//
//  CalendarView.swift
//  Syllabus Sync
//
//  Created by Cursor on 2025-09-06.
//  Redesigned for Gold/Glass wireframe on 2026-01-14.
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
    @State private var viewMode: CalendarViewMode = .week // Default to week as shown in wireframe

    private var events: [CalendarEvent] {
        CalendarEvent.make(from: eventStore.events)
    }

    private var eventsForSelectedDate: [CalendarEvent] {
        events.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    var body: some View {
        GeometryReader { _ in
            ZStack(alignment: .top) {
                // Background
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Section
                    VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                        // Month Title
                        Text(monthYearString)
                            .font(.lexend(.title2, weight: .bold)) // 28px in wireframe ~ title2/title
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.leading, Layout.Spacing.sm)

                        // Toggle
                        CalendarViewModeToggle(selectedMode: $viewMode)
                    }
                    .padding(.horizontal, Layout.Spacing.md)
                    .padding(.top, Layout.Spacing.md)
                    .padding(.bottom, Layout.Spacing.sm)
                    .background(AppColors.background) // Sticky header background
                    
                    // Shared Scrollable Content (Grid + Events)
                    ScrollView {
                        VStack(spacing: Layout.Spacing.md) {
                            // Calendar Grid (Week or Month)
                            if viewMode == .week {
                                WeekStripView(
                                    selectedDate: $selectedDate,
                                    currentMonth: $currentMonth,
                                    events: events
                                )
                            } else {
                                MonthCalendarView(
                                    currentMonth: $currentMonth,
                                    selectedDate: $selectedDate,
                                    events: events
                                )
                            }
                            
                            // Separator Divider
                            Divider()
                                .overlay(AppColors.surfaceSecondary)
                                .padding(.horizontal, Layout.Spacing.lg)
                            
                            // Events List
                            VStack(spacing: Layout.Spacing.md) {
                                if eventsForSelectedDate.isEmpty {
                                    CalendarEmptyStateView()
                                        .padding(.top, Layout.Spacing.xl)
                                } else {
                                    ForEach(eventsForSelectedDate) { event in
                                        GlassEventCard(event: event)
                                    }
                                }
                                
                                // Motivational message (bottom filler)
                                if !eventsForSelectedDate.isEmpty {
                                    MotivationalMessageView()
                                        .padding(.top, Layout.Spacing.xl)
                                        .opacity(0.6)
                                }
                            }
                            .padding(.horizontal, Layout.Spacing.md)
                            .padding(.bottom, 40)
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .onAppear {
            currentMonth = selectedDate
        }
    }
}

// MARK: - View Mode Toggle (Segmented Control)

struct CalendarViewModeToggle: View {
    @Binding var selectedMode: CalendarViewMode
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                let isSelected = selectedMode == mode
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedMode = mode
                    }
                    HapticFeedbackManager.shared.lightImpact()
                }) {
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.surface) // White or Dark Surface
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                .matchedGeometryEffect(id: "ToggleSelection", in: namespace)
                        }
                        
                        Text(mode.rawValue)
                            .font(.lexend(.subheadline, weight: .medium))
                            .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary)
                    }
                    .frame(height: 32)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(4)
        .background(AppColors.surfaceSecondary) // Gray background
        .cornerRadius(12)
        .frame(height: 40)
    }
    
    @Namespace private var namespace
}

// MARK: - Week Strip View

struct WeekStripView: View {
    @Binding var selectedDate: Date
    @Binding var currentMonth: Date
    let events: [CalendarEvent]
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xs) {
            // Weekday Headers (S M T W T F S)
            HStack(spacing: 0) {
                ForEach(daysInWeek, id: \.self) { date in
                    Text(weekdaySymbol(for: date))
                        .font(.lexend(.caption, weight: .bold)) // 12px bold
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days Row
            HStack(spacing: 0) {
                ForEach(daysInWeek, id: \.self) { date in
                    DayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        hasEvents: hasEvents(on: date)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedDate = date
                            currentMonth = date // Update month context if crossing boundary
                        }
                        HapticFeedbackManager.shared.lightImpact()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, Layout.Spacing.sm)
    }
    
    private var daysInWeek: [Date] {
        // Calculate week surrounding selectedDate
        // Start from Sunday (or user locale start)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekInterval.start) }
    }
    
    private func weekdaySymbol(for date: Date) -> String {
        let weekday = calendar.component(.weekday, from: date)
        return calendar.shortWeekdaySymbols[weekday - 1].prefix(1).uppercased()
    }
    
    private func hasEvents(on date: Date) -> Bool {
        events.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

// MARK: - Month Calendar View (Retained Logic, Updated Style)

struct MonthCalendarView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    let events: [CalendarEvent]
    
    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xs) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(.lexend(.caption, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(daysInMonth, id: \.self) { date in
                    DayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        hasEvents: hasEvents(on: date),
                        isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedDate = date
                        }
                        HapticFeedbackManager.shared.lightImpact()
                    }
                }
            }
            // Simple Month Navigation
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                   Image(systemName: "chevron.left").padding()
                }
                Spacer()
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right").padding()
                }
            }
            .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, Layout.Spacing.sm)
    }
    
    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
        }
    }
    
    private var daysInMonth: [Date] {
        var days: [Date] = []
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let lastDayOfMonth = calendar.date(byAdding: .day, value: -1, to: monthInterval.end),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: lastDayOfMonth) else { return days }
        
        var currentDate = firstWeek.start

        // Render only the needed visible weeks for the active month.
        while currentDate < lastWeek.end {
            days.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        return days
    }
    
    private func hasEvents(on date: Date) -> Bool {
        events.contains { calendar.isDate($0.date, inSameDayAs: date) }
    }
}

