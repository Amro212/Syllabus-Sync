//
//  AppRoot.swift
//  Syllabus Sync
//
//  Created by Amro Zabin on 2025-09-06.
//

import SwiftUI

// MARK: - App Routes

/// Centralized route management for the entire app
enum AppRoute: Hashable, CaseIterable {
    case launch
    case onboarding
    case auth
    case dashboard
    case importSyllabus
    case preview
    case courseDetail(courseId: String)
    case settings
    
    // Static cases for easier iteration (excluding parameterized routes)
    static var allCases: [AppRoute] {
        return [.launch, .onboarding, .auth, .dashboard, .importSyllabus, .preview, .courseDetail(courseId: "sample"), .settings]
    }
    
    var title: String {
        switch self {
        case .launch: return "Syllabus Sync"
        case .onboarding: return "Welcome"
        case .auth: return "Sign In"
        case .dashboard: return "Dashboard"
        case .importSyllabus: return "Import Syllabus"
        case .preview: return "Preview"
        case .courseDetail: return "Course Details"
        case .settings: return "Settings"
        }
    }
    
    var systemImage: String {
        switch self {
        case .launch: return "app.connected.to.app.below.fill"
        case .onboarding: return "hand.wave"
        case .auth: return "person.circle"
        case .dashboard: return "house"
        case .importSyllabus: return "plus.circle"
        case .preview: return "eye"
        case .courseDetail: return "book"
        case .settings: return "gear"
        }
    }
}

// MARK: - App Navigation Manager

/// ObservableObject for managing app-wide navigation state
class AppNavigationManager: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var currentRoute: AppRoute = .launch
    @Published var selectedTabRoute: AppRoute = .dashboard
    @Published var isTabBarVisible: Bool = false
    
    /// Navigate to a specific route
    func navigate(to route: AppRoute) {
        currentRoute = route
        navigationPath.append(route)
        HapticFeedbackManager.shared.selection()
    }
    
    /// Pop to root (clear navigation stack)
    func popToRoot() {
        navigationPath = NavigationPath()
        HapticFeedbackManager.shared.lightImpact()
    }
    
    /// Pop back one level
    func popBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
            HapticFeedbackManager.shared.lightImpact()
        }
    }
    
    /// Set the root route (for major navigation changes)
    func setRoot(to route: AppRoute) {
        currentRoute = route
        navigationPath = NavigationPath()
        
        // Show tab bar for main app sections
        isTabBarVisible = [.dashboard, .importSyllabus, .settings].contains(route)
        
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    /// Switch to a specific tab (for tab navigation)
    func switchTab(to route: AppRoute) {
        selectedTabRoute = route
        HapticFeedbackManager.shared.selection()
    }
}

// MARK: - App Root View

/// Main app root that handles all navigation and routing
struct AppRoot: View {
    @StateObject private var navigationManager = AppNavigationManager()
    @StateObject private var themeManager = ThemeManager()
    
    var body: some View {
        NavigationStack(path: $navigationManager.navigationPath) {
            rootView
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                }
        }
        .environmentObject(navigationManager)
        .environmentObject(themeManager)
        .modifier(ThemeEnvironment())
    }
    
    @ViewBuilder
    private var rootView: some View {
        Group {
            switch navigationManager.currentRoute {
            case .launch:
                LaunchScreenView()
                    .transition(.scale.combined(with: .opacity))
            case .onboarding:
                OnboardingPlaceholderView()
                    .transition(.slideUp)
            case .auth:
                AuthPlaceholderView()
                    .transition(.dissolve)
            case .dashboard, .importSyllabus, .settings:
                TabNavigationView()
                    .transition(.slide)
            default:
                // For other routes, show placeholder
                RoutePlaceholderView(route: navigationManager.currentRoute)
                    .transition(.scale)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: navigationManager.currentRoute)
    }
    
    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .launch:
            LaunchScreenView()
        case .onboarding:
            OnboardingPlaceholderView()
        case .auth:
            AuthPlaceholderView()
        case .dashboard:
            DashboardPlaceholderView()
        case .importSyllabus:
            ImportPlaceholderView()
        case .preview:
            PreviewPlaceholderView()
        case .courseDetail(let courseId):
            CourseDetailPlaceholderView(courseId: courseId)
        case .settings:
            SettingsPlaceholderView()
        }
    }
}

// MARK: - Tab Navigation

