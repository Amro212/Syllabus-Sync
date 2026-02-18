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
                        VStack(spacing: Layout.Spacing.xl) {
                            QuickInsightCardView(events: eventStore.events, isNewUser: !hasAddedEvents && eventStore.events.isEmpty)
                            
                            WeekAtGlanceView(events: eventStore.events, isNewUser: !hasAddedEvents && eventStore.events.isEmpty)
                            
                            UpcomingDeadlinesView(
                                events: eventStore.events,
                                isNewUser: !hasAddedEvents && eventStore.events.isEmpty,
                                onEventTapped: { event in
                                    navigationManager.scrollToEventId = event.id
                                    navigationManager.switchTab(to: .reminders)
                                }
                            )
                        }
                        .padding(.horizontal, Layout.Spacing.md)
                        .padding(.vertical, Layout.Spacing.xl)
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
            // Load user-specific preference
            loadUserPreference()
            
            await eventStore.fetchEvents()
            if !eventStore.events.isEmpty {
                updateUserPreference(true)
            }
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

        await MainActor.run {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isRefreshing = false
                showShimmer = false
            }
        }
    }
}

// MARK: - FAB Option


// MARK: - Legacy Components

// DashboardEmptyView removed as we now use inline empty states within sections.

// MARK: - Week At a Glance

// MARK: - Dashboard Components

private struct WeekAtGlanceView: View {
    let events: [EventItem]
    let isNewUser: Bool
    
    private var thisWeekEvents: [EventItem] {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? now
        
        return events.filter { event in
            // Only show upcoming events (not past ones), matching RemindersView behavior
            event.start >= now && event.start < endOfWeek
        }
    }
    
    private var stats: [(icon: String, count: Int, label: String)] {
        var assignments = 0
        var labs = 0
        var exams = 0
        var quizzes = 0
        var lectures = 0
        var other = 0
        
        for event in thisWeekEvents {
            switch event.type {
            case .assignment: assignments += 1
            case .lab: labs += 1
            case .midterm, .final: exams += 1
            case .quiz: quizzes += 1
            case .lecture: lectures += 1
            case .other: other += 1
            }
        }
        
        var result: [(icon: String, count: Int, label: String)] = []
        if assignments > 0 { result.append(("doc.text.fill", assignments, assignments == 1 ? "Assignment due" : "Assignments due")) }
        if labs > 0 { result.append(("flask.fill", labs, labs == 1 ? "Lab this week" : "Labs this week")) }
        if exams > 0 { result.append(("graduationcap.fill", exams, exams == 1 ? "Exam approaching" : "Exams approaching")) }
        if quizzes > 0 { result.append(("questionmark.circle.fill", quizzes, quizzes == 1 ? "Quiz this week" : "Quizzes this week")) }
        if lectures > 0 { result.append(("person.3.fill", lectures, lectures == 1 ? "Lecture this week" : "Lectures this week")) }
        if other > 0 { result.append(("calendar.badge.clock", other, other == 1 ? "Other event" : "Other events")) }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            Text("This Week at a Glance")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            if stats.isEmpty {
                // Empty State Card
                VStack(spacing: Layout.Spacing.md) {
                    Image(systemName: isNewUser ? "text.book.closed.fill" : "checkmark.circle.fill")
                        .font(.lexend(size: 48, weight: .regular))
                        .foregroundColor(AppColors.accent.opacity(0.8))
                        .padding(.top, Layout.Spacing.lg)
                    
                    Text(isNewUser ? "Welcome to Syllabus Sync!" : "No events this week")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(isNewUser ? "It looks a little empty here. Start by adding your first course or assignment using the '+' button below!" : "You're clear for the week! Great time to study ahead.")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Layout.Spacing.lg)
                        .padding(.bottom, Layout.Spacing.lg)
                }
                .frame(maxWidth: .infinity)
                .background(AppColors.surface)
                .cornerRadius(20)
                
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Layout.Spacing.md) {
                        ForEach(Array(stats.enumerated()), id: \.offset) { _, stat in
                            GlanceStatCard(icon: stat.icon, count: stat.count, label: stat.label)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
                .padding(.horizontal, -Layout.Spacing.md)
                .padding(.leading, Layout.Spacing.md)
            }
        }
    }
}

