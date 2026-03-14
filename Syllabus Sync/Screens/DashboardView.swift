//
//  DashboardView.swift
//  Syllabus Sync
//
//  Created by Assistant on 2024-01-01.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var importViewModel: ImportViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var courseRepository: CourseRepository
    @EnvironmentObject var gradingRepository: GradingRepository
    @StateObject private var errorHandler = ErrorHandler()
    @State private var isRefreshing = false
    @State private var showShimmer = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var showingImportView = false
    @State private var showingSocialHub = false
    @State private var showingAdminDebug = false
    
    // Track if the user has ever added events to distinguish "New User" from "Caught Up"
    // We scope this to the specific user ID to prevent state leaking between accounts
    @State private var hasAddedEvents: Bool = false


    var body: some View {
        GeometryReader { geo in
            let headerHeight = geo.safeAreaInsets.top + 4

            ZStack(alignment: .top) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Custom header logic
                        // We remove the Duplicate 'Dashboard' Text here because it is already in the Sticky Top Bar.
                        
                        // New modular dashboard structure matching wireframe
                        // Always show the structure, even if empty
                        VStack(spacing: Layout.Spacing.lg) {
                            greetingHeader

                            DashboardSummaryClusterView(
                                events: eventStore.events,
                                isNewUser: !hasAddedEvents && eventStore.events.isEmpty,
                                onEventTapped: { event in
                                    navigationManager.scrollToEventId = event.id
                                    navigationManager.switchTab(to: .reminders)
                                }
                            )

                            MyCoursesSection(
                                courses: courseRepository.courses,
                                events: eventStore.events,
                                onCourseTapped: { course in
                                    navigationManager.navigate(to: .courseDetail(course: course))
                                }
                            )
                        }
                        .padding(.horizontal, Layout.Spacing.md)
                        .padding(.vertical, Layout.Spacing.lg)
                        .transition(.opacity)
                    }
                    .padding(.top, 60)
                    .padding(.bottom, 80) // Add bottom padding for tab bar
                }
                .background(AppColors.background)
                .refreshable {
                    await performRefreshAsync()
                }

                // Custom Top Bar (Sticky)
                VStack(spacing: 0) {
                    HStack {
                        Text("Dashboard")
                            .font(.titleL)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Spacer()

                        HStack(spacing: Layout.Spacing.md) {
                            Button {
                                HapticFeedbackManager.shared.lightImpact()
                                showingSocialHub = true
                            } label: {
                                Image(systemName: "person.2.fill")
                                    .font(.lexend(size: 22, weight: .regular))
                                    .foregroundColor(AppColors.textPrimary)
                            }

                            Button {
                                HapticFeedbackManager.shared.lightImpact()
                                showingAdminDebug = true
                            } label: {
                                Image(systemName: "wrench.and.screwdriver.fill")
                                    .font(.lexend(size: 22, weight: .regular))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .padding(.horizontal, Layout.Spacing.md)
                    .padding(.bottom, Layout.Spacing.sm)
                    .padding(.top, geo.safeAreaInsets.top)
                    .background(AppColors.background.opacity(0.95))
                    .overlay(alignment: .bottom) {
                        Divider().opacity(0.5)
                    }
                    
                    Spacer()
                }
                .frame(height: headerHeight + 50)
                .ignoresSafeArea(edges: .top)
            }
            .background(AppColors.background)
        }
        .task {
            await loadDashboardData()
        }
        .onChange(of: eventStore.events) { events in
             if !events.isEmpty {
                 updateUserPreference(true)
             }
        }
        .alert("Error", isPresented: $errorHandler.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorHandler.errorMessage)
        }
        .sheet(isPresented: $showingImportView) {
            AISyllabusScanModal()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showingSocialHub) {
            SocialHubView()
                .presentationDetents([.fraction(0.93)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
                .presentationBackground(.ultraThinMaterial)
        }
        .sheet(isPresented: $showingAdminDebug) {
            AdminDebugView()
                .environmentObject(eventStore)
                .environmentObject(navigationManager)
                .presentationDetents([.fraction(0.93)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
                .presentationBackground(.ultraThinMaterial)
        }
    }
    
    // MARK: - User Preference Logic
    
    private func loadUserPreference() {
        guard let userId = SupabaseAuthService.shared.currentUser?.id else { return }
        hasAddedEvents = UserDefaults.standard.bool(forKey: "hasAddedEvents_\(userId)")
    }

    private func loadDashboardData() async {
        loadUserPreference()
        guard SupabaseAuthService.shared.isAuthenticated else { return }

        async let eventsLoad: Void = eventStore.fetchEvents()
        async let coursesLoad: Void = courseRepository.refresh()
        async let gradingLoad: Void = gradingRepository.fetchAll()
        _ = await (eventsLoad, coursesLoad, gradingLoad)

        if !eventStore.events.isEmpty {
            updateUserPreference(true)
        }
    }

    private func updateUserPreference(_ value: Bool) {
        guard let userId = SupabaseAuthService.shared.currentUser?.id else { return }
        hasAddedEvents = value
        UserDefaults.standard.set(value, forKey: "hasAddedEvents_\(userId)")
    }
    
    private func performRefreshAsync() async {
        await MainActor.run {
            isRefreshing = true
            showShimmer = true
            HapticFeedbackManager.shared.lightImpact()
        }

        await eventStore.refresh()
        await courseRepository.refresh()
        await gradingRepository.fetchAll()

        await MainActor.run {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isRefreshing = false
                showShimmer = false
            }
        }
    }
    
    // MARK: - Greeting
    
    private var greetingHeader: some View {
        let summaryItems = headerSummaryItems

        return ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppColors.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppColors.border.opacity(0.45), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                Text(timeBasedGreeting)
                    .font(.lexend(size: 30, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(todayEventSummary)
                    .font(.lexend(size: 15, weight: .regular))
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !summaryItems.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Layout.Spacing.sm) {
                            ForEach(summaryItems) { item in
                                DashboardHeaderPill(item: item)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Layout.Spacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerSummaryItems: [DashboardHeaderPill.Item] {
        let upcomingCount = eventStore.events.filter {
            $0.start >= Date() && $0.start <= Calendar.current.date(byAdding: .hour, value: 48, to: Date())!
        }.count

        return [
            DashboardHeaderPill.Item(
                icon: "calendar",
                title: Date().formatted(.dateTime.weekday(.wide)),
                value: Date().formatted(.dateTime.month(.abbreviated).day())
            ),
            DashboardHeaderPill.Item(
                icon: "books.vertical.fill",
                title: "Courses",
                value: "\(courseRepository.courses.count)"
            ),
            DashboardHeaderPill.Item(
                icon: "bolt.fill",
                title: "Due Soon",
                value: "\(upcomingCount)"
            )
        ]
    }
    
    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let timeGreeting: String
        switch hour {
        case 0..<12: timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        default: timeGreeting = "Good evening"
        }
        if let name = SupabaseAuthService.shared.currentUser?.displayName?
            .components(separatedBy: " ").first, !name.isEmpty {
            return "\(timeGreeting), \(name)!"
        }
        return "\(timeGreeting)!"
    }
    
    private var todayEventSummary: String {
        let todayEvents = eventStore.events.filter { Calendar.current.isDateInToday($0.start) }
        switch todayEvents.count {
        case 0:
            return eventStore.events.isEmpty ? "Add your first course to get started." : "No events scheduled for today."
        case 1:
            return "You have 1 event today."
        default:
            return "You have \(todayEvents.count) events today."
        }
    }
}

// MARK: - FAB Option


// MARK: - Legacy Components

// DashboardEmptyView removed as we now use inline empty states within sections.

// MARK: - Week At a Glance

// MARK: - Dashboard Components

private struct DashboardSummaryClusterView: View {
    let events: [EventItem]
    let isNewUser: Bool
    let onEventTapped: (EventItem) -> Void

    private var insight: DashboardHeroInsight {
        let now = Date()
        let calendar = Calendar.current
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        let twoDaysFromNow = calendar.date(byAdding: .hour, value: 48, to: now) ?? now
        let urgentEvents = events
            .filter { $0.start >= now && $0.start <= twoDaysFromNow }
            .sorted { $0.start < $1.start }

        if isNewUser && events.isEmpty {
            return DashboardHeroInsight(
                eyebrow: "Quick Insights",
                title: "Your dashboard is ready",
                description: "Import a syllabus to get started.",
                icon: "sparkles",
                tint: AppColors.accent
            )
        }

        if let firstUrgent = urgentEvents.first, firstUrgent.start < tomorrowStart {
            return DashboardHeroInsight(
                eyebrow: "Deadline Today",
                title: firstUrgent.title,
                description: "\(firstUrgent.courseCode) due today.",
                icon: "exclamationmark.circle.fill",
                tint: AppColors.eventExam
            )
        }

        if urgentEvents.count >= 2, let nearest = urgentEvents.first {
            return DashboardHeroInsight(
                eyebrow: "Heavy Window",
                title: "\(urgentEvents.count) items due soon",
                description: "Next: \(nearest.title) • \(nearest.courseCode)",
                icon: "hourglass",
                tint: AppColors.warning
            )
        }

        if let next = urgentEvents.first {
            return DashboardHeroInsight(
                eyebrow: "Deadline Tomorrow",
                title: next.title,
                description: "\(next.courseCode) due tomorrow.",
                icon: "clock.badge.fill",
                tint: AppColors.accentSecondary
            )
        }

        return DashboardHeroInsight(
            eyebrow: "Quick Insights",
            title: "You have breathing room",
            description: "Nothing due in the next 48 hours.",
            icon: "leaf.fill",
            tint: AppColors.success
        )
    }

    private var weeklyStats: [DashboardWeeklyStat] {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? now
        let weekEvents = events.filter { $0.start >= now && $0.start < endOfWeek }

        let grouped = Dictionary(grouping: weekEvents, by: \.type)
        return EventItem.EventType.allCases.compactMap { type in
            guard let groupedEvents = grouped[type], !groupedEvents.isEmpty else { return nil }
            return DashboardWeeklyStat(
                icon: type.dashboardIcon,
                count: groupedEvents.count,
                label: type.dashboardLabel(count: groupedEvents.count),
                tint: type.dashboardTint
            )
        }
    }

    private var upcomingEvents: [EventItem] {
        let now = Date()
        let weekFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now

        return events
            .filter { $0.start >= now && $0.start <= weekFromNow }
            .sorted { $0.start < $1.start }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        VStack(spacing: Layout.Spacing.md) {
            DashboardHeroCard(insight: insight)

            DashboardPriorityBoard(
                weeklyStats: weeklyStats,
                upcomingEvents: upcomingEvents,
                isNewUser: isNewUser,
                onEventTapped: onEventTapped
            )
        }
    }
}

private struct DashboardHeaderPill: View {
    struct Item: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let value: String
    }

    let item: Item

    var body: some View {
        HStack(spacing: Layout.Spacing.sm) {
            Image(systemName: item.icon)
                .font(.lexend(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 28, height: 28)
                .background(AppColors.surface.opacity(0.8), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text(item.value)
                    .font(.captionL)
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .padding(.horizontal, Layout.Spacing.sm)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.surface.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

private struct DashboardHeroInsight {
    let eyebrow: String
    let title: String
    let description: String
    let icon: String
    let tint: Color
}

private struct DashboardHeroCard: View {
    let insight: DashboardHeroInsight

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                    Text(insight.eyebrow.uppercased())
                        .font(.captionL)
                        .foregroundStyle(insight.tint)

                    Text(insight.title)
                        .font(.lexend(size: 24, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(insight.description)
                        .font(.bodyS)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: Layout.Spacing.md)

                ZStack {
                    Circle()
                        .fill(insight.tint.opacity(0.18))
                        .frame(width: 58, height: 58)

                    Image(systemName: insight.icon)
                        .font(.lexend(size: 24, weight: .semibold))
                        .foregroundStyle(insight.tint)
                }
            }
        }
        .padding(Layout.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppColors.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(AppColors.border.opacity(0.42), lineWidth: 1)
                }
        )
        .shadow(color: AppColors.shadow.opacity(0.09), radius: 16, x: 0, y: 10)
    }
}

private struct DashboardPriorityBoard: View {
    let weeklyStats: [DashboardWeeklyStat]
    let upcomingEvents: [EventItem]
    let isNewUser: Bool
    let onEventTapped: (EventItem) -> Void

    private var primaryEvent: EventItem? {
        upcomingEvents.first
    }

    private var secondaryEvents: [EventItem] {
        Array(upcomingEvents.dropFirst())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Focus This Week")
                        .font(.titleS)
                        .foregroundStyle(AppColors.textPrimary)
                    Text("Deadlines and weekly pace.")
                        .font(.captionL)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()
            }

            if let primaryEvent {
                DashboardPrimaryDeadlineCard(event: primaryEvent, onTap: {
                    onEventTapped(primaryEvent)
                })
            } else {
                DashboardNoDeadlineCard(isNewUser: isNewUser)
            }

            DashboardWeeklySnapshotCard(stats: weeklyStats, isNewUser: isNewUser)

            if !secondaryEvents.isEmpty {
                DashboardSecondaryDeadlinesCard(events: secondaryEvents, onEventTapped: onEventTapped)
            }
        }
    }
}

private struct DashboardPrimaryDeadlineCard: View {
    let event: EventItem
    let onTap: () -> Void

    private var relativeText: String {
        let calendar = Calendar.current
        let dayDifference = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: event.start)
        ).day ?? 0

        switch dayDifference {
        case ..<0:
            return "Past due"
        case 0:
            return "Due today"
        case 1:
            return "Due tomorrow"
        default:
            return "In \(dayDifference) days"
        }
    }

    private var dateText: String {
        event.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private var timeText: String {
        event.allDay == true ? "All Day" : event.start.formatted(.dateTime.hour().minute())
    }

    var body: some View {
        Button {
            HapticFeedbackManager.shared.lightImpact()
            onTap()
        } label: {
            VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                HStack {
                    Label("Upcoming Deadline", systemImage: "sparkles")
                        .font(.captionL)
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()

                    Text(relativeText)
                        .font(.captionL)
                        .foregroundStyle(event.type.dashboardTint)
                        .padding(.horizontal, Layout.Spacing.sm)
                        .padding(.vertical, Layout.Spacing.xs)
                        .background(event.type.dashboardTint.opacity(0.12), in: Capsule())
                }

                HStack(alignment: .top, spacing: Layout.Spacing.md) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(event.title)
                            .font(.titleS)
                            .foregroundStyle(AppColors.textPrimary)
                            .multilineTextAlignment(.leading)

                        Text(event.courseCode)
                            .font(.bodyS)
                            .foregroundStyle(AppColors.textSecondary)

                        HStack(spacing: Layout.Spacing.sm) {
                            DashboardMetaBadge(icon: "calendar", text: dateText)
                            DashboardMetaBadge(icon: "clock", text: timeText)
                        }
                    }

                    Spacer(minLength: Layout.Spacing.sm)

                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(event.type.dashboardTint.opacity(0.14))
                            .frame(width: 58, height: 58)

                        Image(systemName: event.type.dashboardIcon)
                            .font(.lexend(size: 24, weight: .semibold))
                            .foregroundStyle(event.type.dashboardTint)
                    }
                }
            }
            .padding(Layout.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(AppColors.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(AppColors.border.opacity(0.4), lineWidth: 1)
                    }
            )
            .shadow(color: AppColors.shadow.opacity(0.08), radius: 12, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardWeeklySnapshotCard: View {
    let stats: [DashboardWeeklyStat]
    let isNewUser: Bool

    private let compactColumns = [
        GridItem(.flexible(), spacing: Layout.Spacing.sm),
        GridItem(.flexible(), spacing: Layout.Spacing.sm)
    ]

    private var totalCount: Int {
        stats.reduce(0) { $0 + $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week at a Glance")
                        .font(.titleS)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(stats.isEmpty ? "No items this week." : "\(totalCount) item\(totalCount == 1 ? "" : "s") this week.")
                        .font(.captionL)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()
            }

            if stats.isEmpty {
                DashboardEmptySnapshotCard(
                    icon: isNewUser ? "text.book.closed.fill" : "checkmark.circle.fill",
                    title: isNewUser ? "Nothing here yet" : "Week is clear",
                    message: isNewUser
                        ? "Import a syllabus to get started."
                        : "No items left this week."
                )
            } else if stats.count == 1, let stat = stats.first {
                DashboardSingleWeeklyMetricCard(stat: stat)
            } else if stats.count <= 4 {
                LazyVGrid(columns: compactColumns, spacing: Layout.Spacing.sm) {
                    ForEach(stats) { stat in
                        DashboardWeeklyMetricCard(stat: stat)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Layout.Spacing.sm) {
                        ForEach(stats) { stat in
                            DashboardWeeklyMetricCard(stat: stat)
                                .frame(width: 168)
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(Layout.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColors.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppColors.border.opacity(0.38), lineWidth: 1)
                }
        )
    }
}

private struct DashboardSecondaryDeadlinesCard: View {
    let events: [EventItem]
    let onEventTapped: (EventItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            HStack {
                Text("Also Coming Up")
                    .font(.titleS)
                    .foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text("\(events.count)")
                    .font(.captionL)
                    .foregroundStyle(AppColors.textSecondary)
            }

            ForEach(events) { event in
                DashboardDeadlineRow(event: event, onTap: {
                    onEventTapped(event)
                })
            }
        }
        .padding(Layout.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColors.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppColors.border.opacity(0.38), lineWidth: 1)
                }
        )
    }
}

private struct DashboardNoDeadlineCard: View {
    let isNewUser: Bool

    var body: some View {
        HStack(spacing: Layout.Spacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.14))
                    .frame(width: 52, height: 52)

                Image(systemName: isNewUser ? "calendar.badge.plus" : "checkmark.circle.fill")
                    .font(.lexend(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(isNewUser ? "No deadlines yet" : "No urgent deadlines")
                    .font(.titleS)
                    .foregroundStyle(AppColors.textPrimary)
                Text(isNewUser ? "Import a syllabus to get started." : "Nothing due in the next 7 days.")
                    .font(.bodyS)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(Layout.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColors.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppColors.border.opacity(0.38), lineWidth: 1)
                }
        )
    }
}

