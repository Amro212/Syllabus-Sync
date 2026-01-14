//
//  CustomTabBar.swift
//  Syllabus Sync
//
//  Created by Assistant on 2025-01-01.
//

import SwiftUI

struct CustomTabBar: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var themeManager: ThemeManager
    
    // Action handler for the center FAB
    var onFabTapped: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Dashboard Tab
            TabBarItem(
                icon: "dashboard",
                title: "Dashboard",
                isSelected: navigationManager.selectedTabRoute == .dashboard,
                isFilled: true // Dashboard icon needs special handling if using material symbols, but we map to SF Symbols
            ) {
                navigationManager.switchTab(to: .dashboard)
            }
            .frame(maxWidth: .infinity)
            
            // Reminders Tab
            TabBarItem(
                icon: "notifications",
                title: "Reminders",
                isSelected: navigationManager.selectedTabRoute == .reminders
            ) {
                navigationManager.switchTab(to: .reminders)
            }
            .frame(maxWidth: .infinity)
            
            // Center Action Button (Floating Style)
            // We use a ZStack to allow the button to overflow if needed,
            // though the design keeps it relatively inline but large.
            Button(action: {
                HapticFeedbackManager.shared.mediumImpact()
                onFabTapped()
            }) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent)
                        .shadow(color: AppColors.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "plus")
                        .font(.lexend(size: 32, weight: .light)) // Thin/Light weight matches the design better
                        .foregroundColor(.white)
                }
                .frame(width: 64, height: 64)
            }
            .offset(y: -24) // Lift it up slightly to break the bar boundary
            .frame(maxWidth: .infinity)
            
            // Preview Tab (extraction preview - for debugging)
            TabBarItem(
                icon: "eye",
                title: "Preview",
                isSelected: navigationManager.selectedTabRoute == .preview
            ) {
                navigationManager.switchTab(to: .preview)
            }
            .frame(maxWidth: .infinity)
            
            // Settings Tab
            TabBarItem(
                icon: "settings",
                title: "Settings",
                isSelected: navigationManager.selectedTabRoute == .settings
            ) {
                navigationManager.switchTab(to: .settings)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Layout.Spacing.lg) // Increased to bring icons closer
        .padding(.top, Layout.Spacing.xs)
        .padding(.bottom, -10) // Negative padding to pull it down further
        .ignoresSafeArea(edges: .bottom) // Override default safe area spacing
        .background(
            // Use background-dark with opacity/blur for the bar itself
            AppColors.background
                .opacity(0.9)
                .ignoresSafeArea()
                .shadow(color: AppColors.shadow.opacity(0.1), radius: 10, x: 0, y: -2)
                .overlay(
                    Rectangle()
                        .fill(Material.ultraThin)
                        .opacity(0.5)
                        .allowsHitTesting(false)
                )
                // In the design, it's a rounded container at the bottom, not full width edge-to-edge necessarily, 
                // but usually tab bars are full width. The image shows rounded corners at top.
                .clipShape(
                    RoundedCornerShape(radius: 20, corners: [.topLeft, .topRight])
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

private struct TabBarItem: View {
    let icon: String // We will map these string names to SF Symbols
    let title: String
    let isSelected: Bool
    var isFilled: Bool = false
    let action: () -> Void
    
    // Mapping from Material Symbol names (design) to SF Symbols
    private var systemImageName: String {
        switch icon {
        case "dashboard": return "square.grid.2x2" + (isSelected || isFilled ? ".fill" : "")
        case "notifications": return "bell" + (isSelected ? ".fill" : "")
        case "eye": return "eye" + (isSelected ? ".fill" : "")
        case "calendar_month": return "calendar"
        case "settings": return "gearshape" + (isSelected ? ".fill" : "")
        default: return "questionmark"
        }
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: systemImageName)
                    .font(.lexend(size: 24, weight: .regular))
                
                Text(title)
                    .font(.tabLabel)
            }
            .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }
}

// Helper for rounded corners on specific sides
private struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