// MARK: - Day Cell (Redesigned)

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    var isCurrentMonth: Bool = true
    let action: () -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Selection Background (Glow + Gradient)
                if isSelected {
                    Circle() // Glow
                        .fill(AppColors.accent.opacity(0.3))
                        .frame(width: 44, height: 44)
                        .blur(radius: 8)
                    
                    Circle() // Main Gradient
                        .fill(AppColors.goldGradient)
                        .frame(width: 44, height: 44)
                        .shadow(color: AppColors.accent.opacity(0.4), radius: 4, x: 0, y: 0)
                }
                
                VStack(spacing: 4) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.lexend(.body, weight: isToday ? .bold : .medium))
                        .foregroundColor(textColor)
                    
                    // Dot (only if not selected, as selected state is distinct enough, or maybe change dot color)
                    if hasEvents && !isSelected {
                        Circle()
                            .fill(AppColors.accent)
                            .frame(width: 4, height: 4)
                            .shadow(color: AppColors.accent.opacity(0.8), radius: 2)
                    } else if hasEvents && isSelected {
                        Circle() // White dot for contrast on gold
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(height: 50)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isCurrentMonth ? 1.0 : 0.3)
    }
    
    private var textColor: Color {
        if isSelected {
            return .white // White text on Gold
        } else if isToday {
            return AppColors.accent // Gold text for today
        } else {
            return AppColors.textPrimary // Default text
        }
    }
}

// MARK: - Glass Event Card (New!)