/// Tab-based navigation for main app sections
struct TabNavigationView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    
    /// Custom function to handle back navigation in tab context
    private func handleBackNavigation() {
        // If we're not on the dashboard tab, go to dashboard
        // Otherwise, use normal back navigation
        if navigationManager.selectedTabRoute != .dashboard {
            navigationManager.switchTab(to: .dashboard)
        } else {
            navigationManager.popBack()
        }
    }
    
    var body: some View {
        TabView(selection: $navigationManager.selectedTabRoute) {
            // Dashboard tab with its own navigation stack
            NavigationStack {
                NavigationTransitionContainer(transitionType: .dissolve) {
                    DashboardPlaceholderView()
                }
                .navigationDestination(for: AppRoute.self) { route in
                    NavigationTransitionContainer(transitionType: .slide) {
                        switch route {
                        case .preview:
                            PreviewPlaceholderView()
                        case .courseDetail(let courseId):
                            CourseDetailPlaceholderView(courseId: courseId)
                        default:
                            EmptyView()
                        }
                    }
                }
            }
            .tabItem {
                Image(systemName: AppRoute.dashboard.systemImage)
                Text(AppRoute.dashboard.title)
            }
            .tag(AppRoute.dashboard)
            
            // Import tab with its own navigation stack  
            NavigationStack {
                NavigationTransitionContainer(transitionType: .dissolve) {
                    ImportPlaceholderView()
                }
            }
            .tabItem {
                Image(systemName: AppRoute.importSyllabus.systemImage)
                Text(AppRoute.importSyllabus.title)
            }
            .tag(AppRoute.importSyllabus)
            
            // Settings tab with its own navigation stack
            NavigationStack {
                NavigationTransitionContainer(transitionType: .dissolve) {
                    SettingsPlaceholderView()
                }
            }
            .tabItem {
                Image(systemName: AppRoute.settings.systemImage)
                Text(AppRoute.settings.title)
            }
            .tag(AppRoute.settings)
        }
        .onAppear {
            // Configure tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(AppColors.surface)
            appearance.shadowColor = UIColor(AppColors.border.withOpacity(0.3))
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        .onChange(of: navigationManager.selectedTabRoute) {
            // Only provide haptic feedback for tab changes
            // Don't update navigationManager.currentRoute to avoid interfering with back navigation
            HapticFeedbackManager.shared.selection()
        }
    }
}

// MARK: - Placeholder Views

/// Generic placeholder view for any route
struct RoutePlaceholderView: View {
    let route: AppRoute
    @EnvironmentObject var navigationManager: AppNavigationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.xl) {
                AppIcon(route.systemImage, size: .xlarge, style: .filled)
                
                VStack(spacing: Layout.Spacing.md) {
                    Text(route.title)
                        .font(.titleL)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("This is a placeholder view for the \(route.title) screen.")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                NavigationTestSection()
            }
            .padding(Layout.Spacing.lg)
        }
        .background(AppColors.background)
        .navigationTitle(route.title)
        .navigationBarTitleDisplayMode(.large)
    }
}

/// Onboarding placeholder with flow simulation
struct OnboardingPlaceholderView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @State private var currentStep = 0
    private let steps = ["Welcome", "Features", "Permissions", "Get Started"]
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xxl) {
            Spacer()
            
            AppIcon("hand.wave", size: .xlarge, style: .filled)
            
            VStack(spacing: Layout.Spacing.lg) {
                Text("Welcome to Syllabus Sync")
                    .font(.titleXL)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Step \(currentStep + 1) of \(steps.count): \(steps[currentStep])")
                    .font(.body)
                    .foregroundColor(AppColors.textSecondary)
                
                ProgressView(value: Double(currentStep + 1), total: Double(steps.count))
                    .progressViewStyle(LinearProgressViewStyle(tint: AppColors.accent))
                    .padding(.horizontal, Layout.Spacing.xl)
            }
            
            Spacer()
            
            VStack(spacing: Layout.Spacing.md) {
                if currentStep < steps.count - 1 {
                    HapticPrimaryCTAButton("Next", icon: "arrow.right", hapticType: .lightImpact) {
                        withAnimation(.spring()) {
                            currentStep += 1
                        }
                    }
                } else {
                    HapticPrimaryCTAButton("Get Started", icon: "arrow.right", hapticType: .success) {
                        navigationManager.setRoot(to: .auth)
                    }
                }
                
                if currentStep > 0 {
                    HapticSecondaryButton("Back", icon: "arrow.left", hapticType: .lightImpact) {
                        withAnimation(.spring()) {
                            currentStep -= 1
                        }
                    }
                }
            }
            .padding(Layout.Spacing.lg)
        }
        .background(AppColors.background)
    }
}

/// Auth placeholder with form simulation
struct AuthPlaceholderView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.xl) {
                AppIcon("person.circle", size: .xlarge, style: .filled)
                