private struct DashboardWeeklyStat: Identifiable {
    let id = UUID()
    let icon: String
    let count: Int
    let label: String
    let tint: Color
}

private struct DashboardWeeklyMetricCard: View {
    let stat: DashboardWeeklyStat

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            HStack {
                Image(systemName: stat.icon)
                    .font(.lexend(size: 16, weight: .semibold))
                    .foregroundStyle(stat.tint)
                    .frame(width: 34, height: 34)
                    .background(stat.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Spacer()

                Text("\(stat.count)")
                    .font(.lexend(size: 28, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
            }

            Text(stat.label)
                .font(.bodyS)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Layout.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.surfaceSecondary.opacity(0.58))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(stat.tint.opacity(0.18), lineWidth: 1)
                }
        )
    }
}

private struct DashboardSingleWeeklyMetricCard: View {
    let stat: DashboardWeeklyStat

    var body: some View {
        HStack(spacing: Layout.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(stat.tint.opacity(0.14))
                    .frame(width: 54, height: 54)

                Image(systemName: stat.icon)
                    .font(.lexend(size: 22, weight: .semibold))
                    .foregroundStyle(stat.tint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("\(stat.count) \(stat.label)")
                    .font(.titleS)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Spacer()
        }
        .padding(Layout.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.surfaceSecondary.opacity(0.58))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(stat.tint.opacity(0.18), lineWidth: 1)
                }
        )
    }
}

private struct DashboardEmptySnapshotCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: Layout.Spacing.md) {
            ZStack {
                Circle()
                    .fill(AppColors.accent.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.lexend(size: 20, weight: .medium))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppColors.textPrimary)
                Text(message)
                    .font(.bodyS)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(Layout.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppColors.surfaceSecondary.opacity(0.58))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(AppColors.border.opacity(0.3), lineWidth: 1)
                }
        )
    }
}

private struct DashboardDeadlineRow: View {
    let event: EventItem
    let onTap: () -> Void

    private var dayStamp: String {
        let calendar = Calendar.current
        let dayDifference = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: event.start)
        ).day ?? 0

        switch dayDifference {
        case ..<0:
            return "Past due"
        case 0:
            return "Today"
        case 1:
            return "Tomorrow"
        default:
            return event.start.formatted(.dateTime.weekday(.abbreviated))
        }
    }

    private var timeStamp: String {
        event.allDay == true ? "All Day" : event.start.formatted(.dateTime.hour().minute())
    }

    private var subtitleText: String {
        "\(event.courseCode) • \(timeStamp)"
    }

    var body: some View {
        Button {
            HapticFeedbackManager.shared.lightImpact()
            onTap()
        } label: {
            HStack(spacing: Layout.Spacing.md) {
                Image(systemName: event.type.dashboardIcon)
                    .font(.lexend(size: 16, weight: .semibold))
                    .foregroundStyle(event.type.dashboardTint)
                    .frame(width: 38, height: 38)
                    .background(event.type.dashboardTint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.body)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(subtitleText)
                        .font(.captionL)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(dayStamp)
                    .font(.captionL)
                    .foregroundStyle(event.type.dashboardTint)
                    .padding(.horizontal, Layout.Spacing.sm)
                    .padding(.vertical, Layout.Spacing.xs)
                    .background(event.type.dashboardTint.opacity(0.12), in: Capsule())
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

private struct DashboardMetaBadge: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
        .foregroundStyle(AppColors.textSecondary)
        .padding(.horizontal, Layout.Spacing.sm)
        .padding(.vertical, Layout.Spacing.xs)
        .background(AppColors.surfaceSecondary.opacity(0.7), in: Capsule())
    }
}

private struct MyCoursesSection: View {
    let courses: [Course]
    let events: [EventItem]
    let onCourseTapped: (Course) -> Void

    private var upcomingEvents: [EventItem] {
        let now = Date()
        return events.filter {
            guard let occurrenceDate = $0.dashboardOccurrenceDate(relativeTo: now) else { return false }
            return occurrenceDate >= now
        }
    }

    private var totalEventCount: Int {
        upcomingEvents.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("My Courses")
                        .font(.titleS)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(courses.isEmpty ? "Import a syllabus to start building your course spaces." : "\(courses.count) course\(courses.count == 1 ? "" : "s") connected to \(totalEventCount) upcoming item\(totalEventCount == 1 ? "" : "s").")
                        .font(.captionL)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Image(systemName: "books.vertical.fill")
                    .font(.lexend(size: 18, weight: .medium))
                    .foregroundStyle(AppColors.accent)
                    .frame(width: 38, height: 38)
                    .background(AppColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            if courses.isEmpty {
                DashboardEmptySnapshotCard(
                    icon: "book.closed",
                    title: "No course spaces yet",
                    message: "Once your syllabus is imported, this rail becomes a quick jump point into each course view."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Layout.Spacing.sm) {
                        ForEach(courses) { course in
                            CourseChipView(
                                course: course,
                                eventCount: upcomingEvents.filter { $0.courseCode == course.code }.count,
                                onTap: { onCourseTapped(course) }
                            )
                        }
                    }
                    .padding(.horizontal, 1)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(Layout.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColors.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppColors.border.opacity(0.38), lineWidth: 1)
                }
        )
    }
}

private extension EventItem {
    func dashboardOccurrenceDate(relativeTo now: Date, calendar: Calendar = .current) -> Date? {
        guard !needsDate else { return nil }
        guard let recurrenceRule, start < now else { return start }

        let timeComponents = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: start)
        let recurringWeekdays = dashboardWeekdays(from: recurrenceRule, calendar: calendar)
        let targetWeekdays = recurringWeekdays.isEmpty ? [calendar.component(.weekday, from: start)] : recurringWeekdays

        var nextOccurrence: Date?

        for weekday in targetWeekdays {
            var components = DateComponents()
            components.weekday = weekday
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            components.second = timeComponents.second
            components.nanosecond = timeComponents.nanosecond

            guard let candidate = calendar.nextDate(
                after: now,
                matching: components,
                matchingPolicy: .nextTime,
                direction: .forward
            ) else {
                continue
            }

            if let untilDate = dashboardRecurrenceEndDate(from: recurrenceRule, calendar: calendar), candidate > untilDate {
                continue
            }

            if nextOccurrence == nil || candidate < nextOccurrence! {
                nextOccurrence = candidate
            }
        }

        return nextOccurrence
    }

    private func dashboardWeekdays(from recurrenceRule: String, calendar: Calendar) -> [Int] {
        guard let range = recurrenceRule.range(of: "BYDAY=") else { return [] }
        let afterByDay = recurrenceRule[range.upperBound...]
        let byDayValue = afterByDay.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true).first ?? Substring()

        let weekdayMap: [String: Int] = [
            "SU": 1,
            "MO": 2,
            "TU": 3,
            "WE": 4,
            "TH": 5,
            "FR": 6,
            "SA": 7
        ]

        return byDayValue
            .split(separator: ",")
            .compactMap { weekdayMap[String($0).uppercased()] }
            .filter { (1...7).contains($0) }
    }

    private func dashboardRecurrenceEndDate(from recurrenceRule: String, calendar: Calendar) -> Date? {
        guard let range = recurrenceRule.range(of: "UNTIL=") else { return nil }
        let afterUntil = recurrenceRule[range.upperBound...]
        let untilValue = afterUntil.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true).first ?? Substring()

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if untilValue.contains("T") {
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        } else {
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = "yyyyMMdd"
        }

        return formatter.date(from: String(untilValue))
    }
}

