//
//  ProfileEditSheets.swift
//  Syllabus Sync
//
//  Polished edit sheets for profile management.
//  Includes: Username, DisplayName, Bio, BlockedUsers, FriendRequests.
//

import SwiftUI

// MARK: - Edit Username Sheet

struct EditUsernameSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: Layout.Spacing.lg) {
                    // Info card
                    HStack(spacing: Layout.Spacing.md) {
                        Image(systemName: "info.circle.fill")
                            .font(.lexend(size: 16, weight: .medium))
                            .foregroundColor(AppColors.accent)

                        Text("Your username is unique and visible to others. Use 3-20 characters: letters, numbers, or underscores.")
                            .font(.lexend(size: 13, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(Layout.Spacing.md)
                    .background(AppColors.surface)
                    .cornerRadius(Layout.CornerRadius.lg)

                    // Input field
                    VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                        Text("USERNAME")
                            .font(.lexend(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(0.5)

                        HStack {
                            Text("@")
                                .font(.lexend(size: 18, weight: .medium))
                                .foregroundColor(AppColors.textTertiary)

                            TextField("username", text: $viewModel.editingUsername)
                                .font(.lexend(size: 18, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .onChange(of: viewModel.editingUsername) { _, newValue in
                                    viewModel.validateUsernameInput(newValue)
                                }
                        }
                        .padding(Layout.Spacing.md)
                        .background(AppColors.surface)
                        .cornerRadius(Layout.CornerRadius.lg)
                        .overlay(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                                .stroke(
                                    viewModel.usernameError != nil ? Color.red.opacity(0.6) : AppColors.border.opacity(0.3),
                                    lineWidth: 1
                                )
                        )

                        // Error / character count
                        HStack {
                            if let error = viewModel.usernameError {
                                Text(error)
                                    .font(.lexend(size: 12, weight: .medium))
                                    .foregroundColor(.red)
                            }

                            Spacer()

                            Text("\(viewModel.editingUsername.count)/20")
                                .font(.lexend(size: 12, weight: .regular))
                                .foregroundColor(viewModel.editingUsername.count > 20 ? .red : AppColors.textTertiary)
                        }
                    }

                    Spacer()

                    // Save button
                    Button {
                        Task { await viewModel.updateUsername(viewModel.editingUsername) }
                    } label: {
                        HStack {
                            if viewModel.isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.129, green: 0.110, blue: 0.067)))
                            } else {
                                Text("Save Username")
                                    .font(.lexend(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Layout.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                                .fill(canSaveUsername ? AppColors.accent : AppColors.surfaceSecondary)
                        )
                        .foregroundColor(canSaveUsername ? Color(red: 0.129, green: 0.110, blue: 0.067) : AppColors.textTertiary)
                    }
                    .disabled(!canSaveUsername || viewModel.isSaving)
                }
                .padding(Layout.Spacing.lg)
            }
            .navigationTitle("Edit Username")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .onAppear {
                viewModel.editingUsername = viewModel.username
                viewModel.usernameError = nil
            }
        }
    }

    private var canSaveUsername: Bool {
        !viewModel.editingUsername.isEmpty &&
        viewModel.usernameError == nil &&
        viewModel.editingUsername != viewModel.username
    }
}

// MARK: - Edit Display Name Sheet

struct EditDisplayNameSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: Layout.Spacing.lg) {
                    // Info card
                    HStack(spacing: Layout.Spacing.md) {
                        Image(systemName: "info.circle.fill")
                            .font(.lexend(size: 16, weight: .medium))
                            .foregroundColor(AppColors.accent)

                        Text("Your display name appears above your @username. Leave empty to use your username as your primary name.")
                            .font(.lexend(size: 13, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(Layout.Spacing.md)
                    .background(AppColors.surface)
                    .cornerRadius(Layout.CornerRadius.lg)

                    // Input field
                    VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                        Text("DISPLAY NAME")
                            .font(.lexend(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(0.5)

                        TextField("Display Name (optional)", text: $viewModel.editingDisplayName)
                            .font(.lexend(size: 18, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .padding(Layout.Spacing.md)
                            .background(AppColors.surface)
                            .cornerRadius(Layout.CornerRadius.lg)
                            .overlay(
                                RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                                    .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                            )

                        HStack {
                            Spacer()
                            Text("\(viewModel.editingDisplayName.count)/50")
                                .font(.lexend(size: 12, weight: .regular))
                                .foregroundColor(viewModel.editingDisplayName.count > 50 ? .red : AppColors.textTertiary)
                        }
                    }

                    Spacer()

                    // Save button
                    Button {
                        Task { await viewModel.updateDisplayName(viewModel.editingDisplayName) }
                    } label: {
                        HStack {
                            if viewModel.isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.129, green: 0.110, blue: 0.067)))
                            } else {
                                Text("Save Display Name")
                                    .font(.lexend(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Layout.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                                .fill(canSaveDisplayName ? AppColors.accent : AppColors.surfaceSecondary)
                        )
                        .foregroundColor(canSaveDisplayName ? Color(red: 0.129, green: 0.110, blue: 0.067) : AppColors.textTertiary)
                    }
                    .disabled(!canSaveDisplayName || viewModel.isSaving)
                }
                .padding(Layout.Spacing.lg)
            }
            .navigationTitle("Edit Display Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .onAppear {
                viewModel.editingDisplayName = viewModel.displayName
            }
        }
    }

    private var canSaveDisplayName: Bool {
        viewModel.editingDisplayName != viewModel.displayName &&
        viewModel.editingDisplayName.count <= 50
    }
}

// MARK: - Edit Bio Sheet

struct EditBioSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss
    private let maxBioLength = 200

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: Layout.Spacing.lg) {
                    // Info card
                    HStack(spacing: Layout.Spacing.md) {
                        Image(systemName: "info.circle.fill")
                            .font(.lexend(size: 16, weight: .medium))
                            .foregroundColor(AppColors.accent)

                        Text("Tell others a bit about yourself. Your bio is visible on your profile.")
                            .font(.lexend(size: 13, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(Layout.Spacing.md)
                    .background(AppColors.surface)
                    .cornerRadius(Layout.CornerRadius.lg)

                    // Text editor
                    VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                        Text("BIO")
                            .font(.lexend(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.textSecondary)
                            .tracking(0.5)

                        TextEditor(text: $viewModel.editingBio)
                            .font(.lexend(size: 16, weight: .regular))
                            .foregroundColor(AppColors.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120, maxHeight: 180)
                            .padding(Layout.Spacing.md)
                            .background(AppColors.surface)
                            .cornerRadius(Layout.CornerRadius.lg)
                            .overlay(
                                RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                                    .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: viewModel.editingBio) { _, newValue in
                                if newValue.count > maxBioLength {
                                    viewModel.editingBio = String(newValue.prefix(maxBioLength))
                                }
                            }

                        HStack {
                            Spacer()
                            Text("\(viewModel.editingBio.count)/\(maxBioLength)")
                                .font(.lexend(size: 12, weight: .regular))
                                .foregroundColor(viewModel.editingBio.count >= maxBioLength ? .red : AppColors.textTertiary)
                        }
                    }

                    Spacer()

                    // Save button
                    Button {
                        Task { await viewModel.updateBio(viewModel.editingBio) }
                    } label: {
                        HStack {
                            if viewModel.isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.129, green: 0.110, blue: 0.067)))
                            } else {
                                Text("Save Bio")
                                    .font(.lexend(size: 16, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Layout.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                                .fill(canSaveBio ? AppColors.accent : AppColors.surfaceSecondary)
                        )
                        .foregroundColor(canSaveBio ? Color(red: 0.129, green: 0.110, blue: 0.067) : AppColors.textTertiary)
                    }
                    .disabled(!canSaveBio || viewModel.isSaving)
                }
                .padding(Layout.Spacing.lg)
            }
            .navigationTitle("Edit Bio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .onAppear {
                viewModel.editingBio = viewModel.bio
            }
        }
    }

    private var canSaveBio: Bool {
        viewModel.editingBio != viewModel.bio
    }
}

