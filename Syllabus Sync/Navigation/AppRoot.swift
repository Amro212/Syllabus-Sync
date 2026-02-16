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
    case reminders
    case importSyllabus
    case preview
    case calendar
    case courseDetail(course: MockCourse)
    case profile
    case networkingTest
    
    // Static cases for easier iteration (excluding parameterized routes)
    static var allCases: [AppRoute] {
        return [.launch, .onboarding, .auth, .dashboard, .reminders, .importSyllabus, .preview, .calendar, .profile]
    }
    
    var title: String {
        switch self {
        case .launch: return "Syllabus Sync"
        case .onboarding: return "Welcome"
        case .auth: return "Sign In"
        case .dashboard: return "Dashboard"
        case .reminders: return "Reminders"
        case .importSyllabus: return "Import Syllabus"
        case .preview: return "Preview"
        case .calendar: return "Calendar"
        case .courseDetail: return "Course Details"
        case .profile: return "Profile"
        case .networkingTest: return "Networking Test"
        }
    }
    
    var systemImage: String {
        switch self {
        case .launch: return "app.connected.to.app.below.fill"
        case .onboarding: return "hand.wave"
        case .auth: return "person.circle"
        case .dashboard: return "house"
        case .reminders: return "bell"
        case .importSyllabus: return "plus.circle"
        case .preview: return "eye"
        case .calendar: return "calendar"
        case .courseDetail: return "book"
        case .profile: return "person.crop.circle"
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
    @Published var scrollToEventId: String?
    
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
        isTabBarVisible = [.dashboard, .reminders, .importSyllabus, .profile].contains(route)
        
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    /// Switch to a specific tab (for tab navigation)
    func switchTab(to route: AppRoute) {
        withAnimation(.easeInOut(duration: 0.1)) {
            selectedTabRoute = route
        }
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
        .task {
            // Load user data when app launches and user is authenticated
            if SupabaseAuthService.shared.isAuthenticated {
                await eventStore.fetchEvents()
            }
        }
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
            case .dashboard, .reminders, .importSyllabus, .profile:
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
        case .reminders:
            RemindersView()
        case .importSyllabus:
            AISyllabusScanModal()
        case .preview:
            PreviewView()
        case .calendar:
            CalendarView()
        case .courseDetail(let course):
            CourseDetailView(course: course)
        case .profile:
            ProfileView()
        case .networkingTest:
            NetworkingTestView()
        }
    }
}

// MARK: - Tab Navigation

