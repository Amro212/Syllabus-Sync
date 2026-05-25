//
//  SocialHubView.swift
//  Syllabus Sync
//
//  Main Social Hub modal view with Friends and Discover tabs.
//  Matches the wireframe: dark modal with gold accents, blurred background peek.
//

import SwiftUI

// MARK: - Social Hub View

struct SocialHubView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SocialHubViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            AppColors.background.ignoresSafeArea()

            if viewModel.needsUsername && !viewModel.isLoadingUsername {
                CreateUsernameView(viewModel: viewModel)
            } else {
                mainContent
            }

            // Toast overlay
            if viewModel.showToast, let message = viewModel.toastMessage {
                VStack {
                    Spacer()
                    toastBanner(message)
                        .padding(.bottom, Layout.Spacing.xl)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .task {
            await viewModel.loadInitialData()
        }
        .onChange(of: viewModel.showToast) { _, show in
            if show {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { viewModel.showToast = false }
                }
            }
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
                .padding(.top, Layout.Spacing.md)

            // My ID Card
            myIdCard
                .padding(.horizontal, Layout.Spacing.lg)
                .padding(.top, Layout.Spacing.md)

            // Segmented Control
            segmentedControl
                .padding(.horizontal, Layout.Spacing.lg)
                .padding(.top, Layout.Spacing.md)

            // Search Bar
            searchBar
                .padding(.horizontal, Layout.Spacing.lg)
                .padding(.top, Layout.Spacing.md)

            // Tab Content
            ScrollView {
                if viewModel.selectedTab == .friends {
                    friendsTabContent
                        .padding(.horizontal, Layout.Spacing.lg)
                        .padding(.top, Layout.Spacing.md)
                } else {
                    discoverTabContent
                        .padding(.horizontal, Layout.Spacing.lg)
                        .padding(.top, Layout.Spacing.md)
                }

                Spacer(minLength: Layout.Spacing.massive)
            }
        }
        .sheet(isPresented: $viewModel.showFriendSchedule) {
            if let friend = viewModel.selectedFriend {
                FriendScheduleView(viewModel: viewModel, friend: friend)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(20)
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("SOCIAL HUB")
                .font(.lexend(size: 24, weight: .bold))
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Button {
                HapticFeedbackManager.shared.lightImpact()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.lexend(size: 18, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, Layout.Spacing.lg)
    }

    // MARK: - My ID Card

    private var myIdCard: some View {
        HStack(spacing: Layout.Spacing.md) {
            // Avatar
            Image(systemName: "person.fill")
                .font(.lexend(size: 20, weight: .medium))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 44, height: 44)
                .background(AppColors.surfaceSecondary)
                .clipShape(Circle())

            // Label + Username
            VStack(alignment: .leading, spacing: 2) {
                Text("MY ID")
                    .font(.lexend(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .tracking(1)

                if viewModel.isLoadingUsername {
                    ShimmerView()
                        .frame(width: 100, height: 16)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Text(viewModel.myUsername ?? "—")
                        .font(.lexend(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                }
            }

            Spacer()

            // Copy Button
            Button {
                if let username = viewModel.myUsername {
                    UIPasteboard.general.string = username
                    HapticFeedbackManager.shared.success()
                    viewModel.toastMessage = "Username copied!"
                    withAnimation { viewModel.showToast = true }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                        .font(.lexend(size: 13, weight: .medium))
                    Text("COPY")
                        .font(.lexend(size: 12, weight: .semibold))
                        .tracking(0.5)
                }
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Layout.Spacing.sm)
                .padding(.vertical, 6)
                .background(AppColors.surfaceSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.sm))
            }
        }
        .padding(Layout.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .fill(AppColors.surface)
        )
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: 0) {
            ForEach(SocialHubViewModel.Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectTab(tab)
                    }
                    HapticFeedbackManager.shared.lightImpact()
                } label: {
                    Text(tab.rawValue)
                        .font(.lexend(size: 14, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(viewModel.selectedTab == tab
                            ? Color(red: 0.129, green: 0.110, blue: 0.067)
                            : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(viewModel.selectedTab == tab
                                    ? AppColors.accent
                                    : Color.clear)
                        )
                }
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(AppColors.surface)
        )
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Layout.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.lexend(size: 16, weight: .regular))
                .foregroundColor(AppColors.textTertiary)

            TextField(
                viewModel.selectedTab == .friends
                    ? "Quick Search..."
                    : "Search usernames or browse recommendations...",
                text: viewModel.selectedTab == .friends
                    ? $viewModel.friendsSearchText
                    : $viewModel.discoverSearchText
            )
            .font(.lexend(size: 15, weight: .regular))
            .foregroundColor(AppColors.textPrimary)
            .autocapitalization(.none)
            .autocorrectionDisabled()
            .onChange(of: viewModel.discoverSearchText) { _, _ in
                viewModel.handleDiscoverSearchChange()
            }
        }
        .padding(.horizontal, Layout.Spacing.md)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .fill(AppColors.surface)
        )
    }

    // MARK: - Friends Tab Content

    @ViewBuilder
    private var friendsTabContent: some View {
        if viewModel.isLoadingFriends {
            friendsShimmer
        } else {
            VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
                // Pending Requests Section
                if !viewModel.pendingRequests.isEmpty {
                    pendingRequestsSection
                }

                // My Connections Section
                connectionsSection
            }
        }
    }

    // MARK: - Pending Requests

    private var pendingRequestsSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            // Header with count pill
            HStack(spacing: Layout.Spacing.sm) {
                Text("PENDING REQUESTS")
                    .font(.lexend(size: 13, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(1)

                Text("\(viewModel.pendingRequests.count) PENDING")
                    .font(.lexend(size: 11, weight: .bold))
                    .foregroundColor(Color(red: 0.129, green: 0.110, blue: 0.067))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(AppColors.accent)
                    )

                Spacer()
            }

            // Request cards
            ForEach(viewModel.pendingRequests) { request in
                pendingRequestRow(request)
            }
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
                Task { await viewModel.declineRequest(request) }
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
                Task { await viewModel.acceptRequest(request) }
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

    // MARK: - My Connections Grid

    private var connectionsSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            // Header with count
            HStack {
                Text("MY CONNECTIONS")
                    .font(.lexend(size: 13, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .tracking(1)

                Spacer()

                Text("\(viewModel.filteredFriends.count) FRIENDS")
                    .font(.lexend(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
            }

            if viewModel.filteredFriends.isEmpty {
                emptyFriendsState
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: Layout.Spacing.sm),
                    GridItem(.flexible(), spacing: Layout.Spacing.sm)
                ]

                LazyVGrid(columns: columns, spacing: Layout.Spacing.sm) {
                    ForEach(viewModel.filteredFriends) { friend in
                        friendCard(friend)
                    }
                }
            }
        }
    }

    private func friendCard(_ friend: FriendDisplay) -> some View {
        Button {
            Task { await viewModel.openFriendSchedule(friend) }
        } label: {
            VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                HStack {
                    Image(systemName: "person.fill")
                        .font(.lexend(size: 16, weight: .regular))
                        .foregroundColor(AppColors.textTertiary)

                    Spacer()

                    Image(systemName: "message.fill")
                        .font(.lexend(size: 13, weight: .regular))
                        .foregroundColor(AppColors.textTertiary)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(friend.displayName ?? friend.username)
                        .font(.lexend(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(friend.courseName.map { "Shared course: \($0)" } ?? "Tap to view schedule")
                        .font(.lexend(size: 12, weight: .regular))
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(Layout.Spacing.md)
            .frame(height: 110)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                    .fill(AppColors.surface)
            )
        }
    }

    // MARK: - Discover Tab Content

    @ViewBuilder
    private var discoverTabContent: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            if viewModel.isLoadingDiscover {
                discoverShimmer
            } else if viewModel.discoverResults.isEmpty {
                if viewModel.discoverSearchText.count >= 2 {
                    emptySearchState
                } else {
                    emptyRecommendationsState
                }
            } else {
                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    Text(viewModel.discoverSearchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
                        ? "SEARCH RESULTS"
                        : "RECOMMENDED FOR YOU")
                        .font(.lexend(size: 13, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .tracking(1)

                    Text(viewModel.discoverSearchText.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
                        ? "Ranked by mutual friends and shared courses."
                        : "People with overlap in your network or classes.")
                        .font(.lexend(size: 12, weight: .regular))
                        .foregroundColor(AppColors.textTertiary)
                }

                ForEach(viewModel.discoverResults) { user in
                    discoverUserRow(user)
                }
            }
        }
    }

    private func discoverUserRow(_ user: DiscoverUserDisplay) -> some View {
        HStack(spacing: Layout.Spacing.sm) {
            avatarCircle(
                initials: AvatarColor.initials(from: user.username),
                colorHex: AvatarColor.hex(for: user.id),
                size: 40
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(user.displayName ?? user.username)
                    .font(.lexend(size: 14, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                if let displayName = user.displayName, displayName != user.username {
                    Text("@\(user.username)")
                        .font(.lexend(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .lineLimit(1)
                }

                // Color-coded context chips
                HStack(spacing: 4) {
                    if user.hasMutualFriends {
                        contextChip(
                            icon: "person.2.fill",
                            text: "\(user.mutualFriendsCount) mutual",
                            color: Color(hex: "#AB47BC")
                        )
                    }

                    if user.hasSharedCourses {
                        ForEach(user.sharedCoursePreview, id: \.self) { code in
                            contextChip(
                                icon: nil,
                                text: code,
                                color: Color(hex: "#26C6DA")
                            )
                        }

                        if user.remainingSharedCourseCount > 0 {
                            contextChip(
                                icon: nil,
                                text: "+\(user.remainingSharedCourseCount)",
                                color: Color(hex: "#26C6DA")
                            )
                        }
                    }
                }
            }

            Spacer(minLength: Layout.Spacing.xs)

            discoverActionButton(for: user)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .fill(AppColors.surface)
        )
    }

    // MARK: - Shared Components

    private func avatarCircle(initials: String, colorHex: String, size: CGFloat) -> some View {
        Text(initials)
            .font(.lexend(size: size * 0.36, weight: .bold))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                Circle().fill(Color(hex: colorHex))
            )
    }

    private func toastBanner(_ message: String) -> some View {
        Text(message)
            .font(.lexend(size: 14, weight: .medium))
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.vertical, Layout.Spacing.sm)
            .background(
                Capsule().fill(AppColors.surface)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            )
            .padding(.horizontal, Layout.Spacing.xl)
    }

    // MARK: - Empty / Loading States

    private var emptyFriendsState: some View {
        VStack(spacing: Layout.Spacing.md) {
            Image(systemName: "person.2.slash")
                .font(.lexend(size: 36, weight: .regular))
                .foregroundColor(AppColors.textTertiary)

            Text("No connections yet")
                .font(.lexend(size: 16, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            Text("Search for classmates in the Discover tab")
                .font(.lexend(size: 13, weight: .regular))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.Spacing.xxl)
    }

    private var emptySearchState: some View {
        VStack(spacing: Layout.Spacing.md) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.lexend(size: 36, weight: .regular))
                .foregroundColor(AppColors.textTertiary)

            Text("No users found")
                .font(.lexend(size: 16, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            Text("Try a different username")
                .font(.lexend(size: 13, weight: .regular))
                .foregroundColor(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.Spacing.xxl)
    }

    private var emptyRecommendationsState: some View {
        VStack(spacing: Layout.Spacing.md) {
            Image(systemName: "person.2.wave.2")
                .font(.lexend(size: 36, weight: .regular))
                .foregroundColor(AppColors.textTertiary)

            Text("No recommendations yet")
                .font(.lexend(size: 16, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            Text("Add classmates and courses will start surfacing mutual connections here.")
                .font(.lexend(size: 13, weight: .regular))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.Spacing.xxl)
    }

    private var friendsShimmer: some View {
        VStack(spacing: Layout.Spacing.md) {
            ForEach(0..<3, id: \.self) { _ in
                ShimmerView()
                    .frame(height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.lg))
            }
        }
    }

    private var discoverShimmer: some View {
        VStack(spacing: Layout.Spacing.md) {
            ForEach(0..<4, id: \.self) { _ in
                ShimmerView()
                    .frame(height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.lg))
            }
        }
    }

    private func discoverActionButton(for user: DiscoverUserDisplay) -> some View {
        Group {
            switch user.requestState {
            case .none:
                Button {
                    Task { await viewModel.sendRequest(to: user) }
                } label: {
                    Text("ADD FRIEND")
                        .font(.lexend(size: 10, weight: .bold))
                        .foregroundColor(Color(red: 0.129, green: 0.110, blue: 0.067))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().fill(AppColors.accent)
                        )
                }
            case .requested:
                Button {
                    Task { await viewModel.cancelRequest(to: user) }
                } label: {
                    Text("REQUESTED")
                        .font(.lexend(size: 10, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            Capsule().stroke(AppColors.textTertiary, lineWidth: 1)
                        )
                }
            case .friends:
                HStack(spacing: 3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                    Text("FRIENDS")
                        .font(.lexend(size: 10, weight: .bold))
                }
                .foregroundColor(Color(hex: "#4CAF50"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(Color(hex: "#4CAF50").opacity(0.15))
                )
            }
        }
    }

    private func contextChip(icon: String?, text: String, color: Color) -> some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
                .font(.lexend(size: 10, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(color.opacity(0.15))
        )
    }
}
