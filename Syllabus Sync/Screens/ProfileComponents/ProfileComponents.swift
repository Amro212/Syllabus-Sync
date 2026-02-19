//
//  ProfileComponents.swift
//  Syllabus Sync
//
//  Reusable UI components for the profile interface.
//  Matches the gold-on-dark design system.
//

import SwiftUI

// MARK: - Profile Header View

struct ProfileHeaderView: View {
    @ObservedObject var viewModel: ProfileViewModel

    var body: some View {
        VStack(spacing: Layout.Spacing.lg) {
            // Avatar - Large circular avatar
            ZStack {
                if let photoURL = viewModel.photoURL {
                    AsyncImage(url: photoURL) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        defaultAvatar
                    }
                } else {
                    defaultAvatar
                }
            }
            .frame(width: 100, height: 100)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppColors.accent, lineWidth: 3))
            .shadow(color: AppColors.accent.opacity(0.3), radius: 10, y: 5)

            // User Info
            VStack(spacing: Layout.Spacing.xs) {
                Text(viewModel.displayName.isEmpty ? viewModel.username : viewModel.displayName)
                    .font(.lexend(size: 24, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                if !viewModel.displayName.isEmpty {
                    Text("@\(viewModel.username)")
                        .font(.lexend(size: 15, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }

                if !viewModel.bio.isEmpty {
                    Text(viewModel.bio)
                        .font(.lexend(size: 14, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Layout.Spacing.lg)
                        .padding(.top, Layout.Spacing.xs)
                }

                // Email with provider badge
                HStack(spacing: Layout.Spacing.sm) {
                    Image(systemName: "envelope.fill")
                        .font(.lexend(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)

                    Text(viewModel.email)
                        .font(.lexend(size: 13, weight: .regular))
                        .foregroundColor(AppColors.textTertiary)

                    // Provider badge
                    providerBadge
                }
                .padding(.top, Layout.Spacing.xs)
            }
        }
        .padding(.vertical, Layout.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .fill(AppColors.surface)
        )
    }

    private var defaultAvatar: some View {
        ZStack {
            Circle()
                .fill(AppColors.surfaceSecondary)

            Text(avatarInitials)
                .font(.lexend(size: 40, weight: .bold))
                .foregroundColor(AppColors.accent)
        }
    }

    private var avatarInitials: String {
        let name = viewModel.displayName.isEmpty ? viewModel.username : viewModel.displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var providerBadge: some View {
        Group {
            switch viewModel.provider {
            case .google:
                Label {
                    Text("Google")
                        .font(.lexend(size: 11, weight: .semibold))
                } icon: {
                    Image(systemName: "g.circle.fill")
                        .font(.lexend(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, Layout.Spacing.sm)
                .padding(.vertical, 3)
                .background(Color.blue)
                .clipShape(Capsule())
            case .email:
                Label {
                    Text("Email")
                        .font(.lexend(size: 11, weight: .semibold))
                } icon: {
                    Image(systemName: "envelope.circle.fill")
                        .font(.lexend(size: 11, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.129, green: 0.110, blue: 0.067))
                .padding(.horizontal, Layout.Spacing.sm)
                .padding(.vertical, 3)
                .background(AppColors.accent)
                .clipShape(Capsule())
            default:
                EmptyView()
            }
        }
    }
}

// MARK: - Profile Section

struct ProfileSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            Text(title.uppercased())
                .font(.lexend(size: 13, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)
                .padding(.horizontal, Layout.Spacing.lg)

            VStack(spacing: Layout.Spacing.sm) {
                content
            }
            .padding(.horizontal, Layout.Spacing.lg)
        }
    }
}

// MARK: - Editable Field Row

struct EditableFieldRow: View {
    let title: String
    let value: String
    let icon: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Layout.Spacing.md) {
                Image(systemName: icon)
                    .font(.lexend(size: 18, weight: .medium))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.lexend(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(0.5)

                    Text(value.isEmpty ? "Not set" : value)
                        .font(.lexend(size: 16, weight: .medium))
                        .foregroundColor(value.isEmpty ? AppColors.textTertiary : AppColors.textPrimary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "pencil")
                    .font(.lexend(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Layout.Spacing.md)
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.lg)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: Layout.Spacing.md) {
            Image(systemName: icon)
                .font(.lexend(size: 18, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.lexend(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .tracking(0.5)

                Text(value)
                    .font(.lexend(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.lg)
    }
}

// MARK: - Navigation Row

struct NavigationRow: View {
    let title: String
    let icon: String
    var badge: Int = 0
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Layout.Spacing.md) {
                Image(systemName: icon)
                    .font(.lexend(size: 18, weight: .medium))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24)

                Text(title)
                    .font(.lexend(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if badge > 0 {
                    Text("\(badge)")
                        .font(.lexend(size: 12, weight: .bold))
                        .foregroundColor(Color(red: 0.129, green: 0.110, blue: 0.067))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColors.accent)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.lexend(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(Layout.Spacing.md)
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.lg)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Toggle Row

struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Layout.Spacing.md) {
            Image(systemName: icon)
                .font(.lexend(size: 18, weight: .medium))
                .foregroundColor(AppColors.accent)
                .frame(width: 24)

            Text(title)
                .font(.lexend(size: 16, weight: .medium))
                .foregroundColor(AppColors.textPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(AppColors.accent)
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.lg)
    }
}

// MARK: - Action Row

struct ActionRow: View {
    let title: String
    let icon: String
    var isDestructive: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Layout.Spacing.md) {
                Image(systemName: icon)
                    .font(.lexend(size: 18, weight: .medium))
                    .foregroundColor(isDestructive ? .red : AppColors.accent)
                    .frame(width: 24)

                Text(title)
                    .font(.lexend(size: 16, weight: .medium))
                    .foregroundColor(isDestructive ? .red : AppColors.textPrimary)

                Spacer()
            }
            .padding(Layout.Spacing.md)
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.lg)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Schedule Visibility Picker

struct ScheduleVisibilityPicker: View {
    @Binding var selectedVisibility: ScheduleVisibility
    let onChange: (ScheduleVisibility) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack(spacing: Layout.Spacing.sm) {
                Image(systemName: "eye.fill")
                    .font(.lexend(size: 18, weight: .medium))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("SCHEDULE VISIBILITY")
                        .font(.lexend(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(0.5)

                    Text(selectedVisibility.description)
                        .font(.lexend(size: 13, weight: .regular))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, Layout.Spacing.md)
            .padding(.top, Layout.Spacing.md)

            // Visibility options
            VStack(spacing: Layout.Spacing.xs) {
                ForEach(ScheduleVisibility.allCases, id: \.self) { visibility in
                    Button {
                        HapticFeedbackManager.shared.lightImpact()
                        selectedVisibility = visibility
                        Task {
                            await onChange(visibility)
                        }
                    } label: {
                        HStack(spacing: Layout.Spacing.md) {
                            Image(systemName: visibility.icon)
                                .font(.lexend(size: 16, weight: .medium))
                                .foregroundColor(selectedVisibility == visibility ? AppColors.accent : AppColors.textTertiary)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(visibility.displayName)
                                    .font(.lexend(size: 15, weight: .semibold))
                                    .foregroundColor(selectedVisibility == visibility ? AppColors.textPrimary : AppColors.textSecondary)

                                Text(visibility.description)
                                    .font(.lexend(size: 12, weight: .regular))
                                    .foregroundColor(AppColors.textTertiary)
                            }

                            Spacer()

                            if selectedVisibility == visibility {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.lexend(size: 20, weight: .medium))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(Layout.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                                .fill(selectedVisibility == visibility ? AppColors.accent.opacity(0.1) : AppColors.surfaceSecondary)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Layout.Spacing.md)
            .padding(.bottom, Layout.Spacing.md)
        }
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.lg)
    }
}

// MARK: - Theme Picker Row

struct ThemePickerRow: View {
    @Binding var selectedTheme: String
    let themeManager: ThemeManager?

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack(spacing: Layout.Spacing.sm) {
                Image(systemName: "paintbrush.fill")
                    .font(.lexend(size: 18, weight: .medium))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text("THEME")
                        .font(.lexend(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(0.5)

                    Text(themeDisplayName)
                        .font(.lexend(size: 13, weight: .regular))
                        .foregroundColor(AppColors.textTertiary)
                }
            }
            .padding(.horizontal, Layout.Spacing.md)
            .padding(.top, Layout.Spacing.md)

            // Theme options
            VStack(spacing: Layout.Spacing.xs) {
                ForEach(["light", "dark", "system"], id: \.self) { theme in
                    Button {
                        HapticFeedbackManager.shared.lightImpact()
                        selectedTheme = theme
                        updateThemeManager(theme)
                    } label: {
                        HStack(spacing: Layout.Spacing.md) {
                            Image(systemName: themeIcon(theme))
                                .font(.lexend(size: 16, weight: .medium))
                                .foregroundColor(selectedTheme == theme ? AppColors.accent : AppColors.textTertiary)
                                .frame(width: 24)

                            Text(themeDisplayName(theme))
                                .font(.lexend(size: 15, weight: .semibold))
                                .foregroundColor(selectedTheme == theme ? AppColors.textPrimary : AppColors.textSecondary)

                            Spacer()

                            if selectedTheme == theme {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.lexend(size: 20, weight: .medium))
                                    .foregroundColor(AppColors.accent)
                            }
                        }
                        .padding(Layout.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                                .fill(selectedTheme == theme ? AppColors.accent.opacity(0.1) : AppColors.surfaceSecondary)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, Layout.Spacing.md)
            .padding(.bottom, Layout.Spacing.md)
        }
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.lg)
    }

    private var themeDisplayName: String {
        themeDisplayName(selectedTheme)
    }

    private func themeDisplayName(_ theme: String) -> String {
        switch theme {
        case "light": return "Light"
        case "dark": return "Dark"
        case "system": return "System"
        default: return "System"
        }
    }

    private func themeIcon(_ theme: String) -> String {
        switch theme {
        case "light": return "sun.max.fill"
        case "dark": return "moon.fill"
        case "system": return "circle.lefthalf.filled"
        default: return "circle.lefthalf.filled"
        }
    }

    private func updateThemeManager(_ themeString: String) {
        guard let manager = themeManager else { return }

        let theme: AppTheme
        switch themeString {
        case "light":
            theme = .light
        case "dark":
            theme = .dark
        case "system":
            theme = .system
        default:
            theme = .system
        }

        manager.currentTheme = theme
    }
}

// MARK: - Toast Banner

struct ToastBanner: View {
    let message: String

    var body: some View {
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
}
