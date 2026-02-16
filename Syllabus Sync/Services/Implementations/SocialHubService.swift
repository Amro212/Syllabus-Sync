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

    static let shared = SocialHubService()

    private let supabase: SupabaseClient

    private var currentUserId: String? {
        SupabaseAuthService.shared.currentUser?.id
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

    /// Search users by username prefix, excluding self and existing friends
    func searchUsers(prefix: String) async -> [DiscoverUserDisplay] {
        guard let uid = currentUserId else {
            print("⚠️ Cannot search: not authenticated")
            return []
        }
        guard prefix.count >= 2 else {
            print("⚠️ Search query too short: \(prefix.count) chars")
            return []
        }

        do {
            // Find users matching prefix
            let matches: [UserProfile] = try await supabase
                .from("users")
                .select("id, username, updated_at")
                .ilike("username", pattern: "\(prefix)%")
                .neq("id", value: uid)
                .limit(20)
                .execute()
                .value

            print("🔍 Found \(matches.count) users matching '\(prefix)'")

            if matches.isEmpty { return [] }

            // Get current friends to mark them
            let friendIds = await fetchFriendUserIds()

            // Get outgoing pending requests to mark "Requested" state
            let outgoing: [FriendRequest] = try await supabase
                .from("friend_requests")
                .select()
                .eq("from_user_id", value: uid)
                .eq("status", value: "pending")
                .execute()
                .value
            let pendingToIds = Set(outgoing.map(\.toUserId))

            return matches.compactMap { user in
                guard let username = user.username, !username.isEmpty else { return nil }

                let state: DiscoverRequestState
                if friendIds.contains(user.id) {
                    state = .friends
                } else if pendingToIds.contains(user.id) {
                    state = .requested
                } else {
                    state = .none
                }

                return DiscoverUserDisplay(
                    id: user.id,
                    username: username,
                    displayName: nil,
                    mutualFriendsCount: 0, // placeholder
                    coursesText: nil,
                    requestState: state
                )
            }
        } catch let error as URLError {
            print("⚠️ Network error searching users: \(error)")
            return []
        } catch {
            print("⚠️ Search users failed: \(error)")
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
                .select("id, username, updated_at")
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
                    displayName: nil,
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

            print("🔍 DEBUG: Found \(friendships.count) friendships for user \(uid)")

            if friendships.isEmpty { return [] }

            let friendIds = friendships.map { $0.userAId == uid ? $0.userBId : $0.userAId }
            print("🔍 DEBUG: Friend IDs: \(friendIds)")

            let profiles: [UserProfile] = try await supabase
                .from("users")
                .select("id, username, updated_at")
                .in("id", values: friendIds)
                .execute()
                .value

            print("🔍 DEBUG: Fetched \(profiles.count) profiles: \(profiles.map { "\($0.id): \($0.username ?? "nil")" })")

            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })

            let result = friendships.compactMap { f in
                let friendId = f.userAId == uid ? f.userBId : f.userAId
                let profile = profileMap[friendId]
                let username = profile?.username ?? "unknown"
                print("🔍 DEBUG: Friendship \(f.id) -> friendId: \(friendId), username: \(username)")
                return FriendDisplay(
                    id: f.id,
                    userId: friendId,
                    username: username,
                    displayName: nil,
                    courseName: nil
                )
            }

            print("🔍 DEBUG: Returning \(result.count) friend displays")
            return result
        } catch {
            print("⚠️ Fetch friends failed: \(error)")
            return []
        }
    }

    // MARK: - Friend Schedule

    /// Fetch a friend's events (read-only). Only works for accepted friends.
    func fetchFriendEvents(friendUserId: String) async -> [EventItem] {
        guard currentUserId != nil else { return [] }

        // Verify friendship exists
        let friendIds = await fetchFriendUserIds()
        guard friendIds.contains(friendUserId) else {
            print("⚠️ Not friends with \(friendUserId), cannot view schedule")
            return []
        }

        do {
            let rows: [SupabaseEvent] = try await supabase
                .from("events")
                .select()
                .eq("user_id", value: friendUserId)
                .order("start_date", ascending: true)
                .execute()
                .value

            return rows.map { $0.toDomain() }
        } catch {
            print("⚠️ Fetch friend events failed: \(error)")
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