private extension EventItem.EventType {
    var dashboardTint: Color {
        switch self {
        case .assignment:
            return AppColors.eventAssignment
        case .quiz:
            return AppColors.eventQuiz
        case .midterm, .final:
            return AppColors.eventExam
        case .lab:
            return AppColors.eventLab
        case .lecture:
            return AppColors.eventLecture
        case .tutorial:
            return AppColors.info
        case .officeHours:
            return AppColors.accentSecondary
        case .importantDate:
            return AppColors.warning
        case .other:
            return AppColors.accent
        }
    }

    var dashboardIcon: String {
        switch self {
        case .assignment:
            return "doc.text.fill"
        case .quiz:
            return "questionmark.circle.fill"
        case .midterm, .final:
            return "graduationcap.fill"
        case .lab:
            return "flask.fill"
        case .lecture:
            return "person.3.fill"
        case .tutorial:
            return "person.2.fill"
        case .officeHours:
            return "clock.fill"
        case .importantDate:
            return "exclamationmark.triangle.fill"
        case .other:
            return "calendar"
        }
    }

    func dashboardLabel(count: Int) -> String {
        switch self {
        case .assignment:
            return count == 1 ? "assignment due" : "assignments due"
        case .quiz:
            return count == 1 ? "quiz scheduled" : "quizzes scheduled"
        case .midterm, .final:
            return count == 1 ? "exam approaching" : "exams approaching"
        case .lab:
            return count == 1 ? "lab block" : "lab blocks"
        case .lecture:
            return count == 1 ? "lecture" : "lectures"
        case .tutorial:
            return count == 1 ? "tutorial" : "tutorials"
        case .officeHours:
            return count == 1 ? "office hour" : "office hours"
        case .importantDate:
            return count == 1 ? "important date" : "important dates"
        case .other:
            return count == 1 ? "other item" : "other items"
        }
    }
}

