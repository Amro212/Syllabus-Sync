import SwiftUI

struct CustomTabBar: View {
    @EnvironmentObject private var navigationManager: AppNavigationManager

    let onFabTapped: () -> Void
    var isFabExpanded = false

    var body: some View {
        HStack(spacing: 4) {
            tab(.dashboard, icon: "square.grid.2x2")
            tab(.reminders, icon: "bell")
            quickActionsButton
                .frame(maxWidth: .infinity)
            tab(.friends, icon: "person.2")
            tab(.profile, icon: "person.crop.circle")
        }
        .padding(.horizontal, Layout.Spacing.sm)
        .padding(.vertical, Layout.Spacing.xs)
        .background {
            AppColors.surface
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Divider().allowsHitTesting(false)
        }
    }

    private var quickActionsButton: some View {
        Button {
            HapticFeedbackManager.shared.mediumImpact()
            onFabTapped()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 27, weight: .medium))
                .foregroundStyle(AppColors.background)
                .rotationEffect(.degrees(isFabExpanded ? 45 : 0))
                .frame(width: 54, height: 54)
                .background(AppColors.accent, in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFabExpanded ? "Close quick actions" : "Open quick actions")
    }

    private func tab(_ route: AppRoute, icon: String) -> some View {
        let isSelected = navigationManager.selectedTabRoute == route

        return Button {
            navigationManager.switchTab(to: route)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: isSelected ? icon + ".fill" : icon)
                    .font(.system(size: 22))
                    .accessibilityHidden(true)

                Text(route.title)
                    .font(.tabLabel)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? AppColors.accent : AppColors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
