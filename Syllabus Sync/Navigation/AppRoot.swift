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
enum AppRoute: Hashable {
    case launch
    case onboarding
    case auth
    case dashboard
    case reminders
    case importSyllabus
    case preview
    case parseReview
    case calendar
    case courseDetail(course: Course)
    case profile
    case networkingTest
    
    var title: String {
        switch self {
        case .launch: return "Syllabus Sync"
        case .onboarding: return "Welcome"
        case .auth: return "Sign In"
        case .dashboard: return "Dashboard"
        case .reminders: return "Reminders"
        case .importSyllabus: return "Import Syllabus"
        case .preview: return "Preview"
        case .parseReview: return "Review Events"
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
        case .parseReview: return "checklist"
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
    @Published var showParseReview: Bool = false
    
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

private extension AppNavigationManager {
    var isSignedInShellRoute: Bool {
        [.dashboard, .reminders, .importSyllabus, .profile].contains(currentRoute)
    }
}

// MARK: - App Root View

/// Main app root that handles all navigation and routing
struct AppRoot: View {
    @StateObject private var navigationManager = AppNavigationManager()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var eventStore: EventStore
    @StateObject private var importViewModel: ImportViewModel
    @StateObject private var courseRepository: CourseRepository
    @StateObject private var gradingRepository: GradingRepository

    init() {
        let store = EventStore()
        let gradingRepo = GradingRepository()
        let courseRepo = CourseRepository()
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
        _gradingRepository = StateObject(wrappedValue: gradingRepo)
        _courseRepository = StateObject(wrappedValue: courseRepo)
        _importViewModel = StateObject(wrappedValue: ImportViewModel(
            extractor: PDFKitExtractor(),
            parser: parser,
            eventStore: store,
            courseRepository: courseRepo,
            gradingRepository: gradingRepo
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
        .environmentObject(courseRepository)
        .environmentObject(gradingRepository)
        .modifier(ThemeEnvironment(themeManager: themeManager))
        .task(id: navigationManager.currentRoute) {
            await loadAuthenticatedDataIfNeeded()
        }
        .onAppear {
            print("🏠 AppRoot appeared, currentRoute: \(navigationManager.currentRoute)")
        }
    }

    private func loadAuthenticatedDataIfNeeded() async {
        guard navigationManager.isSignedInShellRoute else { return }
        guard SupabaseAuthService.shared.isAuthenticated else { return }

        // Route changes happen after launch/auth decisions, so this avoids
        // missing the initial load when session restoration finishes later.
        async let eventsLoad: Void = eventStore.fetchEvents()
        async let coursesLoad: Void = courseRepository.refresh()
        async let gradingLoad: Void = gradingRepository.fetchAll()
        _ = await (eventsLoad, coursesLoad, gradingLoad)
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
                // Safety fallback — subsidiary routes are pushed via NavigationStack
                TabNavigationView()
                    .transition(.slide)
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
        case .parseReview:
            ParseReviewView()
        case .calendar:
            CalendarView()
        case .courseDetail(let course):
            CourseDetailView(course: course)
                .navigationBarHidden(true)
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
        .fullScreenCover(isPresented: $navigationManager.showParseReview) {
            ParseReviewView()
                .environmentObject(importViewModel)
                .environmentObject(navigationManager)
                .environmentObject(eventStore)
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

            print("🚀 LaunchScreenView appeared")
            print("🔐 isAuthenticated: \(SupabaseAuthService.shared.isAuthenticated)")

            // Check authentication state and navigate accordingly
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                print("⏰ 2 second delay complete, navigating...")
                withAnimation(.spring(response: 0.7, dampingFraction: 0.8)) {
                    if SupabaseAuthService.shared.isAuthenticated {
                        // User is logged in, go directly to dashboard
                        print("✅ Navigating to dashboard")
                        navigationManager.setRoot(to: .dashboard)
                    } else {
                        // User is not logged in, show auth screen
                        print("🔓 Navigating to auth")
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