private struct GlanceStatCard: View {
    let icon: String
    let count: Int
    let label: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Icon container at top-left
            Image(systemName: icon)
                .font(.lexend(size: 22, weight: .medium))
                .foregroundColor(AppColors.accent)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.accent.opacity(0.2))
                )
            
            Spacer()
            
            // Count and Label at bottom
            Text("\(count)")
                .font(.lexend(size: 42, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text(label)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 150, height: 170, alignment: .topLeading)
        .padding(16)
        .background(AppColors.surface)
        .cornerRadius(20)
    }
}

// MARK: - Upcoming Deadlines

private struct UpcomingDeadlinesView: View {
    let events: [EventItem]
    let isNewUser: Bool
    let onEventTapped: (EventItem) -> Void
    
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
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            Text("Upcoming Deadlines")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            if upcomingEvents.isEmpty {
                VStack(spacing: Layout.Spacing.md) {
                    Image(systemName: isNewUser ? "calendar.badge.plus" : "calendar.badge.checkmark")
                        .font(.lexend(size: 40, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, Layout.Spacing.md)
                    
                    Text(isNewUser ? "No deadlines yet! Tap the '+' button to add your first task or event." : "No upcoming deadlines")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Layout.Spacing.lg)
                        .padding(.bottom, Layout.Spacing.md)
                }
                .frame(maxWidth: .infinity)
                .background(AppColors.surface)
                .cornerRadius(20)
            } else {
                VStack(spacing: Layout.Spacing.sm) {
                    ForEach(upcomingEvents) { event in
                        DeadlineRow(event: event, onTap: { onEventTapped(event) })
                    }
                }
            }
        }
    }
}

private struct DeadlineRow: View {
    let event: EventItem
    let onTap: () -> Void
    
    private var iconColor: Color {
        switch event.type {
        case .assignment: return Color.blue
        case .lab: return Color.green
        case .midterm, .final: return Color.red
        case .quiz: return Color.orange
        case .lecture, .other: return Color.gray
        }
    }
    
