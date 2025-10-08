//
//  ThemeManager.swift
//  Syllabus Sync
//
//  Created by Cursor on 2025-09-06.
//

import SwiftUI
import Combine

/// Theme configuration options
enum AppTheme: String, CaseIterable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
    
    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

/// Centralized theme management for the app
/// Handles theme persistence and provides reactive theme updates
class ThemeManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current theme setting
    @Published var currentTheme: AppTheme = .system {
        didSet {
            saveTheme()
        }
    }
    
    /// Whether the interface is currently in dark mode
    @Published var isDarkMode: Bool = false
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let themeKey = "app_theme"
    
    // MARK: - Initialization
    
    init() {
        loadTheme()
        updateDarkModeStatus()
    }
    
    // MARK: - Public Methods
    
    /// Toggles between light and dark theme
    func toggleTheme() {
        switch currentTheme {
        case .light:
            currentTheme = .dark
        case .dark:
            currentTheme = .light
        case .system:
            // When system, toggle to the opposite of current appearance
            currentTheme = isDarkMode ? .light : .dark
        }
    }
    
    /// Sets a specific theme
    func setTheme(_ theme: AppTheme) {
        currentTheme = theme
    }
    
    /// Updates dark mode status based on current environment
    func updateDarkModeStatus() {
        // This will be updated from the environment in the view
        // For now, we'll use a default based on system settings
        if currentTheme == .system {
            // System will handle this automatically
            isDarkMode = UITraitCollection.current.userInterfaceStyle == .dark
        } else {
            isDarkMode = currentTheme == .dark
        }
    }
    
    // MARK: - Private Methods
    
    private func loadTheme() {
        let savedTheme = userDefaults.string(forKey: themeKey) ?? AppTheme.system.rawValue
        currentTheme = AppTheme(rawValue: savedTheme) ?? .system
    }
    
    private func saveTheme() {
        userDefaults.set(currentTheme.rawValue, forKey: themeKey)
    }
}

// MARK: - ThemeToggle Component

/// Animated theme toggle component with spring animations
struct ThemeToggle: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: Layout.Spacing.sm) {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                ThemeButton(
                    theme: theme,
                    isSelected: themeManager.currentTheme == theme,
                    action: {
                        selectTheme(theme)
                    }
                )
            }
        }
        .padding(Layout.Spacing.sm)
        .background(AppColors.surfaceSecondary)
        .cornerRadius(Layout.CornerRadius.md)
        .onAppear {
            themeManager.updateDarkModeStatus()
        }
        .onChange(of: colorScheme) {
            themeManager.updateDarkModeStatus()
        }
    }
    
    private func selectTheme(_ theme: AppTheme) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
            themeManager.setTheme(theme)
            isAnimating = true
        }
        
        // Reset animation state
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAnimating = false
        }
    }
}

// MARK: - Theme Button Component

private struct ThemeButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
            action()
        }) {
            Image(systemName: theme.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.sm)
                        .fill(isSelected ? AppColors.accent : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Simple Theme Toggle

/// Simple animated toggle for light/dark mode only
struct SimpleThemeToggle: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.colorScheme) private var colorScheme
    
    private var isDark: Bool {
        if themeManager.currentTheme == .system {
            return colorScheme == .dark
        }
        return themeManager.currentTheme == .dark
    }
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                themeManager.toggleTheme()
            }
        }) {
            HStack(spacing: Layout.Spacing.sm) {
                Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(AppColors.accent)
                    .rotationEffect(.degrees(isDark ? 0 : 180))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isDark)
                
                Text(isDark ? "Dark" : "Light")
                    .font(.buttonSecondary)
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(Layout.Spacing.md)
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.md)
            .shadow(color: AppColors.shadow.opacity(0.1), radius: Layout.Shadow.small.radius, x: Layout.Shadow.small.x, y: Layout.Shadow.small.y)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            themeManager.updateDarkModeStatus()
        }
        .onChange(of: colorScheme) {
            themeManager.updateDarkModeStatus()
        }
    }
}

// MARK: - Environment Integration

/// View modifier to apply theme management to the app
/// Takes an explicit ThemeManager to avoid requiring an EnvironmentObject in previews
struct ThemeEnvironment: ViewModifier {
    @ObservedObject var themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(themeManager.currentTheme.colorScheme)
    }
}

extension View {
    /// Applies theme management to the view hierarchy with an explicit manager
    func themeManaged(_ themeManager: ThemeManager) -> some View {
        modifier(ThemeEnvironment(themeManager: themeManager))
    }
}

// MARK: - Preview Components

#if DEBUG
struct ThemeManager_Previews: PreviewProvider {
    static var previews: some View {
        ThemeShowcase()
            .preferredColorScheme(.light)
            .previewDisplayName("Theme Components - Light")
        
        ThemeShowcase()
            .preferredColorScheme(.dark)
            .previewDisplayName("Theme Components - Dark")
    }
}