                VStack(spacing: Layout.Spacing.lg) {
                    Text(isSignUp ? "Create Account" : "Welcome Back")
                        .font(.titleL)
                        .foregroundColor(AppColors.textPrimary)
                    
                    SegmentedTabs(
                        items: [false, true],
                        selectedItem: isSignUp,
                        itemTitle: { $0 ? "Sign Up" : "Login" }
                    ) { isSignUpTab in
                        isSignUp = isSignUpTab
                    }
                }
                
                VStack(spacing: Layout.Spacing.md) {
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, Layout.Spacing.lg)
                
                VStack(spacing: Layout.Spacing.md) {
                    HapticPrimaryCTAButton(
                        isSignUp ? "Create Account" : "Sign In",
                        icon: "arrow.right",
                        isLoading: isLoading,
                        hapticType: .success
                    ) {
                        simulateAuth()
                    }
                    
                    HapticSecondaryButton("Back to Welcome", icon: "arrow.left", hapticType: .lightImpact) {
                        navigationManager.setRoot(to: .onboarding)
                    }
                }
                .padding(Layout.Spacing.lg)
                
                NavigationTestSection()
            }
        }
        .background(AppColors.background)
        .navigationTitle(isSignUp ? "Sign Up" : "Sign In")
    }
    
    private func simulateAuth() {
        isLoading = true
        HapticFeedbackManager.shared.lightImpact()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            HapticFeedbackManager.shared.success()
            navigationManager.setRoot(to: .dashboard)
        }
    }
}

/// Dashboard placeholder with navigation options
struct DashboardPlaceholderView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.xl) {
                AppIcon("house", size: .xlarge, style: .filled)
                
                VStack(spacing: Layout.Spacing.md) {
                    Text("Dashboard")
                        .font(.titleL)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Your academic overview")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                QuickActionsGrid()
                
                NavigationTestSection()
            }
            .padding(Layout.Spacing.lg)
        }
        .background(AppColors.background)
        .navigationTitle("Dashboard")
    }
}

/// Import placeholder
struct ImportPlaceholderView: View {
    var body: some View {
        RoutePlaceholderView(route: .importSyllabus)
    }
}

/// Preview placeholder
struct PreviewPlaceholderView: View {
    var body: some View {
        RoutePlaceholderView(route: .preview)
    }
}

/// Course detail placeholder
struct CourseDetailPlaceholderView: View {
    let courseId: String
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.xl) {
                AppIcon("book", size: .xlarge, style: .filled)
                
                VStack(spacing: Layout.Spacing.md) {
                    Text("Course Details")
                        .font(.titleL)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Course ID: \(courseId)")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, Layout.Spacing.md)
                        .padding(.vertical, Layout.Spacing.sm)
                        .background(AppColors.surfaceSecondary)
                        .cornerRadius(Layout.CornerRadius.sm)
                }
                
                NavigationTestSection()
            }
            .padding(Layout.Spacing.lg)
        }
        .background(AppColors.background)
        .navigationTitle("Course Details")
    }
}

/// Settings placeholder
struct SettingsPlaceholderView: View {
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.xl) {
                AppIcon("gear", size: .xlarge, style: .filled)
                
                VStack(spacing: Layout.Spacing.md) {
                    Text("Settings")
                        .font(.titleL)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Customize your experience")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                CardView(style: .elevated) {
                    VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
                        HStack {
                            Image(systemName: "paintbrush")
                                .foregroundColor(AppColors.accent)
                            Text("Appearance")
                                .font(.titleS)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                        }
                        
                        ThemeToggle()
                    }
                }
                
                NavigationTestSection()
            }
            .padding(Layout.Spacing.lg)
        }
        .background(AppColors.background)
        .navigationTitle("Settings")
    }
}

// MARK: - Test Components

/// Quick actions grid for dashboard testing
struct QuickActionsGrid: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Layout.Spacing.md) {
            // Import Syllabus - switches tabs
            CardView(style: .elevated) {
                Button(action: {
                    navigationManager.switchTab(to: .importSyllabus)
                }) {
                    VStack(spacing: Layout.Spacing.sm) {
                        AppIcon("plus.circle", size: .medium, style: .filled)
                        Text("Import Syllabus")
                            .font(.captionL)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Layout.Spacing.md)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Preview Events - stays in dashboard tab with NavigationLink
            CardView(style: .elevated) {
                NavigationLink(value: AppRoute.preview) {
                    VStack(spacing: Layout.Spacing.sm) {
                        AppIcon("eye", size: .medium, style: .filled)
                        Text("Preview Events")
                            .font(.captionL)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Layout.Spacing.md)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        HapticFeedbackManager.shared.lightImpact()
                    }
                )
            }
            
            // Course Details - stays in dashboard tab with NavigationLink
            CardView(style: .elevated) {
                NavigationLink(value: AppRoute.courseDetail(courseId: "CS101")) {
                    VStack(spacing: Layout.Spacing.sm) {
                        AppIcon("book", size: .medium, style: .filled)
                        Text("Course Details")
                            .font(.captionL)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Layout.Spacing.md)
                }
                .buttonStyle(PlainButtonStyle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        HapticFeedbackManager.shared.lightImpact()
                    }
                )
            }
            
