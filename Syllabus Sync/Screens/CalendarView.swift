//
//  CalendarView.swift
//  Syllabus Sync
//
//  Created by Cursor on 2025-09-06.
//  Redesigned for calendar grid view on 2026-01-10.
//

import SwiftUI

// MARK: - Calendar View Mode

enum CalendarViewMode: String, CaseIterable {
    case month = "Month"
    case week = "Week"
}

// MARK: - Calendar View

struct CalendarView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var eventStore: EventStore
    
    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var viewMode: CalendarViewMode = .month
    
    private var events: [CalendarEvent] {
        CalendarEvent.make(from: eventStore.events)
    }
    
    private var eventsForSelectedDate: [CalendarEvent] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }
    
    private var eventsThisWeek: [CalendarEvent] {
        let calendar = Calendar.current
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return []
        }
        return events.filter { $0.date >= weekStart && $0.date < weekEnd }
            .sorted { $0.date < $1.date }
    }
    
    var body: some View {
        GeometryReader { geo in
            let headerHeight = geo.safeAreaInsets.top + 4
            
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // Month Title
                    HStack {
                        Text(monthYearString)
                            .font(.titleL)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.accent)
                        
                        Spacer()
                        
                        // Add button placeholder for future functionality
                        Button(action: {
                            HapticFeedbackManager.shared.lightImpact()
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                        }
                    }
                    .padding(.horizontal, Layout.Spacing.lg)
                    .padding(.top, 70)
                    .padding(.bottom, Layout.Spacing.md)
                    
                    // View Mode Toggle
                    CalendarViewModeToggle(selectedMode: $viewMode)
                        .padding(.horizontal, Layout.Spacing.lg)
                        .padding(.bottom, Layout.Spacing.lg)
                    
                    // Calendar Content
                    if viewMode == .month {
                        MonthCalendarView(
                            currentMonth: $currentMonth,
                            selectedDate: $selectedDate,
                            events: events
                        )
                        .padding(.horizontal, Layout.Spacing.lg)
                    } else {
                        WeekCalendarView(
                            selectedDate: $selectedDate,
                            events: events
                        )
                        .padding(.horizontal, Layout.Spacing.lg)
                    }
                    
                    // Events List
                    ScrollView {
                        VStack(spacing: Layout.Spacing.md) {
                            if viewMode == .month {
                                if eventsForSelectedDate.isEmpty {
                                    CalendarEmptyStateView()
                                        .padding(.top, Layout.Spacing.xl)
                                } else {
                                    ForEach(eventsForSelectedDate) { event in
                                        CalendarEventCard(event: event, showDate: false)
                                    }
                                }
                            } else {
                                if eventsThisWeek.isEmpty {
                                    CalendarEmptyStateView()
                                        .padding(.top, Layout.Spacing.xl)
                                } else {
                                    ForEach(eventsThisWeek) { event in
                                        CalendarEventCard(event: event, showDate: true)
                                    }
                                }
                            }
                            
                            // Motivational message
                            if !eventsThisWeek.isEmpty || !eventsForSelectedDate.isEmpty {
                                MotivationalMessageView()
                                    .padding(.top, Layout.Spacing.xl)
                            }
                        }
                        .padding(.horizontal, Layout.Spacing.lg)
                        .padding(.top, Layout.Spacing.lg)
                        .padding(.bottom, 100) // Bottom padding for tab bar
                    }
                }
                .background(AppColors.background)
                
                // Custom Top Bar (Sticky)
                VStack(spacing: 0) {
                    HStack {
                        Text("Calendar")
                            .font(.titleL)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "person.circle")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.textPrimary)
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
    }
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }
}

// MARK: - View Mode Toggle

struct CalendarViewModeToggle: View {
    @Binding var selectedMode: CalendarViewMode
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMode = mode
                    }
                    HapticFeedbackManager.shared.lightImpact()
                }) {
                    Text(mode.rawValue)
                        .font(.bodyS)
                        .fontWeight(.medium)
                        .foregroundColor(selectedMode == mode ? AppColors.textPrimary : AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Layout.Spacing.sm)
                        .background(
                            selectedMode == mode ?
                            AppColors.surface :
                            Color.clear
                        )
                        .cornerRadius(Layout.CornerRadius.md)
                }
            }
        }
        .padding(4)
        .background(AppColors.surfaceSecondary)
        .cornerRadius(Layout.CornerRadius.lg)
    }
}

// MARK: - Month Calendar View

struct MonthCalendarView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let events: [CalendarEvent]
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: Layout.Spacing.md) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.captionL)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: columns, spacing: Layout.Spacing.sm) {
                ForEach(daysInMonth, id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                            hasEvents: hasEvents(on: date)
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedDate = date
                            }
                            HapticFeedbackManager.shared.lightImpact()
                        }
                    } else {
                        Color.clear
                            .frame(height: 44)
                    }
                }
            }
        }
    }
    
    private var daysInMonth: [Date?] {
        var days: [Date?] = []
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return days
        }
        
        // Add days from the start of the first week
        var currentDate = firstWeek.start
        
        // Find the last day of the month
        guard let lastDayOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonth))!) else {
            return days
        }
        
        // Calculate how many weeks we need to display
        let weeksInMonth = calendar.component(.weekOfMonth, from: lastDayOfMonth)
        let totalDays = weeksInMonth * 7
        
        for _ in 0..<totalDays {
            if calendar.isDate(currentDate, equalTo: currentMonth, toGranularity: .month) {
                days.append(currentDate)
            } else {
                // Show days from previous/next month as dimmed
                days.append(currentDate)
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return days
    }
    
    private func hasEvents(on date: Date) -> Bool {
        events.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

// MARK: - Week Calendar View

struct WeekCalendarView: View {
    @Binding var selectedDate: Date
    let events: [CalendarEvent]
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: Layout.Spacing.md) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.captionL)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Week days
            HStack(spacing: 0) {
                ForEach(daysInWeek, id: \.self) { date in
                    WeekDayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        hasEvents: hasEvents(on: date)
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDate = date
                        }
                        HapticFeedbackManager.shared.lightImpact()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private var daysInWeek: [Date] {
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate))!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }
    
    private func hasEvents(on date: Date) -> Bool {
        events.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

// MARK: - Day Cell

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let hasEvents: Bool
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.bodyS)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(textColor)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? AppColors.accent : Color.clear)
                    )
                
                // Event indicator dot
                Circle()
                    .fill(hasEvents ? AppColors.accent : Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        } else if !isCurrentMonth {
            return AppColors.textTertiary
        } else {
            return AppColors.textPrimary
        }
    }
}

