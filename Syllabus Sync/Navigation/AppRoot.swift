//
//  AppRoot.swift
//  Syllabus Sync
//
//  Created by Amro Zabin on 2025-09-06.
//

import Foundation
import SwiftUI

private let defaultAPIBaseURL: URL = {
    if let env = ProcessInfo.processInfo.environment["API_BASE_URL"], let url = URL(string: env) {
        return url
    }
    return URL(string: "http://localhost:8787")!
}()

// MARK: - App Routes

/// Centralized route management for the entire app
enum AppRoute: Hashable, CaseIterable {
    case launch
    case onboarding
    case auth
    case dashboard
    case importSyllabus
    case preview
    case courseDetail(course: MockCourse)
    case settings
    case networkingTest
    
    // Static cases for easier iteration (excluding parameterized routes)
    static var allCases: [AppRoute] {
        return [.launch, .onboarding, .auth, .dashboard, .importSyllabus, .preview, .settings]
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
        case .networkingTest: return "Networking Test"
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
        case .networkingTest: return "network"
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
    @StateObject private var eventStore: EventStore
    @StateObject private var importViewModel: ImportViewModel

    init() {
        let store = EventStore()
        let parser = {
            let config = URLSessionAPIClient.Configuration(
                baseURL: defaultAPIBaseURL,
                defaultHeaders: ["Content-Type": "application/json"],
                requestTimeout: 90,
                maxRetryCount: 2
            )
            let client = URLSessionAPIClient(configuration: config)
            return SyllabusParserRemote(apiClient: client)
        }()
        _eventStore = StateObject(wrappedValue: store)
        _importViewModel = StateObject(wrappedValue: ImportViewModel(
            extractor: PDFKitExtractor(),
            parser: parser,
            eventStore: store
        ))
    }

    var body: some View {
        NavigationStack(path: $navigationManager.navigationPath) {
            rootView
                .navigationDestination(for: AppRoute.self) { route in
                    destinationView(for: route)
                }
        }
        .environmentObject(navigationManager)
        .environmentObject(themeManager)
        .environmentObject(eventStore)
        .environmentObject(importViewModel)
        .modifier(ThemeEnvironment(themeManager: themeManager))
    }
    
    @ViewBuilder
    private var rootView: some View {
        Group {
            switch navigationManager.currentRoute {
            case .launch:
                LaunchScreenView()
                    .transition(.scale.combined(with: .opacity))
            case .onboarding:
                OnboardingView()
                    .transition(.slideUp)
            case .auth:
                AuthView()
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
            OnboardingView()
        case .auth:
            AuthView()
        case .dashboard:
            DashboardView()
        case .importSyllabus:
            ImportView()
        case .preview:
            PreviewView()
        case .courseDetail(let course):
            CourseDetailView(course: course)
        case .settings:
            SettingsView()
        case .networkingTest:
            NetworkingTestView()
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
            // Dashboard tab
            DashboardView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
                .tag(AppRoute.dashboard)
            
            // Calendar tab
                PreviewView()
                    .tabItem {
                        Image(systemName: "calendar")
                        Text("Calendar")
                    }
                    .tag(AppRoute.preview) // Using preview route for now
            
            // Reminders tab
            RemindersPlaceholderView()
                .tabItem {
                    Image(systemName: "bell")
                    Text("Reminders")
                }
                .tag(AppRoute.courseDetail(course: MockCourse.sampleCourses[0])) // Temporary
            
            // Settings tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
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

/// Calendar placeholder view
struct CalendarPlaceholderView: View {
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                Text("📅")
                    .font(.system(size: 80))
                Text("Calendar View")
                    .font(.titleL)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                Text("Coming Soon")
                    .font(.body)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
            .background(AppColors.background)
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

/// Reminders placeholder view
struct RemindersPlaceholderView: View {
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                Text("🔔")
                    .font(.system(size: 80))
                Text("Reminders View")
                    .font(.titleL)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
                Text("Coming Soon")
                    .font(.body)
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
            }
            .background(AppColors.background)
            .navigationTitle("Reminders")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

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
    let courseCode: String
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.xl) {
                AppIcon("book", size: .xlarge, style: .filled)
                
                VStack(spacing: Layout.Spacing.md) {
                    Text("Course Details")
                        .font(.titleL)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Course Code: \(courseCode)")
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

/// Real Settings View
struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var eventStore: EventStore
    
    @State private var showingResetAlert = false
    @State private var notificationsEnabled = true
    @State private var hapticEnabled = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Layout.Spacing.xl) {
                    // App Info Section
                    VStack(spacing: Layout.Spacing.lg) {
                        AppIcon("graduationcap.circle.fill", size: .xlarge, style: .filled)
                        
                        VStack(spacing: Layout.Spacing.md) {
                            Text("Syllabus Sync")
                                .font(.titleL)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Version 1.0 (Beta)")
                                .font(.body)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    // Appearance Section
                    SettingsSection(title: "Appearance", icon: "paintbrush") {
                        VStack(spacing: Layout.Spacing.lg) {
                            SettingsRow(
                                title: "Theme",
                                subtitle: "Choose your preferred theme",
                                icon: "circle.lefthalf.filled"
                            ) {
                                ThemeToggle()
                            }
                        }
                    }
                    
                    // Preferences Section
                    SettingsSection(title: "Preferences", icon: "slider.horizontal.3") {
                        VStack(spacing: Layout.Spacing.lg) {
                            SettingsToggleRow(
                                title: "Notifications",
                                subtitle: "Get notified about upcoming events",
                                icon: "bell",
                                isOn: $notificationsEnabled
                            )
                            
                            SettingsToggleRow(
                                title: "Haptic Feedback",
                                subtitle: "Feel interactions with haptic feedback",
                                icon: "iphone.radiowaves.left.and.right",
                                isOn: $hapticEnabled
                            )
                        }
                    }
                    
                    // Testing Section
                    SettingsSection(title: "Testing", icon: "wrench.and.screwdriver") {
                        VStack(spacing: Layout.Spacing.lg) {
                            SettingsActionRow(
                                title: "Test Haptic Feedback",
                                subtitle: "Try different haptic patterns",
                                icon: "hand.tap"
                            ) {
                                testHapticFeedback()
                            }
                            
                            SettingsActionRow(
                                title: "Test Networking",
                                subtitle: "Test API client and parsing functionality",
                                icon: "network"
                            ) {
                                navigationManager.navigate(to: .networkingTest)
                            }
                            
                            SettingsActionRow(
                                title: "Reset to Empty State",
                                subtitle: "Clear all data and return to onboarding",
                                icon: "trash",
                                isDestructive: true
                            ) {
                                showingResetAlert = true
                            }
                        }
                    }
                    
                    // About Section
                    SettingsSection(title: "About", icon: "info.circle") {
                        VStack(spacing: Layout.Spacing.lg) {
                            SettingsActionRow(
                                title: "Privacy Policy",
                                subtitle: "View our privacy policy",
                                icon: "hand.raised"
                            ) {
                                // Open privacy policy (mock)
                                HapticFeedbackManager.shared.lightImpact()
                            }
                            
                            SettingsActionRow(
                                title: "Terms of Service",
                                subtitle: "View terms and conditions",
                                icon: "doc.text"
                            ) {
                                // Open terms (mock)
                                HapticFeedbackManager.shared.lightImpact()
                            }
                            
                            SettingsActionRow(
                                title: "Contact Support",
                                subtitle: "Get help with your account",
                                icon: "envelope"
                            ) {
                                // Contact support (mock)
                                HapticFeedbackManager.shared.lightImpact()
                            }
                        }
                    }
                }
                .padding(Layout.Spacing.lg)
            }
            .background(AppColors.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .alert("Reset App Data", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAppData()
            }
        } message: {
            Text("This will delete all your courses and events, and return the app to its initial state. This action cannot be undone.")
        }
    }
    
    private func testHapticFeedback() {
        let patterns: [(String, () -> Void)] = [
            ("Light Impact", { HapticFeedbackManager.shared.lightImpact() }),
            ("Medium Impact", { HapticFeedbackManager.shared.mediumImpact() }),
            ("Heavy Impact", { HapticFeedbackManager.shared.heavyImpact() }),
            ("Success", { HapticFeedbackManager.shared.success() }),
            ("Warning", { HapticFeedbackManager.shared.warning() }),
            ("Error", { HapticFeedbackManager.shared.error() }),
            ("Selection", { HapticFeedbackManager.shared.selection() })
        ]
        
        // Cycle through patterns with delays
        for (index, (_, action)) in patterns.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                action()
            }
        }
    }
    
    private func resetAppData() {
        HapticFeedbackManager.shared.success()
        Task {
            await eventStore.deleteAllEvents()
            navigationManager.currentRoute = .launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                navigationManager.currentRoute = .onboarding
            }
        }
    }
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
            HStack(spacing: Layout.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.accent)
                
                Text(title)
                    .font(.titleS)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            CardView(style: .elevated) {
                content
            }
        }
    }
}

