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
    @StateObject private var errorHandler = ErrorHandler()
    @State private var isRefreshing = false
    @State private var showShimmer = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var showingImportView = false
    @State private var fabPressed = false
    @State private var fabExpanded = false
    @State private var editingEvent: EventItem?
    @State private var isCreatingNewEvent = false

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                let headerHeight = geo.safeAreaInsets.top + 4

                ZStack(alignment: .top) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // Custom header with consistent padding
                            VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                                Text("Dashboard")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                if eventStore.events.isEmpty {
                                    Text("Welcome aboard! Let's get your semester organized.")
                                        .font(.body)
                                        .foregroundColor(AppColors.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(.horizontal, Layout.Spacing.md)
                            .padding(.top, Layout.Spacing.sm)
                            .padding(.bottom, Layout.Spacing.sm)
                            
                            if showShimmer {
                                DashboardShimmerView()
                                    .transition(.opacity)
                            } else if eventStore.events.isEmpty {
                                DashboardEmptyView(showingImportView: $showingImportView)
                                    .transition(.opacity)
                            } else {
                                // New modular dashboard structure
                                VStack(spacing: Layout.Spacing.xl) {
                                    DashboardHeaderSummaryView(events: eventStore.events)
                                    DashboardWeekCarouselView(events: eventStore.events, onDayTapped: { date in
                                        // Find the first event on this date and scroll to it
                                        let calendar = Calendar.current
                                        if let firstEvent = eventStore.events.first(where: { event in
                                            calendar.isDate(event.start, inSameDayAs: date)
                                        }) {
                                            navigationManager.scrollToEventId = firstEvent.id
                                        }
                                        navigationManager.selectedTabRoute = .reminders
                                    })
                                    DashboardHighlightsView(events: eventStore.events, onEventTapped: { event in
                                        navigationManager.scrollToEventId = event.id
                                        navigationManager.selectedTabRoute = .reminders
                                    })
                                    DashboardInsightsView(events: eventStore.events)
                                }
                                .padding(.horizontal, Layout.Spacing.md)
                                .padding(.vertical, Layout.Spacing.xl)
                                .transition(.opacity)
                            }
                        }
                        .padding(.top, 40)
                    }
                    .background(AppColors.background)
                    .refreshable {
                        await performRefreshAsync()
                    }

                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .frame(height: headerHeight)
                            .overlay(alignment: .bottom) {
                                Color.primary.opacity(0.12)
                                    .frame(height: 1)
                                    .allowsHitTesting(false)
                            }
                            .ignoresSafeArea(edges: .top)
                        Spacer()
                    }
                }
                .background(AppColors.background)
                .overlay(alignment: .bottomTrailing) {
                    if !eventStore.events.isEmpty {
                        fabButton
                            .padding(.trailing, Layout.Spacing.xl)
                            .padding(.bottom, Layout.Spacing.xl)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .task {
            // Load events from Supabase when dashboard appears
            await eventStore.fetchEvents()
        }
        .alert("Error", isPresented: $errorHandler.showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorHandler.errorMessage)
        }
        .sheet(isPresented: $showingImportView) {
            ImportView()
                .environmentObject(navigationManager)
        }
        .fullScreenCover(item: $editingEvent) { event in
            EventEditView(event: event) { updated in
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
        .onChange(of: showingImportView) { newValue in
            if !newValue { fabExpanded = false }
        }
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

// MARK: - Floating Action Button

private extension DashboardView {
    var fabButton: some View {
        ZStack(alignment: .bottomTrailing) {
            // Backdrop dimming
            if fabExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            fabExpanded = false
                        }
                    }
                    .transition(.opacity)
            }
            
            VStack(alignment: .trailing, spacing: Layout.Spacing.md) {
                // Expanded options
                if fabExpanded {
                    VStack(spacing: Layout.Spacing.sm) {
                        // Add Reminder option
                        FABOption(
                            icon: "plus.circle.fill",
                            label: "Add Reminder",
                            color: Color.blue,
                            action: {
                                HapticFeedbackManager.shared.mediumImpact()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    fabExpanded = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    createNewEvent()
                                }
                            }
                        )
                        
                        // Upload Syllabus option
                        FABOption(
                            icon: "doc.badge.plus",
                            label: "Upload Syllabus",
                            color: AppColors.accent,
                            action: {
                                HapticFeedbackManager.shared.mediumImpact()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    fabExpanded = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showingImportView = true
                                }
                            }
                        )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Main FAB button
                Button(action: handleFabTap) {
                    Image(systemName: fabExpanded ? "xmark" : "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .padding(24)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.886, green: 0.714, blue: 0.275), // #E2B646
                                    Color(red: 0.816, green: 0.612, blue: 0.118)  // #D09C1E
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .elevatedShadowLight()
                        .rotationEffect(.degrees(fabExpanded ? 135 : 0))
                }
                .scaleEffect(fabPressed ? 0.90 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: fabPressed)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: fabExpanded)
                .accessibilityLabel(fabExpanded ? "Close menu" : "Open quick actions")
            }
        }
    }

    func handleFabTap() {
        HapticFeedbackManager.shared.mediumImpact()
        fabPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            fabPressed = false
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            fabExpanded.toggle()
        }
    }

    func createNewEvent() {
        let now = Date()
        let newEvent = EventItem(
            id: UUID().uuidString,
            courseCode: "", // Empty courseCode to avoid deletion conflicts
            type: .assignment,
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

// MARK: - FAB Option

private struct FABOption: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
            action()
        }) {
            HStack(spacing: Layout.Spacing.sm) {
                Text(label)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(color)
                            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
            }
            .padding(.horizontal, Layout.Spacing.md)
            .padding(.vertical, Layout.Spacing.sm)
            .background(
                Capsule()
                    .fill(AppColors.surface)
                    .shadow(color: AppColors.shadow.opacity(0.15), radius: 8, x: 0, y: 4)
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Dashboard Empty State

struct DashboardEmptyView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @State private var buttonScale: CGFloat = 1.0
    @State private var showGlow: Bool = false
    @Binding var showingImportView: Bool
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xxl) {
            // Illustration from dashboard-image.png
            VStack(spacing: Layout.Spacing.xl) {
                ZStack {
                    Image("DashboardEmpty")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 280, maxHeight: 240)
                        .scaleEffect(showGlow ? 1.04 : 0.95)
                        .opacity(showGlow ? 1.0 : 0.85)
                        .animation(
                            Animation.easeInOut(duration: 2.8)
                                .repeatForever(autoreverses: true),
                            value: showGlow
                        )
                        .onAppear { 
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showGlow = true 
                            }
                        }
                }
                .frame(width: 280, height: 240)
                .clipped()
                
                // Concise Copy
                VStack(spacing: Layout.Spacing.md) {
                    Text("Nothing here yet! Upload a syllabus to get started.")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, Layout.Spacing.xl)
                }
            }
            .padding(.horizontal, Layout.Spacing.md)
            
            // Action Section
            VStack(spacing: Layout.Spacing.lg) {
                Spacer(minLength: 40) // Adds vertical empty space above the button (tweak value if needed)
                // Primary CTA - Large gradient button
                Button {
                    HapticFeedbackManager.shared.mediumImpact()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        buttonScale = 0.95
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            buttonScale = 1.0
                        }
                    }
                    showingImportView = true
                } label: {
                    HStack(spacing: Layout.Spacing.sm) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Import Syllabus PDFs")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(height: 55)     // Increased height
                    .frame(maxWidth: 320) // Decreased width
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.886, green: 0.714, blue: 0.275), // Medium gold
                                Color(red: 0.722, green: 0.565, blue: 0.110)  // Darker gold
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(Layout.CornerRadius.lg)
                    .shadow(color: AppColors.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .scaleEffect(buttonScale)
            }
            .padding(.bottom, Layout.Spacing.xl)
        }
    }
}

// MARK: - Dashboard Header Summary

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
                .font(.system(size: 12, weight: .semibold))
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
                    .font(.system(size: 20, weight: .semibold))
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
                    .font(.system(size: 14, weight: .semibold))
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
                .font(.system(size: 18, weight: .semibold))
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
