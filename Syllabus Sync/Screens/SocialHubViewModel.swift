//
//  SocialHubViewModel.swift
//  Syllabus Sync
//
//  ViewModel for the Social Hub modal.
//  Drives: username state, friends/discover tabs, requests, search, friend schedule.
//

import SwiftUI

@MainActor
final class SocialHubViewModel: ObservableObject {

    // MARK: - Tab State

    enum Tab: String, CaseIterable {
        case friends = "FRIENDS"
        case discover = "DISCOVER"
    }

    @Published var selectedTab: Tab = .friends

    // MARK: - Username State

    @Published var myUsername: String?
    @Published var isLoadingUsername = false
    @Published var needsUsername = false
    @Published var usernameInput = ""
    @Published var usernameError: String?
    @Published var isSavingUsername = false

    // MARK: - Friends Tab

    @Published var pendingRequests: [PendingRequestDisplay] = []
    @Published var friends: [FriendDisplay] = []
    @Published var isLoadingFriends = false
    @Published var friendsSearchText = ""

    var filteredFriends: [FriendDisplay] {
        if friendsSearchText.isEmpty { return friends }
        let query = friendsSearchText.lowercased()
        return friends.filter {
            $0.username.lowercased().contains(query) ||
            ($0.displayName?.lowercased().contains(query) ?? false)
        }
    }

    // MARK: - Discover Tab

    @Published var discoverSearchText = ""
    @Published var discoverResults: [DiscoverUserDisplay] = []
    @Published var isSearching = false

    // MARK: - Friend Schedule

    @Published var selectedFriend: FriendDisplay?
    @Published var friendEvents: [EventItem] = []
    @Published var isLoadingSchedule = false
    @Published var showFriendSchedule = false

    // MARK: - Toasts

    @Published var toastMessage: String?
    @Published var showToast = false

    // MARK: - Service

    private let service = SocialHubService.shared

    // MARK: - Initial Load

    func loadInitialData() async {
        isLoadingUsername = true
        myUsername = await service.fetchMyUsername()
        isLoadingUsername = false

        if myUsername == nil || myUsername?.isEmpty == true {
            needsUsername = true
            return
        }

        await refreshFriendsTab()
    }

    // MARK: - Username

    func validateUsernameInput(_ value: String) {
        // Filter to only allowed characters
        let filtered = value.filter { c in
            c.isLetter || c.isNumber || c == "_"
        }
        if filtered != usernameInput {
            usernameInput = filtered
            HapticFeedbackManager.shared.lightImpact()
        }

        // Clear error for empty input
        if filtered.isEmpty {
            usernameError = nil
            return
        }

        // Validate length and format
        if filtered.count < 3 {
            usernameError = "Must be at least 3 characters"
        } else if filtered.count > 20 {
            usernameError = "Must be 20 characters or less"
        } else {
            usernameError = nil
        }
    }

    func saveUsername() async {
        guard !usernameInput.isEmpty, usernameError == nil else {
            showToastMessage("Please enter a valid username")
            return
        }

        isSavingUsername = true

        if let error = await service.setUsername(usernameInput) {
            usernameError = error
            isSavingUsername = false
            HapticFeedbackManager.shared.error()
            return
        }

        myUsername = usernameInput
        needsUsername = false
        isSavingUsername = false
        HapticFeedbackManager.shared.success()
        await refreshFriendsTab()
    }

    // MARK: - Friends Tab Refresh

    func refreshFriendsTab() async {
        isLoadingFriends = true
        async let pendingTask = service.fetchPendingRequests()
        async let friendsTask = service.fetchFriends()
        pendingRequests = await pendingTask
        friends = await friendsTask
        isLoadingFriends = false
    }

    // MARK: - Friend Request Actions

    func acceptRequest(_ request: PendingRequestDisplay) async {
        if let error = await service.acceptFriendRequest(requestId: request.id, fromUserId: request.fromUserId) {
            showToastMessage(error)
            return
        }
        HapticFeedbackManager.shared.success()
        showToastMessage("✓ Friend request accepted!")
        await refreshFriendsTab()
    }

    func declineRequest(_ request: PendingRequestDisplay) async {
        if let error = await service.declineFriendRequest(requestId: request.id) {
            showToastMessage(error)
            return
        }
        HapticFeedbackManager.shared.lightImpact()
        // Optimistically update UI
        pendingRequests.removeAll { $0.id == request.id }
        showToastMessage("Request declined")
    }