/// Tab-based navigation for main app sections
struct TabNavigationView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var importViewModel: ImportViewModel
    
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
    
    @State private var showingImportSheet = false
    @State private var fabExpanded = false
    @State private var showFabActions = false
    @State private var editingEvent: EventItem?
    @State private var isCreatingNewEvent = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content Area
            Group {
                switch navigationManager.selectedTabRoute {
                case .dashboard:
                    DashboardView()
                case .reminders:
                    RemindersView()
                case .preview:
                    PreviewView()
                case .calendar:
                    CalendarView()
                case .profile:
                    ProfileView()
                default:
                    DashboardView()
                }
            }
            .id(navigationManager.selectedTabRoute)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.5), value: navigationManager.selectedTabRoute)
            
            // FAB Menu Backdrop (only when expanded)
            if fabExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            fabExpanded = false
                            showFabActions = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(10) // Just below the menu
            }
            
            // FAB Menu Options (positioned above the tab bar)
            if fabExpanded {
                VStack(spacing: 2) {
                    // Add Reminder option
                    FABOption(
                        icon: "calendar.badge.plus",
                        label: "Add Reminder",
                        emphasized: true,
                        isVisible: showFabActions,
                        rowDelay: 0.0,
                        action: {
                            HapticFeedbackManager.shared.mediumImpact()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                fabExpanded = false
                                showFabActions = false
                            }
                            // Small delay to allow menu closing animation to start
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                createNewEvent()
                            }
                        }
                    )
                    
                    // AI Syllabus Scan option
                    FABOption(
                        icon: "sparkles",
                        label: "AI Syllabus Scan",
                        emphasized: false,
                        isVisible: showFabActions,
                        rowDelay: 0.03,
                        action: {
                            HapticFeedbackManager.shared.mediumImpact()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                fabExpanded = false
                                showFabActions = false
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingImportSheet = true
                            }
                        }
                    )
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.xl + 2)
                        .fill(AppColors.surface.opacity(0.95))
                        .overlay(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.xl + 2)
                                .stroke(AppColors.border.opacity(0.42), lineWidth: 1)
                        )
                        .shadow(color: AppColors.shadow.opacity(0.22), radius: 14, x: 0, y: 8)
                )
                .fixedSize()
                .padding(.bottom, 108)
                .transition(.scale(scale: 0.92, anchor: .bottom).combined(with: .opacity).combined(with: .move(edge: .bottom)))
                .zIndex(11) // Above backdrop
            }
            
            // Custom Tab Bar
            CustomTabBar(onFabTapped: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    fabExpanded.toggle()
                    showFabActions = fabExpanded
                }
            }, isFabExpanded: fabExpanded)
            .zIndex(12) // Topmost to ensure button clicks work
        }
        .ignoresSafeArea(.keyboard) 
        .sheet(isPresented: $showingImportSheet) {
            AISyllabusScanModal()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
        }
        .fullScreenCover(item: $editingEvent) { event in
            EventEditView(event: event, isCreatingNew: isCreatingNewEvent) { updated in
                if isCreatingNewEvent {
                    Task { 
                        await eventStore.update(event: updated)
                        isCreatingNewEvent = false
                    }
                } else {
                    Task { await importViewModel.applyEditedEvent(updated) }
                }
                editingEvent = nil
            } onCancel: {
                isCreatingNewEvent = false
                editingEvent = nil
            }
        }
        .onChange(of: navigationManager.selectedTabRoute) { _ in
            HapticFeedbackManager.shared.selection()
            // Close FAB if tab changes
            fabExpanded = false
            showFabActions = false
        }
    }
    
    // Helper to create a new empty event
    private func createNewEvent() {
        let now = Date()
        let newEvent = EventItem(
            id: UUID().uuidString,
            courseCode: "",
            type: .assignment, // Default
            title: "",
            start: now,
            end: nil,
            allDay: false,
            location: nil,
            notes: nil,
            recurrenceRule: nil,
            reminderMinutes: 1440,
            confidence: 1.0
        )
        isCreatingNewEvent = true
        editingEvent = newEvent
    }
}

// Reusable FAB Option Component
private struct FABOption: View {
    let icon: String
    let label: String
    let emphasized: Bool
    let isVisible: Bool
    let rowDelay: Double
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
                action()
            }
        }) {
            HStack(spacing: Layout.Spacing.sm) {
                // Icon
                Image(systemName: icon)
                    .font(.lexend(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 20)
                
                // Label - single line, no wrapping
                Text(label)
                    .font(.subheadline)
                    .fontWeight(emphasized ? .semibold : .medium)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.horizontal, Layout.Spacing.sm + 2)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                    .fill(AppColors.surface.opacity(0.95))
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 6)
        .animation(.spring(response: 0.22, dampingFraction: 0.84).delay(rowDelay), value: isVisible)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
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
                    .font(.lexend(size: 80, weight: .regular))
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
                    .font(.lexend(size: 80, weight: .regular))
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
            
            // Profile - switches tabs
            CardView(style: .elevated) {
                Button(action: {
                    navigationManager.switchTab(to: .profile)
                }) {
                    VStack(spacing: Layout.Spacing.sm) {
                        AppIcon("person.crop.circle", size: .medium, style: .filled)
                        Text("Profile")
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

            // Check authentication state and navigate accordingly
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                    if SupabaseAuthService.shared.isAuthenticated {
                        // User is logged in, go directly to dashboard
                        navigationManager.setRoot(to: .dashboard)
                    } else {
                        // User is not logged in, show auth screen
                        navigationManager.setRoot(to: .auth)
                    }
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