// MARK: - Week Day Cell

struct WeekDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.bodyS)
                    .fontWeight(isToday ? .bold : .medium)
                    .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(isSelected ? AppColors.accent : Color.clear)
                    )
                
                // Event indicator dot
                Circle()
                    .fill(hasEvents ? AppColors.accent : Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Calendar Event Card

struct CalendarEventCard: View {
    let event: CalendarEvent
    let showDate: Bool
    
    var body: some View {
        HStack(spacing: Layout.Spacing.md) {
            // Left accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(AppColors.accent)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                Text(event.title)
                    .font(.titleS)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                
                HStack(spacing: Layout.Spacing.sm) {
                    Text(event.courseCode)
                        .font(.captionL)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if showDate {
                        Text("- \(formattedDate)")
                            .font(.captionL)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Time
            Text(event.time ?? "")
                .font(.captionL)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.md)
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: event.date)
    }
}

// MARK: - Empty State View

struct CalendarEmptyStateView: View {
    var body: some View {
        VStack(spacing: Layout.Spacing.md) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundColor(AppColors.textTertiary)
            
            Text("No events")
                .font(.titleS)
                .foregroundColor(AppColors.textSecondary)
            
            Text("Events for this day will appear here")
                .font(.captionL)
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Layout.Spacing.xl)
    }
}

// MARK: - Motivational Message View

struct MotivationalMessageView: View {
    var body: some View {
        VStack(spacing: Layout.Spacing.sm) {
            Text("😊")
                .font(.system(size: 32))
            
            Text("More deadlines this week!")
                .font(.titleS)
                .fontWeight(.medium)
                .foregroundColor(AppColors.textPrimary)
            
            Text("Stay on track with Syllabus Sync.")
                .font(.captionL)
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Layout.Spacing.xl)
    }
}

// MARK: - Calendar Event Model

struct CalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let type: EventType
    let start: Date
    let end: Date?
    let location: String?
    let notes: String?
    let courseCode: String
    let isCompleted: Bool
    let isAllDay: Bool

    var date: Date { start }

    var time: String? {
        guard !isAllDay else { return nil }
        return CalendarEvent.timeFormatter.string(from: start)
    }

    enum EventType: String, Hashable {
        case assignment
        case quiz
        case midterm
        case final
        case lab
        case lecture
        case other

        init(from domain: EventItem.EventType) {
            switch domain {
            case .assignment: self = .assignment
            case .quiz: self = .quiz
            case .midterm: self = .midterm
            case .final: self = .final
            case .lab: self = .lab
            case .lecture: self = .lecture
            case .other: self = .other
            }
        }

        var displayName: String {
            switch self {
            case .assignment: return "Assignment"
            case .quiz: return "Quiz"
            case .midterm: return "Midterm"
            case .final: return "Final"
            case .lab: return "Lab"
            case .lecture: return "Lecture"
            case .other: return "Other"
            }
        }

        var color: Color {
            switch self {
            case .assignment: return .orange
            case .quiz: return .yellow
            case .midterm: return .pink
            case .final: return .red
            case .lab: return .green
            case .lecture: return .blue
            case .other: return AppColors.textSecondary
            }
        }

        var icon: String {
            switch self {
            case .assignment: return "doc.text"
            case .quiz: return "questionmark.circle"
            case .midterm: return "timer"
            case .final: return "graduationcap"
            case .lab: return "flask"
            case .lecture: return "person.fill"
            case .other: return "calendar"
            }
        }
    }

    init(item: EventItem) {
        id = item.id
        title = item.title
        type = EventType(from: item.type)
        start = item.start
        end = item.end
        location = item.location
        notes = item.notes
        courseCode = item.courseCode
        isCompleted = false
        isAllDay = item.allDay ?? false
    }

    static func make(from items: [EventItem]) -> [CalendarEvent] {
        items.map(CalendarEvent.init)
    }

    static let previewItems: [EventItem] = [
        EventItem(
            id: "cal-1",
            courseCode: "CS101",
            type: .lecture,
            title: "Lecture: Algorithms",
            start: Date(),
            end: nil,
            allDay: false,
            location: "Hall A",
            notes: "Week 2 lecture",
            recurrenceRule: nil,
            reminderMinutes: 30,
            confidence: nil
        ),
        EventItem(
            id: "cal-2",
            courseCode: "MATH152",
            type: .assignment,
            title: "Homework 3",
            start: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            end: nil,
            allDay: false,
            location: nil,
            notes: "Integration practice",
            recurrenceRule: nil,
            reminderMinutes: 60,
            confidence: nil
        )
    ]

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

// MARK: - Preview

#if DEBUG
struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        let previewStore = EventStore()
        _ = Task { await previewStore.autoApprove(events: CalendarEvent.previewItems) }

        return CalendarView()
            .environmentObject(AppNavigationManager())
            .environmentObject(ThemeManager())
            .environmentObject(previewStore)
    }
}
#endif
