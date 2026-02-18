//
//  ProfileView.swift
//  Syllabus Sync
//
//  Main profile view - displays user profile and settings.
//

import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var navigationManager: AppNavigationManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            if viewModel.isLoading {
                VStack(spacing: Layout.Spacing.lg) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        .scaleEffect(1.2)
                    Text("Loading profile...")
                        .font(.lexend(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            } else {
                ScrollView {
                    VStack(spacing: Layout.Spacing.xl) {
                        // Profile Header
                        ProfileHeaderView(viewModel: viewModel)
                            .padding(.horizontal, Layout.Spacing.lg)

                        // Account Section
                        ProfileSection(title: "Account") {
                            EditableFieldRow(
                                title: "Username",
                                value: viewModel.username,
                                icon: "at",
                                onTap: { viewModel.showEditUsername = true }
                            )

                            EditableFieldRow(
                                title: "Display Name",
                                value: viewModel.displayName,
                                icon: "person.fill",
                                onTap: { viewModel.showEditDisplayName = true }
                            )

                            EditableFieldRow(
                                title: "Bio",
                                value: viewModel.bio.isEmpty ? "Add a bio" : viewModel.bio,
                                icon: "text.alignleft",
                                onTap: { viewModel.showEditBio = true }
                            )

                            InfoRow(
                                title: "Email",
                                value: viewModel.email,
                                icon: "envelope.fill"
                            )
                        }

                        // Social Hub Section
                        ProfileSection(title: "Social Hub") {
                            NavigationRow(
                                title: "Friend Requests",
                                icon: "person.badge.plus",
                                badge: viewModel.pendingRequestsCount,
                                onTap: { viewModel.showFriendRequests = true }
                            )

                            InfoRow(
                                title: "Friends",
                                value: "\(viewModel.friendsCount)",
                                icon: "person.2.fill"
                            )

                            ScheduleVisibilityPicker(
                                selectedVisibility: $viewModel.scheduleVisibility,
                                onChange: { visibility in
                                    await viewModel.updateScheduleVisibility(visibility)
                                }
                            )

                            NavigationRow(
                                title: "Blocked Users",
                                icon: "person.slash",
                                badge: viewModel.blockedUsers.count,
                                onTap: { viewModel.showBlockedUsers = true }
                            )

                            ToggleRow(
                                title: "Friend Request Notifications",
                                icon: "bell.fill",
                                isOn: $viewModel.friendRequestNotifications
                            )
                        }

                        // Preferences Section
                        ProfileSection(title: "Preferences") {
                            ToggleRow(
                                title: "Notifications",
                                icon: "bell.badge.fill",
                                isOn: $viewModel.notificationsEnabled
                            )

                            ToggleRow(
                                title: "Haptic Feedback",
                                icon: "hand.tap.fill",
                                isOn: $viewModel.hapticEnabled
                            )
                        }

                        // Appearance Section
                        ProfileSection(title: "Appearance") {
                            ThemePickerRow(
                                selectedTheme: $viewModel.themePreference,
                                themeManager: themeManager
                            )
                        }

                        // Account Actions Section
                        ProfileSection(title: "Account") {
                            if viewModel.provider == .email {
                                ActionRow(
                                    title: "Reset Password",
                                    icon: "key.fill",
                                    isDestructive: false,
                                    onTap: {
                                        Task { await viewModel.resetPassword() }
                                    }
                                )
                            }

                            ActionRow(
                                title: "Sign Out",
                                icon: "rectangle.portrait.and.arrow.right",
                                isDestructive: true,
                                onTap: { viewModel.showSignOutAlert = true }
                            )
                        }

                        // Footer
                        Text("Version 1.0 (Beta)")
                            .font(.lexend(size: 12, weight: .regular))
                            .foregroundColor(AppColors.textTertiary)
                            .padding(.top, Layout.Spacing.lg)
                            .padding(.bottom, Layout.Spacing.massive)
                    }
                    .padding(.top, Layout.Spacing.md)
                }
            }

            // Toast overlay
            if viewModel.showToast, let message = viewModel.toastMessage {
                VStack {
                    Spacer()
                    ToastBanner(message: message)
                        .padding(.bottom, Layout.Spacing.xl)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .task {
            viewModel.eventStore = eventStore
            viewModel.themeManager = themeManager
            viewModel.navigationManager = navigationManager
            await viewModel.loadProfileData()
        }
        .onChange(of: viewModel.showToast) { _, show in
            if show {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { viewModel.showToast = false }
                }
            }
        }
        .onChange(of: viewModel.notificationsEnabled) { _, _ in
            Task { await viewModel.updatePreferences() }
        }
        .onChange(of: viewModel.hapticEnabled) { _, _ in
            Task { await viewModel.updatePreferences() }
        }
        .onChange(of: viewModel.friendRequestNotifications) { _, _ in
            Task { await viewModel.updatePreferences() }
        }
        .onChange(of: viewModel.themePreference) { _, _ in
            Task { await viewModel.updatePreferences() }
        }
        // Sign Out Alert
        .alert("Sign Out", isPresented: $viewModel.showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                Task { await viewModel.signOut() }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        // Edit sheets
        .sheet(isPresented: $viewModel.showEditUsername) {
            EditUsernameSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showEditDisplayName) {
            EditDisplayNameSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showEditBio) {
            EditBioSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showBlockedUsers) {
            BlockedUsersSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showFriendRequests) {
            FriendRequestsSheet(viewModel: viewModel)
        }
    }
}