            // Settings - switches tabs
            CardView(style: .elevated) {
                Button(action: {
                    navigationManager.switchTab(to: .settings)
                }) {
                    VStack(spacing: Layout.Spacing.sm) {
                        AppIcon("gear", size: .medium, style: .filled)
                        Text("Settings")
                            .font(.captionL)
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(Layout.Spacing.md)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

/// Navigation testing section for all screens
struct NavigationTestSection: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    
    var body: some View {
        CardView(style: .outlined) {
            VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
                HStack {
                    Image(systemName: "map")
                        .foregroundColor(AppColors.accent)
                    Text("Navigation Test Center")
                        .font(.titleS)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                }
                
                Text("Test navigation to any screen:")
                    .font(.body)
                    .foregroundColor(AppColors.textSecondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: Layout.Spacing.sm) {
                    ForEach(AppRoute.allCases, id: \.self) { route in
                        SmallButton(route.title, style: .secondary) {
                            navigationManager.navigate(to: route)
                        }
                    }
                }
                
                Divider()
                
                HStack(spacing: Layout.Spacing.sm) {
                    SmallButton("← Back", style: .secondary) {
                        // Use proper navigation instead of direct routing
                        if navigationManager.navigationPath.isEmpty {
                            // If no navigation stack, go to dashboard
                            navigationManager.setRoot(to: .dashboard)
                        } else {
                            // Pop back in navigation stack
                            navigationManager.popBack()
                        }
                    }
                    
                    SmallButton("🏠 Root", style: .secondary) {
                        navigationManager.popToRoot()
                    }
                    
                    Spacer()
                    
                    SmallButton("Auth Reset", style: .destructive) {
                        navigationManager.setRoot(to: .onboarding)
                    }
                }
            }
        }
    }
}

// MARK: - Launch Screen

/// Launch screen view with app logo and smooth transition to onboarding
struct LaunchScreenView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @State private var isAnimating = false
    @State private var showLogo = false
    
    var body: some View {
        ZStack {
            // Background
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: Layout.Spacing.xl) {
                Spacer()
                
                // App Logo/Icon
                VStack(spacing: Layout.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(AppColors.accent.gradient)
                            .frame(width: 120, height: 120)
                            .scaleEffect(showLogo ? 1.0 : 0.6)
                            .opacity(showLogo ? 1.0 : 0.0)
                        
                        AppIcon(
                            "book.fill",
                            size: .xlarge,
                            style: .filled
                        )
                        .foregroundColor(.white)
                        .scaleEffect(showLogo ? 1.0 : 0.8)
                        .opacity(showLogo ? 1.0 : 0.0)
                    }
                    
                    VStack(spacing: Layout.Spacing.sm) {
                        Text("Syllabus Sync")
                            .font(.titleXL)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                            .opacity(showLogo ? 1.0 : 0.0)
                        
                        Text("Organize Your Academic Life")
                            .font(.body)
                            .foregroundColor(AppColors.textSecondary)
                            .opacity(showLogo ? 1.0 : 0.0)
                    }
                }
                
                Spacer()
                
                // Loading indicator
                VStack(spacing: Layout.Spacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        .scaleEffect(1.2)
                        .opacity(showLogo ? 1.0 : 0.0)
                    
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .opacity(showLogo ? 1.0 : 0.0)
                }
                .padding(.bottom, Layout.Spacing.xxl)
            }
            .padding(Layout.Spacing.lg)
        }
        .onAppear {
            // Start the launch animation sequence
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showLogo = true
            }
            
            // Trigger haptic feedback
            HapticFeedbackManager.shared.mediumImpact()
            
            // Navigate to onboarding after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                    navigationManager.setRoot(to: .onboarding)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AppRoot_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AppRoot()
                .previewDisplayName("App Root - Light")
            
            AppRoot()
                .preferredColorScheme(.dark)
                .previewDisplayName("App Root - Dark")
        }
    }
}
#endif