private struct ThemeShowcase: View {
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.xxl) {
                
                // Theme Toggle Showcase
                VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
                    Text("Theme Toggle Components").titleM(color: AppColors.accent)
                    
                    VStack(spacing: Layout.Spacing.lg) {
                        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                            Text("Full Theme Toggle").titleS()
                            Text("Supports Light, Dark, and System themes").bodyS()
                            ThemeToggle()
                        }
                        
                        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                            Text("Simple Theme Toggle").titleS()
                            Text("Quick Light/Dark mode switch").bodyS()
                            SimpleThemeToggle()
                        }
                    }
                }
                
                // Theme Preview Cards
                VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
                    Text("Theme Preview").titleM(color: AppColors.accent)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Layout.Spacing.md) {
                        ThemePreviewCard(title: "Surface Colors") {
                            VStack(spacing: Layout.Spacing.xs) {
                                Rectangle()
                                    .fill(AppColors.background)
                                    .frame(height: 20)
                                    .cornerRadius(Layout.CornerRadius.xs)
                                Rectangle()
                                    .fill(AppColors.surface)
                                    .frame(height: 20)
                                    .cornerRadius(Layout.CornerRadius.xs)
                                Rectangle()
                                    .fill(AppColors.surfaceSecondary)
                                    .frame(height: 20)
                                    .cornerRadius(Layout.CornerRadius.xs)
                            }
                        }
                        
                        ThemePreviewCard(title: "Text Colors") {
                            VStack(spacing: Layout.Spacing.xs) {
                                Text("Primary").bodyS(color: AppColors.textPrimary)
                                Text("Secondary").bodyS(color: AppColors.textSecondary)
                                Text("Tertiary").bodyS(color: AppColors.textTertiary)
                            }
                        }
                        
                        ThemePreviewCard(title: "Accent & Status") {
                            VStack(spacing: Layout.Spacing.xs) {
                                HStack {
                                    Circle().fill(AppColors.accent).frame(width: 12, height: 12)
                                    Text("Accent").captionS()
                                    Spacer()
                                }
                                HStack {
                                    Circle().fill(AppColors.success).frame(width: 12, height: 12)
                                    Text("Success").captionS()
                                    Spacer()
                                }
                                HStack {
                                    Circle().fill(AppColors.warning).frame(width: 12, height: 12)
                                    Text("Warning").captionS()
                                    Spacer()
                                }
                            }
                        }
                        
                        ThemePreviewCard(title: "Shadows & Depth") {
                            VStack(spacing: Layout.Spacing.sm) {
                                Rectangle()
                                    .fill(AppColors.surface)
                                    .frame(height: 16)
                                    .cornerRadius(Layout.CornerRadius.xs)
                                    .shadow(color: AppColors.shadow.opacity(0.1), radius: Layout.Shadow.small.radius, x: Layout.Shadow.small.x, y: Layout.Shadow.small.y)
                                
                                Rectangle()
                                    .fill(AppColors.surface)
                                    .frame(height: 16)
                                    .cornerRadius(Layout.CornerRadius.xs)
                                    .shadow(color: AppColors.shadow.opacity(0.1), radius: Layout.Shadow.medium.radius, x: Layout.Shadow.medium.x, y: Layout.Shadow.medium.y)
                            }
                        }
                    }
                }
                
                // Sample App Content
                VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
                    Text("Sample App Content").titleM(color: AppColors.accent)
                    
                    SampleContentCard()
                }
            }
            .padding(Layout.Spacing.lg)
        }
        .background(AppColors.background)
        .environmentObject(themeManager)
    }
}

private struct ThemePreviewCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            Text(title).captionL(color: AppColors.textSecondary)
            content
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.md)
        .shadow(color: AppColors.shadow.opacity(0.08), radius: Layout.Shadow.small.radius, x: Layout.Shadow.small.x, y: Layout.Shadow.small.y)
    }
}

private struct SampleContentCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack {
                Text("CS101").code()
                Spacer()
                Text("Due Soon").captionL(color: AppColors.warning)
            }
            
            Text("Data Structures Assignment").titleS()
            Text("Implement a balanced binary search tree with insertion, deletion, and traversal methods.").body()
            
            HStack {
                Text("Assigned: Today").caption()
                Spacer()
                Text("100 pts").captionL(color: AppColors.accent)
            }
            
            HStack(spacing: Layout.Spacing.sm) {
                Button("View Details") {}
                    .font(.buttonSecondary)
                    .foregroundColor(AppColors.accent)
                    .padding(Layout.Spacing.sm)
                    .background(AppColors.surfaceSecondary)
                    .cornerRadius(Layout.CornerRadius.sm)
                
                Spacer()
                
                Button("Start Now") {}
                    .font(.buttonSecondary)
                    .foregroundColor(.white)
                    .padding(Layout.Spacing.sm)
                    .background(AppColors.accent)
                    .cornerRadius(Layout.CornerRadius.sm)
            }
        }
        .padding(Layout.Spacing.lg)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.lg)
        .shadow(color: AppColors.shadow.opacity(0.1), radius: Layout.Shadow.medium.radius, x: Layout.Shadow.medium.x, y: Layout.Shadow.medium.y)
    }
}
#endif