// MARK: - Blocked Users Sheet

struct BlockedUsersSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                if viewModel.blockedUsers.isEmpty {
                    emptyState
                } else {
                    blockedUsersList
                }
            }
            .navigationTitle("Blocked Users")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Layout.Spacing.lg) {
            Image(systemName: "person.slash")
                .font(.lexend(size: 48, weight: .regular))
                .foregroundColor(AppColors.textTertiary)

            Text("No blocked users")
                .font(.lexend(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            Text("Users you block won't be able to send you friend requests or view your schedule.")
                .font(.lexend(size: 14, weight: .regular))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.Spacing.xl)
        }
    }

    private var blockedUsersList: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.sm) {
                ForEach(viewModel.blockedUsers) { user in
                    blockedUserRow(user)
                }
            }
            .padding(Layout.Spacing.lg)
        }
    }

    private func blockedUserRow(_ user: BlockedUser) -> some View {
        HStack(spacing: Layout.Spacing.md) {
            // Avatar
            avatarCircle(
                initials: AvatarColor.initials(from: user.username),
                colorHex: AvatarColor.hex(for: user.userId),
                size: 44
            )

            // Name
            VStack(alignment: .leading, spacing: 2) {
                Text(user.username)
                    .font(.lexend(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text("Blocked \(user.blockedAt.formatted(.relative(presentation: .named)))")
                    .font(.lexend(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(0.5)
            }

            Spacer()

            // Unblock button
            Button {
                Task { await viewModel.unblockUser(user.userId) }
            } label: {
                Text("Unblock")
                    .font(.lexend(size: 13, weight: .semibold))
                    .foregroundColor(.red)
                    .padding(.horizontal, Layout.Spacing.md)
                    .padding(.vertical, Layout.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .stroke(Color.red.opacity(0.4), lineWidth: 1)
                    )
            }
        }
        .padding(Layout.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .fill(AppColors.surface)
        )
    }
}

// MARK: - Friend Requests Sheet

struct FriendRequestsSheet: View {
    @ObservedObject var viewModel: ProfileViewModel
    @StateObject private var socialViewModel = SocialHubViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                if socialViewModel.isLoadingFriends {
                    loadingState
                } else if socialViewModel.pendingRequests.isEmpty {
                    emptyState
                } else {
                    requestsList
                }
            }
            .navigationTitle("Friend Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
            .task {
                await socialViewModel.loadInitialData()
            }
        }
    }

    private var loadingState: some View {
        VStack(spacing: Layout.Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                .scaleEffect(1.2)
            Text("Loading requests...")
                .font(.lexend(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: Layout.Spacing.lg) {
            Image(systemName: "person.badge.plus")
                .font(.lexend(size: 48, weight: .regular))
                .foregroundColor(AppColors.textTertiary)

            Text("No pending requests")
                .font(.lexend(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            Text("When someone sends you a friend request, it will appear here.")
                .font(.lexend(size: 14, weight: .regular))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.Spacing.xl)
        }
    }

    private var requestsList: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.sm) {
                // Count pill
                HStack {
                    Text("\(socialViewModel.pendingRequests.count) PENDING")
                        .font(.lexend(size: 11, weight: .bold))
                        .foregroundColor(Color(red: 0.129, green: 0.110, blue: 0.067))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(AppColors.accent))

                    Spacer()
                }

                ForEach(socialViewModel.pendingRequests) { request in
                    pendingRequestRow(request)
                }
            }
            .padding(Layout.Spacing.lg)
        }
    }

    private func pendingRequestRow(_ request: PendingRequestDisplay) -> some View {
        HStack(spacing: Layout.Spacing.md) {
            // Avatar
            avatarCircle(
                initials: AvatarColor.initials(from: request.username),
                colorHex: AvatarColor.hex(for: request.fromUserId),
                size: 44
            )

            // Name + context
            VStack(alignment: .leading, spacing: 2) {
                Text(request.displayName ?? request.username)
                    .font(.lexend(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Text(request.contextLine)
                    .font(.lexend(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
                    .tracking(0.5)
            }

            Spacer()

            // Decline button
            Button {
                Task {
                    await socialViewModel.declineRequest(request)
                    // Update profile count
                    viewModel.pendingRequestsCount = socialViewModel.pendingRequests.count
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.lexend(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(Circle())
            }

            // Accept button
            Button {
                Task {
                    await socialViewModel.acceptRequest(request)
                    // Update profile counts
                    viewModel.pendingRequestsCount = socialViewModel.pendingRequests.count
                    let friends = await SocialHubService.shared.fetchFriends()
                    viewModel.friendsCount = friends.count
                }
            } label: {
                Image(systemName: "checkmark")
                    .font(.lexend(size: 14, weight: .medium))
                    .foregroundColor(Color(red: 0.129, green: 0.110, blue: 0.067))
                    .frame(width: 36, height: 36)
                    .background(AppColors.accent)
                    .clipShape(Circle())
            }
        }
        .padding(Layout.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .fill(AppColors.surface)
        )
    }
}

// MARK: - Shared Avatar Helper

private func avatarCircle(initials: String, colorHex: String, size: CGFloat) -> some View {
    ZStack {
        Circle()
            .fill(Color(hex: colorHex))

        Text(initials)
            .font(.lexend(size: size * 0.38, weight: .bold))
            .foregroundColor(.white)
    }
    .frame(width: size, height: size)
}
