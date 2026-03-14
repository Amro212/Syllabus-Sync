//
//  SocialHubService.swift
//  Syllabus Sync
//
//  Supabase backend operations for the Social Hub friend system.
//  Handles: username management, friend requests, friendships, schedule fetching.
//

import Foundation
import Supabase

@MainActor
final class SocialHubService {

    private struct DiscoverBaseContext {
        let friendIds: Set<String>
        let myCourseCodes: Set<String>
        let outgoingPendingIds: Set<String>
        let incomingPendingIds: Set<String>
    }

    private struct DiscoverMutualContext {
        let friendIdsByUser: [String: Set<String>]
        let sharedCoursesByUser: [String: [String]]
    }

    private struct CourseMembershipRow: Decodable {
        let userId: String
        let code: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case code
        }
    }

    static let shared = SocialHubService()

    private let supabase: SupabaseClient

    /// Lowercased to match Supabase/PostgreSQL's lowercase UUID format.
    /// Swift's UUID.uuidString returns uppercase, but Supabase stores and
    /// returns UUIDs as lowercase. Without this, all Swift-side `==`
    /// comparisons against Supabase-returned IDs silently fail.
    private var currentUserId: String? {
        SupabaseAuthService.shared.currentUser?.id.lowercased()
    }

    private init() {
        self.supabase = SupabaseAuthService.shared.supabase
    }

    // MARK: - Username Operations

    /// Set (or update) the current user's username. Returns nil on success, error message on failure.
    func setUsername(_ username: String) async -> String? {
        guard let uid = currentUserId else { return "Not authenticated" }

        // Client-side validation
        let trimmed = username.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 3 { return "Username must be at least 3 characters" }
        if trimmed.count > 20 { return "Username must be 20 characters or less" }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_")
        if trimmed.rangeOfCharacter(from: allowed.inverted) != nil {
            return "Only letters, numbers, and underscore allowed"
        }

        // Check uniqueness (case-insensitive)
        do {
            let existing: [UserProfile] = try await supabase
                .from("users")
                .select("id, username, updated_at")
                .ilike("username", pattern: trimmed)
                .execute()
                .value

            if let match = existing.first, match.id != uid {
                return "Username is already taken"
            }
        } catch {
            return "Failed to check username availability"
        }

        // Upsert
        await SupabaseAuthService.shared.storeUsernameInDatabase(userId: uid, username: trimmed)
        return nil
    }

    /// Fetch the current user's username
    func fetchMyUsername() async -> String? {
        guard let uid = currentUserId else { return nil }
        return await SupabaseAuthService.shared.fetchUsername(userId: uid)
    }

    // MARK: - Search Users (Discover)

    /// Search users by username prefix and rank them using mutual social context.
    func searchUsers(prefix: String) async -> [DiscoverUserDisplay] {
        guard let uid = currentUserId else {
            print("⚠️ Cannot search: not authenticated")
            return []
        }
        let trimmedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPrefix.count >= 2 else {
            print("⚠️ Search query too short: \(prefix.count) chars")
            return []
        }

        do {
            let matches: [UserProfile] = try await supabase
                .from("users")
                .select("id, username, display_name, updated_at")
                .ilike("username", pattern: "\(trimmedPrefix)%")
                .neq("id", value: uid)
                .limit(20)
                .execute()
                .value

            if matches.isEmpty { return [] }

            let context = try await fetchDiscoverBaseContext(for: uid)
            let users = try await buildDiscoverUsers(
                from: matches,
                baseContext: context,
                includeFriends: true
            )
            return sortDiscoverUsers(users)
        } catch let error as URLError {
            print("⚠️ Network error searching users: \(error)")
            return []
        } catch {
            print("⚠️ Search users failed: \(error)")
            return []
        }
    }

    /// Recommended users based on mutual friends or shared courses.
    func fetchRecommendedUsers() async -> [DiscoverUserDisplay] {
        guard let uid = currentUserId else {
            print("⚠️ Cannot load discover recommendations: not authenticated")
            return []
        }

        do {
            let baseContext = try await fetchDiscoverBaseContext(for: uid)
            let candidateIds = try await fetchRecommendedCandidateIds(
                currentUserId: uid,
                friendIds: baseContext.friendIds,
                myCourseCodes: baseContext.myCourseCodes
            )

            guard !candidateIds.isEmpty else { return [] }

            let profiles = try await fetchUserProfiles(ids: candidateIds)
            let users = try await buildDiscoverUsers(
                from: profiles,
                baseContext: baseContext,
                includeFriends: false
            )
            let recommendedOnly = users.filter(\.isRecommended)
            return sortDiscoverUsers(recommendedOnly)
        } catch {
            print("⚠️ Fetch recommended users failed: \(error)")
            return []
        }
    }

    // MARK: - Friend Requests

    /// Send a friend request. Returns nil on success, error message on failure.
    func sendFriendRequest(toUserId: String) async -> String? {
        guard let uid = currentUserId else { return "Not authenticated" }

        // Validate: cannot send to yourself
        if toUserId == uid { return "You cannot send a friend request to yourself" }

        do {
            // Check if already friends
            let friendIds = await fetchFriendUserIds()
            if friendIds.contains(toUserId) {
                return "You are already friends with this user"
            }

            // Check for existing pending request in either direction
            let existing: [FriendRequest] = try await supabase
                .from("friend_requests")
                .select()
                .eq("status", value: "pending")
                .or("and(from_user_id.eq.\(uid),to_user_id.eq.\(toUserId)),and(from_user_id.eq.\(toUserId),to_user_id.eq.\(uid))")
                .execute()
                .value

            if !existing.isEmpty {
                // Check if the pending request is from them to us
                if let incomingRequest = existing.first(where: { $0.fromUserId == toUserId && $0.toUserId == uid }) {
                    return "This user has already sent you a friend request. Check your Pending Requests."
                }
                // Otherwise it's our outgoing request
                return "Friend request already sent"
            }

            // Insert new request
            let insert = FriendRequestInsert(
                id: UUID().uuidString,
                fromUserId: uid,
                toUserId: toUserId,
                status: "pending"
            )
            try await supabase
                .from("friend_requests")
                .insert(insert)
                .execute()

            print("✅ Friend request sent to \(toUserId)")
            return nil
        } catch let error as URLError {
            print("⚠️ Network error sending friend request: \(error)")
            return "Network error. Please check your connection and try again."
        } catch {
            print("⚠️ Send friend request failed: \(error)")
            return "Unable to send friend request. Please try again."
        }
    }

    /// Cancel an outgoing friend request
    func cancelFriendRequest(requestId: String) async -> String? {
        guard currentUserId != nil else { return "Not authenticated" }

        do {
            try await supabase
                .from("friend_requests")
                .update(["status": "cancelled", "updated_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: requestId)
                .eq("status", value: "pending")
                .execute()
            print("✅ Friend request cancelled")
            return nil
        } catch let error as URLError {
            print("⚠️ Network error cancelling request: \(error)")
            return "Network error. Please check your connection."
        } catch {
            print("⚠️ Cancel request failed: \(error)")
            return "Unable to cancel request. Please try again."
        }
    }

    /// Accept an incoming friend request – creates friendship and updates request status
    func acceptFriendRequest(requestId: String, fromUserId: String) async -> String? {
        guard let uid = currentUserId else { return "Not authenticated" }

        do {
            // Check if already friends (race condition protection)
            let friendIds = await fetchFriendUserIds()
            if friendIds.contains(fromUserId) {
                return "You are already friends with this user"
            }

            // Update request status
            try await supabase
                .from("friend_requests")
                .update(["status": "accepted", "updated_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: requestId)
                .eq("to_user_id", value: uid)
                .eq("status", value: "pending")
                .execute()

            // Create friendship (order user ids for consistent unique pair)
            let (a, b) = uid < fromUserId ? (uid, fromUserId) : (fromUserId, uid)
            let friendship = FriendshipInsert(
                id: UUID().uuidString,
                userAId: a,
                userBId: b
            )
            try await supabase
                .from("friends")
                .insert(friendship)
                .execute()

            print("✅ Friend request accepted, friendship created")
            return nil
        } catch let error as URLError {
            print("⚠️ Network error accepting request: \(error)")
            return "Network error. Please check your connection and try again."
        } catch {
            print("⚠️ Accept friend request failed: \(error)")
            return "Unable to accept request. Please try again."
        }
    }

    /// Decline an incoming friend request
    func declineFriendRequest(requestId: String) async -> String? {
        guard currentUserId != nil else { return "Not authenticated" }

        do {
            try await supabase
                .from("friend_requests")
                .update(["status": "declined", "updated_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: requestId)
                .eq("status", value: "pending")
                .execute()
            print("✅ Friend request declined")
            return nil
        } catch let error as URLError {
            print("⚠️ Network error declining request: \(error)")
            return "Network error. Please check your connection."
        } catch {
            print("⚠️ Decline request failed: \(error)")
            return "Unable to decline request. Please try again."
        }
    }

    // MARK: - Pending Incoming Requests

    /// Fetch pending incoming requests with sender profile info
    func fetchPendingRequests() async -> [PendingRequestDisplay] {
        guard let uid = currentUserId else { return [] }

        do {
            let requests: [FriendRequest] = try await supabase
                .from("friend_requests")
                .select()
                .eq("to_user_id", value: uid)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
                .value

            if requests.isEmpty { return [] }

            // Fetch sender profiles
            let senderIds = requests.map(\.fromUserId)
            let profiles: [UserProfile] = try await supabase
                .from("users")
                .select("id, username, display_name, updated_at")
                .in("id", values: senderIds)
                .execute()
                .value

            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            return requests.compactMap { req in
                let profile = profileMap[req.fromUserId]
                let username = profile?.username ?? "unknown"
                return PendingRequestDisplay(
                    id: req.id,
                    fromUserId: req.fromUserId,
                    username: username,
                    displayName: profile?.displayName,
                    contextLine: "WANTS TO CONNECT"
                )
            }
        } catch {
            print("⚠️ Fetch pending requests failed: \(error)")
            return []
        }
    }

    // MARK: - Friends List

    /// Fetch all friend user IDs for the current user
    func fetchFriendUserIds() async -> Set<String> {
        guard let uid = currentUserId else { return [] }

        do {
            let friendships: [Friendship] = try await supabase
                .from("friends")
                .select()
                .or("user_a_id.eq.\(uid),user_b_id.eq.\(uid)")
                .execute()
                .value

            var ids = Set<String>()
            for f in friendships {
                ids.insert(f.userAId == uid ? f.userBId : f.userAId)
            }
            return ids
        } catch {
            print("⚠️ Fetch friend ids failed: \(error)")
            return []
        }
    }

    /// Fetch friends list with profile info for display
    func fetchFriends() async -> [FriendDisplay] {
        guard let uid = currentUserId else { return [] }

        do {
            let friendships: [Friendship] = try await supabase
                .from("friends")
                .select()
                .or("user_a_id.eq.\(uid),user_b_id.eq.\(uid)")
                .order("created_at", ascending: false)
                .execute()
                .value

            if friendships.isEmpty { return [] }

            let friendIds = friendships.map { $0.userAId == uid ? $0.userBId : $0.userAId }
            let courseCodesByUser = try await fetchCourseCodesByUser(for: [uid] + friendIds)
            let myCourseCodes = courseCodesByUser[uid, default: []]

            let profiles: [UserProfile] = try await supabase
                .from("users")
                .select("id, username, display_name, updated_at")
                .in("id", values: friendIds)
                .execute()
                .value

            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            return friendships.compactMap { f in
                let friendId = f.userAId == uid ? f.userBId : f.userAId
                let profile = profileMap[friendId]
                let username = profile?.username ?? "unknown"
                let sharedCourse = Array(myCourseCodes.intersection(courseCodesByUser[friendId, default: []])).sorted().first
                return FriendDisplay(
                    id: f.id,
                    userId: friendId,
                    username: username,
                    displayName: profile?.displayName,
                    courseName: sharedCourse
                )
            }
        } catch {
            print("⚠️ Fetch friends failed: \(error)")
            return []
        }
    }

    private func fetchDiscoverBaseContext(for userId: String) async throws -> DiscoverBaseContext {
        async let friendIdsTask = fetchFriendUserIds()
        async let pendingTask = fetchPendingRequestUserIds(for: userId)
        async let myCoursesTask = fetchCourseCodesByUser(for: [userId])

        let friendIds = await friendIdsTask
        let pending = try await pendingTask
        let myCourses = try await myCoursesTask

        return DiscoverBaseContext(
            friendIds: friendIds,
            myCourseCodes: myCourses[userId, default: []],
            outgoingPendingIds: pending.outgoing,
            incomingPendingIds: pending.incoming
        )
    }

    private func fetchRecommendedCandidateIds(
        currentUserId: String,
        friendIds: Set<String>,
        myCourseCodes: Set<String>
    ) async throws -> [String] {
        var candidateIds: Set<String> = []

        if !friendIds.isEmpty {
            let friendIdList = Array(friendIds)
            async let friendshipsByA: [Friendship] = supabase
                .from("friends")
                .select()
                .in("user_a_id", values: friendIdList)
                .execute()
                .value
            async let friendshipsByB: [Friendship] = supabase
                .from("friends")
                .select()
                .in("user_b_id", values: friendIdList)
                .execute()
                .value

            let connectedToMyFriends = deduplicatedFriendships(
                try await friendshipsByA,
                try await friendshipsByB
            )

            for friendship in connectedToMyFriends {
                let candidateA = friendship.userAId
                let candidateB = friendship.userBId
                if candidateA != currentUserId && !friendIds.contains(candidateA) {
                    candidateIds.insert(candidateA)
                }
                if candidateB != currentUserId && !friendIds.contains(candidateB) {
                    candidateIds.insert(candidateB)
                }
            }
        }

        if !myCourseCodes.isEmpty {
            let sharedCourseRows: [CourseMembershipRow] = try await supabase
                .from("courses")
                .select("user_id, code")
                .in("code", values: Array(myCourseCodes))
                .neq("user_id", value: currentUserId)
                .execute()
                .value

            for row in sharedCourseRows where !friendIds.contains(row.userId) {
                candidateIds.insert(row.userId)
            }
        }

        candidateIds.remove(currentUserId)
        return Array(candidateIds)
    }

    private func fetchUserProfiles(ids: [String]) async throws -> [UserProfile] {
        guard !ids.isEmpty else { return [] }

        return try await supabase
            .from("users")
            .select("id, username, display_name, updated_at")
            .in("id", values: ids)
            .execute()
            .value
    }

    private func buildDiscoverUsers(
        from profiles: [UserProfile],
        baseContext: DiscoverBaseContext,
        includeFriends: Bool
    ) async throws -> [DiscoverUserDisplay] {
        let candidateIds = profiles.map(\.id)
        let mutualContext = try await fetchDiscoverMutualContext(
            candidateIds: candidateIds,
            currentFriendIds: baseContext.friendIds,
            myCourseCodes: baseContext.myCourseCodes
        )

        return profiles.compactMap { profile in
            let userId = profile.id
            guard let username = profile.username, !username.isEmpty else { return nil }
            if baseContext.incomingPendingIds.contains(userId) { return nil }

            let requestState: DiscoverRequestState
            if baseContext.friendIds.contains(userId) {
                guard includeFriends else { return nil }
                requestState = .friends
            } else if baseContext.outgoingPendingIds.contains(userId) {
                requestState = .requested
            } else {
                requestState = .none
            }

            let mutualFriendIds = mutualContext.friendIdsByUser[userId, default: []]
                .intersection(baseContext.friendIds)
            let sharedCourseCodes = mutualContext.sharedCoursesByUser[userId, default: []]

            return DiscoverUserDisplay(
                id: userId,
                username: username,
                displayName: profile.displayName,
                mutualFriendsCount: mutualFriendIds.count,
                sharedCourseCodes: sharedCourseCodes,
                requestState: requestState
            )
        }
    }

    private func fetchDiscoverMutualContext(
        candidateIds: [String],
        currentFriendIds: Set<String>,
        myCourseCodes: Set<String>
    ) async throws -> DiscoverMutualContext {
        let normalizedCandidateIds = Array(Set(candidateIds))
        guard !normalizedCandidateIds.isEmpty else {
            return DiscoverMutualContext(friendIdsByUser: [:], sharedCoursesByUser: [:])
        }

        let relevantFriendIds = Array(Set(normalizedCandidateIds).union(currentFriendIds))
        async let courseCodesTask = fetchCourseCodesByUser(for: normalizedCandidateIds)
        async let friendshipsByA: [Friendship] = relevantFriendIds.isEmpty ? [] : supabase
            .from("friends")
            .select()
            .in("user_a_id", values: relevantFriendIds)
            .execute()
            .value
        async let friendshipsByB: [Friendship] = relevantFriendIds.isEmpty ? [] : supabase
            .from("friends")
            .select()
            .in("user_b_id", values: relevantFriendIds)
            .execute()
            .value

        let courseCodesByUser = try await courseCodesTask
        let friendships = deduplicatedFriendships(
            try await friendshipsByA,
            try await friendshipsByB
        )

        var friendIdsByUser: [String: Set<String>] = [:]
        for friendship in friendships {
            friendIdsByUser[friendship.userAId, default: []].insert(friendship.userBId)
            friendIdsByUser[friendship.userBId, default: []].insert(friendship.userAId)
        }

        var sharedCoursesByUser: [String: [String]] = [:]
        for userId in normalizedCandidateIds {
            let sharedCourses = Array(myCourseCodes.intersection(courseCodesByUser[userId, default: []])).sorted()
            if !sharedCourses.isEmpty {
                sharedCoursesByUser[userId] = sharedCourses
            }
        }

        return DiscoverMutualContext(
            friendIdsByUser: friendIdsByUser,
            sharedCoursesByUser: sharedCoursesByUser
        )
    }

    private func fetchPendingRequestUserIds(for userId: String) async throws -> (outgoing: Set<String>, incoming: Set<String>) {
        async let outgoingTask: [FriendRequest] = supabase
            .from("friend_requests")
            .select()
            .eq("from_user_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value
        async let incomingTask: [FriendRequest] = supabase
            .from("friend_requests")
            .select()
            .eq("to_user_id", value: userId)
            .eq("status", value: "pending")
            .execute()
            .value

        let outgoing = try await outgoingTask
        let incoming = try await incomingTask
        return (Set(outgoing.map(\.toUserId)), Set(incoming.map(\.fromUserId)))
    }

    private func fetchCourseCodesByUser(for userIds: [String]) async throws -> [String: Set<String>] {
        let normalizedUserIds = Array(Set(userIds))
        guard !normalizedUserIds.isEmpty else { return [:] }

        let rows: [CourseMembershipRow] = try await supabase
            .from("courses")
            .select("user_id, code")
            .in("user_id", values: normalizedUserIds)
            .execute()
            .value

        var courseCodesByUser: [String: Set<String>] = [:]
        for row in rows {
            let normalizedCode = row.code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            guard !normalizedCode.isEmpty else { continue }
            courseCodesByUser[row.userId, default: []].insert(normalizedCode)
        }
        return courseCodesByUser
    }

    private func deduplicatedFriendships(_ lhs: [Friendship], _ rhs: [Friendship]) -> [Friendship] {
        let friendships = lhs + rhs
        var seenIds: Set<String> = []
        var unique: [Friendship] = []
        for friendship in friendships where seenIds.insert(friendship.id).inserted {
            unique.append(friendship)
        }
        return unique
    }

    private func sortDiscoverUsers(_ users: [DiscoverUserDisplay]) -> [DiscoverUserDisplay] {
        users.sorted { lhs, rhs in
            let lhsState = requestSortOrder(for: lhs.requestState)
            let rhsState = requestSortOrder(for: rhs.requestState)
            if lhsState != rhsState { return lhsState < rhsState }
            if lhs.isRecommended != rhs.isRecommended { return lhs.isRecommended && !rhs.isRecommended }
            if lhs.mutualFriendsCount != rhs.mutualFriendsCount {
                return lhs.mutualFriendsCount > rhs.mutualFriendsCount
            }
            if lhs.sharedCourseCodes.count != rhs.sharedCourseCodes.count {
                return lhs.sharedCourseCodes.count > rhs.sharedCourseCodes.count
            }
            return lhs.username.localizedCaseInsensitiveCompare(rhs.username) == .orderedAscending
        }
    }

    private func requestSortOrder(for state: DiscoverRequestState) -> Int {
        switch state {
        case .none: return 0
        case .requested: return 1
        case .friends: return 2
        }
    }

    // MARK: - Friend Schedule

    /// Fetch a friend's events (read-only). Only works for accepted friends.
    func fetchFriendEvents(friendUserId: String) async -> [EventItem] {
        guard currentUserId != nil else {
            print("⚠️ Not authenticated")
            return []
        }

        // Verify friendship exists
        let friendIds = await fetchFriendUserIds()
        guard friendIds.contains(friendUserId) else {
            print("⚠️ Not friends with \(friendUserId), cannot view schedule")
            return []
        }

        // Check friend's schedule visibility setting
        do {
            struct UserVisibility: Codable {
                let scheduleVisibility: String?

                enum CodingKeys: String, CodingKey {
                    case scheduleVisibility = "schedule_visibility"
                }
            }

            let visibilityRows: [UserVisibility] = try await supabase
                .from("users")
                .select("schedule_visibility")
                .eq("id", value: friendUserId)
                .limit(1)
                .execute()
                .value

            if let visibility = visibilityRows.first?.scheduleVisibility {
                // If friend has set their schedule to private, don't show it
                if visibility == "private" {
                    print("⚠️ Friend has set schedule to private")
                    return []
                }
                print("✅ Friend's schedule visibility: \(visibility), fetching events...")
            } else {
                print("⚠️ Could not fetch friend's schedule visibility setting, defaulting to friends_only")
            }

        } catch {
            print("⚠️ Failed to check schedule visibility: \(error)")
            // Continue anyway - if we can't check, assume friends_only
        }

        // Fetch friend's events
        do {
            let rows: [SupabaseEvent] = try await supabase
                .from("events")
                .select()
                .eq("user_id", value: friendUserId)
                .order("start_date", ascending: true)
                .execute()
                .value

            print("✅ Fetched \(rows.count) events for friend \(friendUserId)")
            return rows.map { $0.toDomain() }
        } catch {
            print("⚠️ Fetch friend events failed: \(error)")
            print("   Error details: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Profile Management

    /// Update user's display name in users table
    func updateDisplayName(_ displayName: String?) async -> String? {
        guard let uid = currentUserId else { return "Not authenticated" }

        do {
            try await supabase
                .from("users")
                .update([
                    "display_name": displayName ?? "",
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: uid)
                .execute()

            print("✅ Display name updated")
            return nil
        } catch {
            print("⚠️ Update display name failed: \(error)")
            return "Failed to update display name"
        }
    }

    /// Update user's bio in users table
    func updateBio(_ bio: String?) async -> String? {
        guard let uid = currentUserId else { return "Not authenticated" }

        do {
            try await supabase
                .from("users")
                .update([
                    "bio": bio ?? "",
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: uid)
                .execute()

            print("✅ Bio updated")
            return nil
        } catch {
            print("⚠️ Update bio failed: \(error)")
            return "Failed to update bio"
        }
    }

    /// Update schedule visibility preference
    func updateScheduleVisibility(_ visibility: ScheduleVisibility) async -> String? {
        guard let uid = currentUserId else { return "Not authenticated" }

        do {
            try await supabase
                .from("users")
                .update([
                    "schedule_visibility": visibility.rawValue,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: uid)
                .execute()

            print("✅ Schedule visibility updated to \(visibility.rawValue)")
            return nil
        } catch {
            print("⚠️ Update visibility failed: \(error)")
            return "Failed to update schedule visibility"
        }
    }

    // MARK: - Blocking

    /// Block a user
    func blockUser(_ userId: String) async -> String? {
        guard let uid = currentUserId else { return "Not authenticated" }

        // Cannot block yourself
        if userId == uid { return "You cannot block yourself" }

        do {
            // Check if already blocked
            let existing: [BlockRow] = try await supabase
                .from("blocked_users")
                .select()
                .eq("blocker_id", value: uid)
                .eq("blocked_id", value: userId)
                .execute()
                .value

            if !existing.isEmpty {
                return "User is already blocked"
            }

            // Insert block record
            let insert = BlockInsert(
                id: UUID().uuidString,
                blockerId: uid,
                blockedId: userId
            )
            try await supabase
                .from("blocked_users")
                .insert(insert)
                .execute()

            // Remove friendship if exists
            try await supabase
                .from("friends")
                .delete()
                .or("and(user_a_id.eq.\(uid),user_b_id.eq.\(userId)),and(user_a_id.eq.\(userId),user_b_id.eq.\(uid))")
                .execute()

            print("✅ User blocked")
            return nil
        } catch {
            print("⚠️ Block user failed: \(error)")
            return "Failed to block user"
        }
    }

    /// Unblock a user
    func unblockUser(_ userId: String) async -> String? {
        guard let uid = currentUserId else { return "Not authenticated" }

        do {
            try await supabase
                .from("blocked_users")
                .delete()
                .eq("blocker_id", value: uid)
                .eq("blocked_id", value: userId)
                .execute()

            print("✅ User unblocked")
            return nil
        } catch {
            print("⚠️ Unblock user failed: \(error)")
            return "Failed to unblock user"
        }
    }

    /// Fetch blocked users
    func fetchBlockedUsers() async -> [BlockedUser] {
        guard let uid = currentUserId else { return [] }

        do {
            let blocks: [BlockRow] = try await supabase
                .from("blocked_users")
                .select("id, blocked_id, created_at")
                .eq("blocker_id", value: uid)
                .order("created_at", ascending: false)
                .execute()
                .value

            if blocks.isEmpty { return [] }

            // Fetch user profiles for blocked users
            let blockedIds = blocks.map(\.blockedId)
            let profiles: [UserProfile] = try await supabase
                .from("users")
                .select("id, username, updated_at")
                .in("id", values: blockedIds)
                .execute()
                .value

            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            return blocks.compactMap { block in
                guard let profile = profileMap[block.blockedId],
                      let username = profile.username,
                      let date = ISO8601DateFormatter().date(from: block.createdAt) else {
                    return nil
                }
                return BlockedUser(
                    id: block.id,
                    userId: block.blockedId,
                    username: username,
                    blockedAt: date
                )
            }
        } catch {
            print("⚠️ Fetch blocked users failed: \(error)")
            return []
        }
    }

    // MARK: - Friend Management

    /// Remove a friend
    func removeFriend(friendshipId: String) async -> String? {
        guard currentUserId != nil else { return "Not authenticated" }

        do {
            try await supabase
                .from("friends")
                .delete()
                .eq("id", value: friendshipId)
                .execute()

            print("✅ Friend removed")
            return nil
        } catch {
            print("⚠️ Remove friend failed: \(error)")
            return "Failed to remove friend"
        }
    }

    // MARK: - Preferences

    /// Fetch user preferences
    func fetchUserPreferences() async -> UserPreferences? {
        guard let uid = currentUserId else { return nil }

        do {
            let prefs: [UserPreferences] = try await supabase
                .from("user_preferences")
                .select()
                .eq("user_id", value: uid)
                .limit(1)
                .execute()
                .value

 return prefs.first
        } catch {
            print("⚠️ Fetch user preferences failed: \(error)")
            return nil
        }
    }

    /// Update user preferences
    func updateUserPreferences(_ prefs: UserPreferences) async -> String? {
        guard let uid = currentUserId else { return "Not authenticated" }

        do {
            // Upsert preferences - use the UserPreferences struct directly
            try await supabase
                .from("user_preferences")
                .upsert(prefs)
                .execute()

            print("✅ User preferences updated")
            return nil
        } catch {
            print("⚠️ Update user preferences failed: \(error)")
            return "Failed to update preferences"
        }
    }
}