struct GlassEventCard: View {
    let event: CalendarEvent
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: Layout.Spacing.sm) {
            // Header: Dot + Title + Date Tag
            HStack(alignment: .top, spacing: Layout.Spacing.md) {
                // Vertical Bar / Dot
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.goldGradient.opacity(0.7))
                    .frame(width: 4, height: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                         Text(event.title)
                            .font(.lexend(.headline, weight: .semibold)) // 17px semibold
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(eventDisplayDate)
                            .font(.lexend(size: 11, weight: .medium)) // 11px medium
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(AppColors.surfaceSecondary)
                            .foregroundColor(AppColors.textSecondary)
                            .clipShape(Capsule())
                    }
                    
                    HStack {
                        Text(event.courseCode)
                            .font(.lexend(size: 13, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                        
                        Spacer()
                        
                        if let time = event.time {
                            Text(time)
                                .font(.lexend(size: 13, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
            
            // Footer: Time Remaining Progress
            if let time = timeRemaining {
               VStack(spacing: 6) {
                   HStack {
                       Text("Time Remaining")
                           .font(.lexend(size: 11, weight: .medium))
                           .foregroundColor(AppColors.textTertiary)
                       Spacer()
                       Text(timeRemainingString(time))
                           .font(.lexend(size: 11, weight: .medium))
                           .foregroundColor(AppColors.textSecondary)
                   }
                   
                   // Progress Bar
                   GeometryReader { geo in
                       ZStack(alignment: .leading) {
                           Capsule()
                               .fill(AppColors.surfaceSecondary) // Track
                           
                           Capsule()
                               .fill(AppColors.goldProgressGradient) // Fill
                               .frame(width: calculateProgressWidth(width: geo.size.width, time: time))
                               .opacity(progressOpacity(time: time))
                       }
                   }
                   .frame(height: 6)
               }
               .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            // Glass Effect
            RoundedRectangle(cornerRadius: 20)
                .fill(cardBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColors.accent.opacity(0.15), lineWidth: 1) // Thin gold border
                )
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4) // Glass Shadow
        )
    }
    
    // Helpers
    
    private var cardBackgroundColor: Color {
        // Dark mode: dim glass, Light mode: semi-transparent surface
        colorScheme == .dark ? Color(hex: "2a261a").opacity(0.6) : Color.white.opacity(0.9)
    }
    
    private var eventDisplayDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(event.date) {
            return "Today"
        } else {
            formatter.dateFormat = "MMM d"
            return formatter.string(from: event.date)
        }
    }
    
    /// Returns (days, hours) remaining until the event.
    /// Days is calculated using calendar day boundaries (midnight-to-midnight).
    /// Hours is the remaining hours within the final day.
    private var timeRemaining: (days: Int, hours: Int)? {
        let calendar = Calendar.current
        let now = Date()
        
        // Strip time to compare calendar days
        guard let startOfToday = calendar.startOfDay(for: now) as Date?,
              let startOfEventDay = calendar.startOfDay(for: event.date) as Date? else {
            return nil
        }
        
        // Calendar days difference (midnight to midnight)
        let dayComponents = calendar.dateComponents([.day], from: startOfToday, to: startOfEventDay)
        guard let calendarDays = dayComponents.day else { return nil }
        
        // Hours remaining from now until event time
        let hourComponents = calendar.dateComponents([.hour], from: now, to: event.date)
        let totalHours = hourComponents.hour ?? 0
        
        // If event is in the past
        if calendarDays < 0 || (calendarDays == 0 && totalHours < 0) {
            return (days: calendarDays, hours: totalHours)
        }
        
        // Hours remaining within the final partial day
        let hoursInFinalDay = max(0, totalHours - (calendarDays * 24))
        
        return (days: calendarDays, hours: hoursInFinalDay)
    }
    
    private func timeRemainingString(_ time: (days: Int, hours: Int)) -> String {
        let days = time.days
        let hours = time.hours
        
        if days < 0 || (days == 0 && hours < 0) {
            return "Overdue"
        }
        
        if days == 0 {
            // Due today - show hours
            if hours <= 0 {
                return "Due now"
            } else if hours == 1 {
                return "1 hour"
            } else {
                return "\(hours) hrs"
            }
        } else if days == 1 {
            // Due tomorrow
            return "1 day"
        } else {
            return "\(days) days"
        }
    }
    
    private func calculateProgressWidth(width: CGFloat, time: (days: Int, hours: Int)) -> CGFloat {
        // Logic: 0 days = 100% (full urgency), 7 days = ~10% (minimal urgency)
        // Inverted: Closer deadline = More filled progress bar
        let maxDays = 7.0
        let totalHoursRemaining = Double(time.days * 24 + time.hours)
        let maxHours = maxDays * 24.0
        
        // Clamp to valid range
        let clampedHours = max(0, min(maxHours, totalHoursRemaining))
        let urgency = 1.0 - (clampedHours / maxHours)
        
        // If overdue, full width
        if time.days < 0 || (time.days == 0 && time.hours < 0) {
            return width
        }
        
        return width * CGFloat(max(0.1, urgency)) // at least 10% visible
    }
    
    private func progressOpacity(time: (days: Int, hours: Int)) -> Double {
        // Wireframe shows opacity fades for further items
        // 0 days -> 1.0 opacity, 7 days -> 0.4 opacity
        let maxDays = 7.0
        let totalHoursRemaining = Double(time.days * 24 + time.hours)
        let maxHours = maxDays * 24.0
        
        let clampedHours = max(0, min(maxHours, totalHoursRemaining))
        let urgency = 1.0 - (clampedHours / maxHours)
        
        return max(0.4, urgency)
    }
}

// MARK: - Legacy / Helper Components (Preserved or Stubs)

struct CalendarEmptyStateView: View {
    var body: some View {
        VStack(spacing: Layout.Spacing.md) {
            Image(systemName: "calendar")
                .font(.lexend(size: 40, weight: .regular))
                .foregroundColor(AppColors.textTertiary)
            
            Text("You're up to date!")
                .font(.lexend(.title3, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Enjoy your week.")
                .font(.lexend(.caption, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
        }
        .opacity(0.6)
        .frame(maxWidth: .infinity)
        .padding(Layout.Spacing.xl)
    }
}

// Preserving Model (Normally would be in separate file)
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
        case assignment, quiz, midterm, final, lab, lecture, other

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
    
    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}

// MARK: - Motivational Message View

struct MotivationalMessageView: View {
    var body: some View {
        VStack(spacing: Layout.Spacing.sm) {
            Text("😊")
                .font(.lexend(size: 32, weight: .regular))
            
            Text("More deadlines this week!")
                .font(.lexend(size: 16, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Stay on track with Syllabus Sync.")
                .font(.lexend(size: 13, weight: .regular))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(Layout.Spacing.xl)
    }
}
