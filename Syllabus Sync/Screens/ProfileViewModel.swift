//
//  ProfileViewModel.swift
//  Syllabus Sync
//
//  View model for user profile management.
//  Handles: profile display, editing, social settings, preferences, account actions.
//

import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - User Data

    @Published var currentUser: AuthUser?
    @Published var username: String = ""
    @Published var displayName: String = ""
    @Published var bio: String = ""
    @Published var email: String = ""
    @Published var photoURL: URL?
    @Published var provider: AuthProvider = .email

    // MARK: - Social Settings

    @Published var scheduleVisibility: ScheduleVisibility = .friendsOnly
    @Published var friendRequestNotifications: Bool = true
    @Published var pendingRequestsCount: Int = 0
    @Published var friendsCount: Int = 0
    @Published var blockedUsers: [BlockedUser] = []

    // MARK: - App Preferences

    @Published var notificationsEnabled: Bool = true
    @Published var hapticEnabled: Bool = true
    @Published var themePreference: String = "system"

    // MARK: - UI State

    @Published var isLoading: Bool = false
    @Published var showEditUsername: Bool = false
    @Published var showEditDisplayName: Bool = false
    @Published var showEditBio: Bool = false
    @Published var showBlockedUsers: Bool = false
    @Published var showFriendRequests: Bool = false
    @Published var showDeleteCloudDataAlert: Bool = false
    @Published var showResetAppDataAlert: Bool = false
    @Published var showSignOutAlert: Bool = false

    // MARK: - Editing State

    @Published var editingUsername: String = ""
    @Published var editingDisplayName: String = ""
    @Published var editingBio: String = ""
    @Published var usernameError: String?
    @Published var isSaving: Bool = false

    // MARK: - Toast

    @Published var toastMessage: String?
    @Published var showToast: Bool = false

    // MARK: - Dependencies

    private let authService = SupabaseAuthService.shared
    private let socialHubService = SocialHubService.shared
    var eventStore: EventStore?
    var themeManager: ThemeManager?
   var navigationManager: AppNavigationManager?

    // MARK: - Data Loading

    func loadProfileData() async {
        isLoading = true

        // Load current user
        currentUser = authService.currentUser
        guard let user = currentUser else {
            isLoading = false
            return
        }

        email = user.email ?? ""
        photoURL = user.photoURL
        provider = user.provider

        // Fetch username
        if let fetchedUsername = await socialHubService.fetchMyUsername() {
            username = fetchedUsername
        }

        // Fetch user profile data from users table
        await fetchUserProfile()

        // Fetch preferences
        if let prefs = await socialHubService.fetchUserPreferences() {
            notificationsEnabled = prefs.notificationsEnabled
            hapticEnabled = prefs.hapticFeedbackEnabled
            friendRequestNotifications = prefs.friendRequestNotifications
            themePreference = prefs.themePreference
        } else {
            // Create default preferences if none exist
            await createDefaultPreferences()
        }

        // Fetch social counts
        let pendingRequests = await socialHubService.fetchPendingRequests()
        pendingRequestsCount = pendingRequests.count

        let friends = await socialHubService.fetchFriends()
        friendsCount = friends.count

        // Fetch blocked users
        blockedUsers = await socialHubService.fetchBlockedUsers()

        isLoading = false
    }

    private func fetchUserProfile() async {
        guard let uid = currentUser?.id else { return }

        do {
            struct UserProfileRow: Codable {
                let displayName: String?
                let bio: String?
                let scheduleVisibility: String?

                enum CodingKeys: String, CodingKey {
                    case displayName = "display_name"
                    case bio
                    case scheduleVisibility = "schedule_visibility"
                }
            }

            let rows: [UserProfileRow] = try await authService.supabase
                .from("users")
                .select("display_name, bio, schedule_visibility")
                .eq("id", value: uid)
                .limit(1)
                .execute()
                .value

            if let row = rows.first {
                displayName = row.displayName ?? ""
                bio = row.bio ?? ""
                if let visibility = row.scheduleVisibility,
                   let parsedVisibility = ScheduleVisibility(rawValue: visibility) {
                    scheduleVisibility = parsedVisibility
                }
            }
        } catch {
            print("⚠️ Fetch user profile failed: \(error)")
        }
    }

    private func createDefaultPreferences() async {
        guard let uid = currentUser?.id else { return }

        let defaultPrefs = UserPreferences(
            userId: uid,
            notificationsEnabled: true,
            hapticFeedbackEnabled: true,
            friendRequestNotifications: true,
            themePreference: "system"
        )

        _ = await socialHubService.updateUserPreferences(defaultPrefs)
    }

    // MARK: - Username Management

    func validateUsernameInput(_ value: String) {
        // Filter to only allowed characters
        let filtered = value.filter { c in
            c.isLetter || c.isNumber || c == "_"
        }
        if filtered != editingUsername {
            editingUsername = filtered
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

    func updateUsername(_ newUsername: String) async {
        guard !newUsername.isEmpty, usernameError == nil else {
            showToastMessage("Please enter a valid username")
            return
        }

        isSaving = true

        if let error = await socialHubService.setUsername(newUsername) {
            usernameError = error
            isSaving = false
            HapticFeedbackManager.shared.error()
            return
        }

        username = newUsername
        isSaving = false
        showEditUsername = false
        HapticFeedbackManager.shared.success()
        showToastMessage("✓ Username updated!")
    }

    // MARK: - Profile Editing

    func updateDisplayName(_ newName: String) async {
        isSaving = true

        if let error = await socialHubService.updateDisplayName(newName.isEmpty ? nil : newName) {
            isSaving = false
            showToastMessage(error)
            return
        }

        displayName = newName
        isSaving = false
        showEditDisplayName = false
        HapticFeedbackManager.shared.success()
        showToastMessage("✓ Display name updated!")
    }

    func updateBio(_ newBio: String) async {
        isSaving = true

        if let error = await socialHubService.updateBio(newBio.isEmpty ? nil : newBio) {
            isSaving = false
            showToastMessage(error)
            return
        }

        bio = newBio
        isSaving = false
        showEditBio = false
        HapticFeedbackManager.shared.success()
        showToastMessage("✓ Bio updated!")
    }

    // MARK: - Schedule Visibility

    func updateScheduleVisibility(_ visibility: ScheduleVisibility) async {
        if let error = await socialHubService.updateScheduleVisibility(visibility) {
            showToastMessage(error)
            return
        }

        scheduleVisibility = visibility
        HapticFeedbackManager.shared.success()
        showToastMessage("✓ Schedule visibility updated!")
    }

    // MARK: - Blocking

    func blockUser(_ userId: String) async {
        if let error = await socialHubService.blockUser(userId) {
            showToastMessage(error)
            return
        }

        // Refresh blocked users list
        blockedUsers = await socialHubService.fetchBlockedUsers()

        // Refresh friends count (friendship was removed)
        let friends = await socialHubService.fetchFriends()
        friendsCount = friends.count

        HapticFeedbackManager.shared.success()
        showToastMessage("✓ User blocked")
    }

    func unblockUser(_ userId: String) async {
        if let error = await socialHubService.unblockUser(userId) {
            showToastMessage(error)
            return
        }

        // Remove from local list
        blockedUsers.removeAll { $0.userId == userId }

        HapticFeedbackManager.shared.success()
        showToastMessage("✓ User unblocked")
    }

    // MARK: - Preferences

    func updatePreferences() async {
        guard let uid = currentUser?.id else { return }

        let prefs = UserPreferences(
            userId: uid,
            notificationsEnabled: notificationsEnabled,
            hapticFeedbackEnabled: hapticEnabled,
            friendRequestNotifications: friendRequestNotifications,
            themePreference: themePreference
        )

        if let error = await socialHubService.updateUserPreferences(prefs) {
            showToastMessage(error)
            return
        }

        HapticFeedbackManager.shared.success()
        showToastMessage("✓ Preferences saved!")
    }

    // MARK: - Account Actions

    func resetPassword() async {
        guard provider == .email, !email.isEmpty else {
            showToastMessage("Password reset is only available for email accounts")
            return
        }

        do {
            try await authService.supabase.auth.resetPasswordForEmail(email)
            HapticFeedbackManager.shared.success()
            showToastMessage("✓ Password reset email sent!")
        } catch {
            showToastMessage("Failed to send password reset email")
        }
    }

    func signOut() async {
        do {
            // CRITICAL: Clear all local data before signing out

            // 1. Clear Event Store
            if let store = eventStore {
                await MainActor.run {
                    store.clearEvents()
                }
                print("✅ EventStore cleared")
            }

            // 2. Clear UserDefaults
            if let bundleId = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleId)
                print("✅ UserDefaults cleared")
            }

            // 3. Sign out from Supabase
            try await authService.signOut()
            print("✅ Signed out from Supabase")

            // 4. Navigate to auth screen
            await MainActor.run {
                if let navManager = navigationManager {
                    navManager.setRoot(to: .auth)
                    print("✅ Navigated to auth screen")
                }
                HapticFeedbackManager.shared.success()
            }

        } catch {
            await MainActor.run {
                showToastMessage("Failed to sign out: \(error.localizedDescription)")
            }
        }
    }

    func deleteCloudData() async {
        guard let dataService = SupabaseDataService.shared as? SupabaseDataService else {
            showToastMessage("Data service not available")
            return
        }

        await dataService.deleteAllData()
        HapticFeedbackManager.shared.success()
        showToastMessage("✓ Cloud data deleted!")
    }

    func resetAppData() async {
        // Clear UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
        }

        // Clear event store
        if let store = eventStore {
            store.clearEvents()
        }

        // Sign out
        await signOut()

        HapticFeedbackManager.shared.success()
    }

    // MARK: - Toast Helper

    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        HapticFeedbackManager.shared.lightImpact()
    }
}