struct SettingsRow<Accessory: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    @ViewBuilder let accessory: Accessory
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accessory = accessory()
    }
    
    var body: some View {
        HStack(spacing: Layout.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(AppColors.accent)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            Spacer()
            
            accessory
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        SettingsRow(title: title, subtitle: subtitle, icon: icon) {
            Toggle("", isOn: $isOn)
                .onChange(of: isOn) {
                    HapticFeedbackManager.shared.lightImpact()
                }
        }
    }
}

struct SettingsActionRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isDestructive ? .red : AppColors.accent)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : AppColors.textPrimary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .buttonStyle(PlainButtonStyle())
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
                NavigationLink(value: AppRoute.courseDetail(course: MockCourse.sampleCourses[0])) {
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
                            .fill(AppColors.accent.gradient.opacity(0.1))
                            .frame(width: 140, height: 140)
                            .scaleEffect(showLogo ? 1.0 : 0.6)
                            .opacity(showLogo ? 1.0 : 0.0)
                        
                        Circle()
                            .fill(AppColors.accent.gradient.opacity(0.2))
                            .frame(width: 120, height: 120)
                            .scaleEffect(showLogo ? 1.0 : 0.7)
                            .opacity(showLogo ? 1.0 : 0.0)
                        
                        Image("SyllabusIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 80, height: 80)
                            .scaleEffect(showLogo ? 1.0 : 0.8)
                            .opacity(showLogo ? 1.0 : 0.0)
                    }
                    .shadow(color: AppColors.accent.opacity(0.3), radius: 20, x: 0, y: 10)
                    
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