    // MARK: - Discover

    func searchDiscover() async {
        let query = discoverSearchText.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            discoverResults = []
            return
        }

        isSearching = true
        discoverResults = await service.searchUsers(prefix: query)
        isSearching = false

        // Show helpful message if no results
        if discoverResults.isEmpty && !isSearching {
            // We'll handle this in the UI empty state
        }
    }

    func sendRequest(to user: DiscoverUserDisplay) async {
        // Optimistically update UI first
        if let idx = discoverResults.firstIndex(where: { $0.id == user.id }) {
            discoverResults[idx] = DiscoverUserDisplay(
                id: user.id,
                username: user.username,
                displayName: user.displayName,
                mutualFriendsCount: user.mutualFriendsCount,
                coursesText: user.coursesText,
                requestState: .requested
            )
        }

        if let error = await service.sendFriendRequest(toUserId: user.id) {
            // Revert optimistic update on error
            if let idx = discoverResults.firstIndex(where: { $0.id == user.id }) {
                discoverResults[idx] = DiscoverUserDisplay(
                    id: user.id,
                    username: user.username,
                    displayName: user.displayName,
                    mutualFriendsCount: user.mutualFriendsCount,
                    coursesText: user.coursesText,
                    requestState: .none
                )
            }
            showToastMessage(error)
            return
        }

        HapticFeedbackManager.shared.success()
        showToastMessage("✓ Friend request sent!")
    }

    func cancelRequest(to user: DiscoverUserDisplay) async {
        // Find the pending request id for this user
        guard let uid = SupabaseAuthService.shared.currentUser?.id else {
            showToastMessage("Not authenticated")
            return
        }

        // Optimistically update UI
        let originalState = user.requestState
        if let idx = discoverResults.firstIndex(where: { $0.id == user.id }) {
            discoverResults[idx] = DiscoverUserDisplay(
                id: user.id,
                username: user.username,
                displayName: user.displayName,
                mutualFriendsCount: user.mutualFriendsCount,
                coursesText: user.coursesText,
                requestState: .none
            )
        }

        // We need to find the request ID to cancel it
        do {
            struct ReqRow: Decodable {
                let id: String
                let toUserId: String
                enum CodingKeys: String, CodingKey {
                    case id
                    case toUserId = "to_user_id"
                }
            }
            let rows: [ReqRow] = try await SupabaseAuthService.shared.supabase
                .from("friend_requests")
                .select("id, to_user_id")
                .eq("from_user_id", value: uid)
                .eq("to_user_id", value: user.id)
                .eq("status", value: "pending")
                .limit(1)
                .execute()
                .value

            guard let reqId = rows.first?.id else {
                showToastMessage("Request not found")
                return
            }

            if let error = await service.cancelFriendRequest(requestId: reqId) {
                // Revert optimistic update on error
                if let idx = discoverResults.firstIndex(where: { $0.id == user.id }) {
                    discoverResults[idx] = DiscoverUserDisplay(
                        id: user.id,
                        username: user.username,
                        displayName: user.displayName,
                        mutualFriendsCount: user.mutualFriendsCount,
                        coursesText: user.coursesText,
                        requestState: originalState
                    )
                }
                showToastMessage(error)
                return
            }

            HapticFeedbackManager.shared.lightImpact()
            showToastMessage("Request cancelled")
        } catch {
            // Revert optimistic update on error
            if let idx = discoverResults.firstIndex(where: { $0.id == user.id }) {
                discoverResults[idx] = DiscoverUserDisplay(
                    id: user.id,
                    username: user.username,
                    displayName: user.displayName,
                    mutualFriendsCount: user.mutualFriendsCount,
                    coursesText: user.coursesText,
                    requestState: originalState
                )
            }
            showToastMessage("Unable to cancel request")
        }
    }

    // MARK: - Friend Schedule

    func openFriendSchedule(_ friend: FriendDisplay) async {
        selectedFriend = friend
        isLoadingSchedule = true
        showFriendSchedule = true
        friendEvents = await service.fetchFriendEvents(friendUserId: friend.userId)
        isLoadingSchedule = false

        // Show feedback if no events
        if friendEvents.isEmpty && !isLoadingSchedule {
            // UI will show empty state
        }
    }

    func closeFriendSchedule() {
        showFriendSchedule = false
        selectedFriend = nil
        friendEvents = []
    }

    // MARK: - Toast

    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        HapticFeedbackManager.shared.error()
    }
}