// MARK: - Shared Shimmer

struct DashboardShimmerView: View {
    var body: some View {
        VStack(spacing: Layout.Spacing.xl) {
            VStack(spacing: Layout.Spacing.lg) {
                HStack {
                    Text("Refreshing...")
                        .font(.titleM)
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        .scaleEffect(0.8)
                }

                Rectangle()
                    .fill(AppColors.separator)
                    .frame(height: 1)
            }
            .padding(.top, Layout.Spacing.lg)

            VStack(spacing: Layout.Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerCard()
                }
            }

            Spacer()
        }
        .padding(.horizontal, Layout.Spacing.md)
    }
}

struct ShimmerCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack {
                ShimmerRectangle(width: 60, height: 60)
                    .clipShape(.rect(cornerRadius: Layout.CornerRadius.sm))

                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    ShimmerRectangle(width: 120, height: 16)
                    ShimmerRectangle(width: 80, height: 14)
                }

                Spacer()

                ShimmerRectangle(width: 30, height: 30)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                ShimmerRectangle(width: .infinity, height: 12)
                ShimmerRectangle(width: 200, height: 12)
            }
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .clipShape(.rect(cornerRadius: Layout.CornerRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                .stroke(AppColors.border, lineWidth: 1)
        }
        .cardShadowLight()
    }
}

struct ShimmerRectangle: View {
    let width: CGFloat?
    let height: CGFloat
    @State private var animateGradient = false

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppColors.separator.opacity(0.3),
                        AppColors.separator.opacity(0.1),
                        AppColors.separator.opacity(0.3)
                    ]),
                    startPoint: animateGradient ? .leading : .trailing,
                    endPoint: animateGradient ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: Layout.CornerRadius.xs))
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(AppNavigationManager())
        .environmentObject(ThemeManager())
        .environmentObject(EventStore())
        .environmentObject(CourseRepository())
        .environmentObject(GradingRepository())
        .environmentObject(ImportViewModel(
            extractor: PDFKitExtractor(),
            parser: SyllabusParserRemote(apiClient: URLSessionAPIClient(
                configuration: URLSessionAPIClient.Configuration(
                    baseURL: URL(string: "https://api.example.com")!,
                    requestTimeout: 30,
                    maxRetryCount: 1
                )
            )),
            eventStore: EventStore(),
            courseRepository: CourseRepository(),
            gradingRepository: GradingRepository()
        ))
}