    private var icon: String {
        switch event.type {
        case .assignment: return "doc.text.fill"
        case .lab: return "flask.fill"
        case .midterm, .final: return "graduationcap.fill"
        case .quiz: return "questionmark.circle.fill"
        case .lecture: return "person.3.fill"
        case .other: return "calendar"
        }
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter.string(from: event.start)
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
            onTap()
        }) {
            HStack(spacing: Layout.Spacing.md) {
                // Color-coded icon
                Image(systemName: icon)
                    .font(.lexend(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .fill(iconColor.opacity(0.2))
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Text(event.courseCode)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Date
                Text(formattedDate)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(Layout.Spacing.sm)
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.md)
            .shadow(color: AppColors.shadow.opacity(0.06), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Quick Insight Card

private struct QuickInsightCardView: View {
    let events: [EventItem]
    let isNewUser: Bool
    
    private var insight: (title: String, description: String, icon: String, gradientColors: [Color]) {
        if isNewUser && events.isEmpty {
            return (
                "Your personal study assistant",
                "Once you add your courses and assignments, we'll provide smart insights to help you stay on track!",
                "lightbulb.fill",
                [AppColors.accent.opacity(0.3), AppColors.accent.opacity(0.1)]
            )
        }
        
        // Date logic fix: Check "Today" specifically
        let now = Date()
        let calendar = Calendar.current
        
        // Start of today
        let startOfToday = calendar.startOfDay(for: now)
        // End of today (start of tomorrow)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
        // Use for 48 hour window
        let twoDaysFromNow = calendar.date(byAdding: .day, value: 2, to: now)!
        
        let urgentEvents = events.filter { $0.start >= now && $0.start <= twoDaysFromNow }
        let urgentCount = urgentEvents.count
        
        // Check for Deadline Today specifically
        if let firstUrgent = urgentEvents.sorted(by: { $0.start < $1.start }).first,
           firstUrgent.start < startOfTomorrow {
             return (
                "Deadline Today",
                "Don't forget: \(firstUrgent.title) for \(firstUrgent.courseCode) is due today!",
                "exclamationmark.circle.fill", // More urgent icon
                 [Color.red.opacity(0.3), Color.red.opacity(0.1)] // Urgent color
             )
        }
        
        if urgentCount >= 2 {
            let suggestedEvent = urgentEvents.sorted { $0.start > $1.start }.first
            let suggestion = suggestedEvent.map { "Consider starting your \($0.title) for \($0.courseCode) today." } ?? ""
            
            return (
                "Heavy Workload Ahead",
                "You have \(urgentCount) deadlines in the next 48 hours. \(suggestion)",
                "hourglass",
                 [Color.orange.opacity(0.3), Color.orange.opacity(0.1)]
            )
        } else if urgentCount == 1, let next = urgentEvents.first {
             // If we reached here, it's not today, so it must be tomorrow
            return (
                "Deadline Tomorrow",
                "Don't forget: \(next.title) for \(next.courseCode) is due soon.",
                 "clock.fill",
                 [Color.yellow.opacity(0.3), Color.yellow.opacity(0.1)]
            )
        } else {
            return (
                "You're On Track! 🎉",
                "No urgent deadlines in the next 48 hours. Great time to get ahead!",
                 "hand.thumbsup.fill",
                 [Color.green.opacity(0.3), Color.green.opacity(0.1)]
            )
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            Text("Quick Insights")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
            
            HStack(alignment: .top, spacing: Layout.Spacing.md) {
                // Dynamic icon
                Image(systemName: insight.icon)
                    .font(.lexend(size: 24, weight: .regular))
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            // Use the primary color of the gradient for the icon bg, simplifed to accent for now or logic based
                            .fill(AppColors.accent)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text(insight.description)
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(Layout.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: insight.gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(Layout.CornerRadius.lg)
            .shadow(color: AppColors.shadow.opacity(0.08), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Dashboard Header Summary (Legacy - kept for potential future use)

private struct DashboardHeaderSummaryView: View {
    let events: [EventItem]
    
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12:
            return "Good morning"
        case 12..<17:
            return "Good afternoon"
        default:
            return "Good evening"
        }
    }
    
    private var thisWeekEvents: [EventItem] {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? now
        
        return events.filter { event in
            event.start >= startOfWeek && event.start < endOfWeek
        }
    }
    
    private var eventCounts: (assignments: Int, labs: Int, exams: Int) {
        var assignments = 0
        var labs = 0
        var exams = 0
        
        for event in thisWeekEvents {
            switch event.type {
            case .assignment:
                assignments += 1
            case .lab:
                labs += 1
            case .midterm, .final:
                exams += 1
            default:
                break
            }
        }
        
        return (assignments, labs, exams)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            // Greeting
            Text("\(greeting) 👋")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            // Context
            Text("Here's what your week looks like:")
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
            
            // Stats Pills
            HStack(spacing: Layout.Spacing.sm) {
                let counts = eventCounts
                if counts.assignments > 0 {
                    StatPill(count: counts.assignments, label: counts.assignments == 1 ? "Assignment" : "Assignments", icon: "doc.text.fill")
                }
                if counts.labs > 0 {
                    StatPill(count: counts.labs, label: counts.labs == 1 ? "Lab" : "Labs", icon: "flask.fill")
                }
                if counts.exams > 0 {
                    StatPill(count: counts.exams, label: counts.exams == 1 ? "Exam" : "Exams", icon: "graduationcap.fill")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StatPill: View {
    let count: Int
    let label: String
    let icon: String
    
    var body: some View {
        HStack(spacing: Layout.Spacing.xs) {
            Image(systemName: icon)
                .font(.lexend(size: 12, weight: .semibold))
            Text("\(count) \(label)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundColor(AppColors.textPrimary)
        .padding(.horizontal, Layout.Spacing.sm)
        .padding(.vertical, Layout.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        )
    }
}

// MARK: - Week Carousel

private struct DashboardWeekCarouselView: View {
    let events: [EventItem]
    let onDayTapped: (Date) -> Void
    
    @State private var selectedDayIndex: Int = 0
    
    private var weekDays: [Date] {
        let calendar = Calendar.current
        let today = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startOfWeek)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            Text("This Week's Schedule")
                .font(.titleS)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Layout.Spacing.md) {
                    ForEach(Array(weekDays.enumerated()), id: \.offset) { index, date in
                        DayCard(
                            date: date,
                            events: eventsForDay(date),
                            onTap: { onDayTapped(date) }
                        )
                    }
                }
                .padding(.horizontal, 2) // Prevent shadow clipping
                .padding(.vertical, 4)
            }
            .padding(.horizontal, -Layout.Spacing.md) // Extend to edge
            .padding(.leading, Layout.Spacing.md)
        }
    }
    
    private func eventsForDay(_ date: Date) -> [EventItem] {
        let calendar = Calendar.current
        return events.filter { event in
            calendar.isDate(event.start, inSameDayAs: date)
        }.prefix(3).map { $0 }
    }
}

private struct DayCard: View {
    let date: Date
    let events: [EventItem]
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
            onTap()
        }) {
            VStack(spacing: Layout.Spacing.sm) {
                // Date Header
                VStack(spacing: 2) {
                    Text(dayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isToday ? Color.white : AppColors.textSecondary)
                    
                    Text(dayNumber)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(isToday ? Color.white : AppColors.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Layout.Spacing.sm)
                .background(
                    isToday
                        ? LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.886, green: 0.714, blue: 0.275),
                                Color(red: 0.816, green: 0.612, blue: 0.118)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            gradient: Gradient(colors: [AppColors.surface, AppColors.surface]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                )
                .cornerRadius(Layout.CornerRadius.md)
                
                // Events Preview
                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    if events.isEmpty {
                        Text("No events")
                            .font(.caption2)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Layout.Spacing.sm)
                    } else {
                        ForEach(events.prefix(3)) { event in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(colorForEventType(event.type))
                                    .frame(width: 6, height: 6)
                                
                                Text(event.title)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Layout.Spacing.sm)
                .padding(.bottom, Layout.Spacing.sm)
            }
            .frame(width: 120)
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                    .stroke(isToday ? AppColors.accent.opacity(0.3) : AppColors.border, lineWidth: isToday ? 2 : 1)
            )
            .shadow(color: AppColors.shadow.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    private func colorForEventType(_ type: EventItem.EventType) -> Color {
        switch type {
        case .assignment:
            return Color.blue
        case .lab:
            return Color.purple
        case .midterm, .final:
            return Color.red
        case .quiz:
            return Color.orange
        case .lecture:
            return Color.green
        case .other:
            return Color.gray
        }
    }
}

// MARK: - Upcoming Highlights

private struct DashboardHighlightsView: View {
    let events: [EventItem]
    let onEventTapped: (EventItem) -> Void
    
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
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            Text("Upcoming Highlights")
                .font(.titleS)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            if upcomingEvents.isEmpty {
                Text("No upcoming events in the next 7 days")
                    .font(.body)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, Layout.Spacing.xl)
            } else {
                VStack(spacing: Layout.Spacing.sm) {
                    ForEach(upcomingEvents) { event in
                        HighlightCard(event: event, onTap: { onEventTapped(event) })
                    }
                }
            }
        }
    }
}

private struct HighlightCard: View {
    let event: EventItem
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    private var daysUntil: String {
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: event.start)).day ?? 0
        
        if days == 0 {
            return "today"
        } else if days == 1 {
            return "tomorrow"
        } else {
            return "in \(days) days"
        }
    }
    
    private var icon: String {
        switch event.type {
        case .assignment:
            return "doc.text.fill"
        case .lab:
            return "flask.fill"
        case .midterm, .final:
            return "graduationcap.fill"
        case .quiz:
            return "questionmark.circle.fill"
        case .lecture:
            return "person.fill"
        case .other:
            return "calendar"
        }
    }
    
    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
            onTap()
        }) {
            HStack(spacing: Layout.Spacing.md) {
                // Icon
                Image(systemName: icon)
                    .font(.lexend(size: 20, weight: .semibold))
                    .foregroundColor(AppColors.accent)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(AppColors.accent.opacity(0.1))
                    )
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    HStack(spacing: Layout.Spacing.xs) {
                        Text(event.courseCode)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(daysUntil)
                            .font(.caption)
                            .foregroundColor(AppColors.accent)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.lexend(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(Layout.Spacing.md)
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Insights

private struct DashboardInsightsView: View {
    let events: [EventItem]
    
    private var thisWeekEvents: [EventItem] {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? now
        
        return events.filter { event in
            event.start >= startOfWeek && event.start < endOfWeek
        }
    }
    
    private var todayEvents: [EventItem] {
        events.filter { Calendar.current.isDateInToday($0.start) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            Text("Insights")
                .font(.titleS)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            VStack(spacing: Layout.Spacing.sm) {
                // Week overview insight - only show if there are events this week
                if !thisWeekEvents.isEmpty {
                    let count = thisWeekEvents.count
                    InsightCard(
                        icon: "calendar.badge.clock",
                        text: "You have \(count) event\(count == 1 ? "" : "s") scheduled this week",
                        accentColor: Color.purple
                    )
                }
                
                // Today insight
                if todayEvents.isEmpty {
                    InsightCard(
                        icon: "checkmark.circle.fill",
                        text: "No due items for today 🎉",
                        accentColor: Color.blue
                    )
                } else {
                    InsightCard(
                        icon: "clock.fill",
                        text: "You have \(todayEvents.count) event\(todayEvents.count == 1 ? "" : "s") due today",
                        accentColor: Color.orange
                    )
                }
            }
        }
    }
}

private struct InsightCard: View {
    let icon: String
    let text: String
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: Layout.Spacing.md) {
            Image(systemName: icon)
                .font(.lexend(size: 18, weight: .semibold))
                .foregroundColor(accentColor)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(accentColor.opacity(0.1))
                )
            
            Text(text)
                .font(.body)
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(2)
            
            Spacer()
        }
        .padding(Layout.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        )
    }
}

// MARK: - Event List (Deprecated - moved to Reminders tab)


// MARK: - Dashboard Shimmer

struct DashboardShimmerView: View {
    @State private var animateShimmer = false
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xl) {
            // Header Section
            VStack(spacing: Layout.Spacing.lg) {
                HStack {
                    Text("Refreshing...")
                        .font(.titleM)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)
                    
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
            
            // Content Shimmer
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
    @State private var animateGradient = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack {
                ShimmerRectangle(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.sm))
                
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
        .cornerRadius(Layout.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .cardShadowLight()
    }
}

struct ShimmerRectangle: View {
    let width: CGFloat?
    let height: CGFloat
    @State private var animateGradient = false
    
    init(width: CGFloat?, height: CGFloat) {
        self.width = width
        self.height = height
    }
    
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
            .cornerRadius(Layout.CornerRadius.xs)
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
        .environmentObject(ImportViewModel(
            extractor: PDFKitExtractor(),
            parser: SyllabusParserRemote(apiClient: URLSessionAPIClient(
                configuration: URLSessionAPIClient.Configuration(
                    baseURL: URL(string: "https://api.example.com")!,
                    requestTimeout: 30,
                    maxRetryCount: 1
                )
            )),
            eventStore: EventStore()
        ))
}
