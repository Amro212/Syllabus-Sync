//
//  FriendScheduleView.swift
//  Syllabus Sync
//
//  Enhanced read-only schedule viewer for a selected friend.
//  Features category filter chips, colored calendar dots, a collapsible
//  event accordion per category, and a per-day event list.
//

import SwiftUI

// MARK: - Friend Event Category Model

private struct FriendEventCategory: Identifiable, Equatable {
    let id: String
    let label: String
    let icon: String
    let color: Color
    let types: [EventItem.EventType]

    static let allCategories: [FriendEventCategory] = [
        FriendEventCategory(
            id: "assignments", label: "Assignments", icon: "doc.text",
            color: AppColors.eventAssignment, types: [.assignment]
        ),
        FriendEventCategory(
            id: "quizzes", label: "Quizzes", icon: "questionmark.circle",
            color: AppColors.eventQuiz, types: [.quiz]
        ),
        FriendEventCategory(
            id: "exams", label: "Exams", icon: "graduationcap",
            color: AppColors.eventExam, types: [.midterm, .final]
        ),
        FriendEventCategory(
            id: "labs", label: "Labs", icon: "eyedropper",
            color: AppColors.eventLab, types: [.lab]
        ),
        FriendEventCategory(
            id: "lectures", label: "Lectures", icon: "book.closed",
            color: AppColors.eventLecture, types: [.lecture]
        ),
        FriendEventCategory(
            id: "other", label: "Other", icon: "ellipsis.circle",
            color: AppColors.accent, types: [.tutorial, .officeHours, .importantDate, .other]
        ),
    ]
}

// MARK: - Friend Schedule View

struct FriendScheduleView: View {
    @ObservedObject var viewModel: SocialHubViewModel
    let friend: FriendDisplay
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var viewMode: CalendarViewMode = .week
    /// nil = "All" (no category filter)
    @State private var selectedCategoryId: String? = nil
    @State private var isCategoryExpanded: Bool = true

    // MARK: - Derived State

    /// Categories that actually have at least one event (in order).
    private var availableCategories: [FriendEventCategory] {
        FriendEventCategory.allCategories.filter { category in
            viewModel.friendEvents.contains { category.types.contains($0.type) }
        }
    }

    private var selectedCategory: FriendEventCategory? {
        guard let id = selectedCategoryId else { return nil }
        return availableCategories.first { $0.id == id }
    }

    /// Events restricted to the selected category (or all events if nil).
    private var filteredEvents: [EventItem] {
        guard let cat = selectedCategory else { return viewModel.friendEvents }
        return viewModel.friendEvents.filter { cat.types.contains($0.type) }
    }

    /// CalendarEvent wrappers used by the calendar grid components.
    private var filteredCalendarEvents: [CalendarEvent] {
        CalendarEvent.make(from: filteredEvents)
    }

    /// All events in the selected category, sorted by date — drives the accordion.
    private var categoryEvents: [EventItem] {
        filteredEvents
            .filter { !$0.needsDate }
            .sorted { $0.start < $1.start }
    }

    /// Events on the tapped date, from the currently filtered set.
    private var eventsForSelectedDate: [EventItem] {
        filteredEvents
            .filter { Calendar.current.isDate($0.start, inSameDayAs: selectedDate) }
            .sorted { $0.start < $1.start }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.vertical, Layout.Spacing.md)

                if viewModel.isLoadingSchedule {
                    loadingState
                } else if viewModel.friendEvents.isEmpty {
                    emptyState
                } else {
                    scheduleContent
                }
            }
        }
        .onAppear {
            currentMonth = selectedDate
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(AppColors.surfaceSecondary)
                    .frame(width: 44, height: 44)
                Text(String((friend.displayName ?? friend.username).prefix(1)).uppercased())
                    .font(.lexend(.headline, weight: .bold))
                    .foregroundStyle(AppColors.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(friend.displayName ?? friend.username)'s Schedule")
                    .font(.lexend(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                Text("@\(friend.username)")
                    .font(.lexend(size: 12, weight: .regular))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Button {
                HapticFeedbackManager.shared.lightImpact()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, Layout.Spacing.lg)
    }

    // MARK: - Schedule Content

    private var scheduleContent: some View {
        ScrollView {
            VStack(spacing: Layout.Spacing.lg) {
                // Calendar header: month label + view mode toggle
                calendarHeader
                    .padding(.horizontal, Layout.Spacing.lg)
                    .padding(.top, Layout.Spacing.md)

                // Category filter chips
                categoryChips

                // Calendar grid — wrapped in a distinct bordered card
                calendarCard
                    .padding(.horizontal, Layout.Spacing.lg)

                // Event accordion — always visible ("All Events" when no category selected)
                categoryAccordion
                    .padding(.horizontal, Layout.Spacing.lg)

                // Day events section
                dayEventsSection
                    .padding(.horizontal, Layout.Spacing.lg)
                    .padding(.bottom, 100)
            }
        }
        .scrollIndicators(.hidden)
    }

    private var calendarCard: some View {
        VStack(spacing: 0) {
            if viewMode == .week {
                WeekStripView(
                    selectedDate: $selectedDate,
                    currentMonth: $currentMonth,
                    events: filteredCalendarEvents,
                    highlightColor: selectedCategory?.color
                )
            } else {
                MonthCalendarView(
                    currentMonth: $currentMonth,
                    selectedDate: $selectedDate,
                    events: filteredCalendarEvents,
                    highlightColor: selectedCategory?.color
                )
            }
        }
        .padding(.vertical, Layout.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                        .strokeBorder(AppColors.surfaceSecondary, lineWidth: 1)
                )
        )
    }

    private var calendarHeader: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
            Text(monthYearString)
                .font(.lexend(.title2, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)

            CalendarViewModeToggle(selectedMode: $viewMode)
        }
    }

    // MARK: - Category Chips

    private var categoryChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Layout.Spacing.sm) {
                // "All" chip
                CategoryChip(
                    label: "All",
                    icon: "square.grid.2x2",
                    color: AppColors.textSecondary,
                    isSelected: selectedCategoryId == nil
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedCategoryId = nil
                        isCategoryExpanded = true
                    }
                    HapticFeedbackManager.shared.lightImpact()
                }

                ForEach(availableCategories) { category in
                    CategoryChip(
                        label: category.label,
                        icon: category.icon,
                        color: category.color,
                        isSelected: selectedCategoryId == category.id
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            if selectedCategoryId == category.id {
                                selectedCategoryId = nil
                            } else {
                                selectedCategoryId = category.id
                                isCategoryExpanded = true
                            }
                        }
                        HapticFeedbackManager.shared.lightImpact()
                    }
                }
            }
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.vertical, Layout.Spacing.xs)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Category Accordion

    private var categoryAccordion: some View {
        let accordionLabel = selectedCategory?.label ?? "All Events"
        let accordionIcon = selectedCategory?.icon ?? "square.grid.2x2"
        let accordionColor = selectedCategory?.color ?? AppColors.textSecondary

        return VStack(spacing: 2) {
            // Accordion header
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isCategoryExpanded.toggle()
                }
                HapticFeedbackManager.shared.lightImpact()
            } label: {
                HStack(spacing: Layout.Spacing.sm) {
                    Image(systemName: accordionIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accordionColor)

                    Text(accordionLabel)
                        .font(.lexend(.subheadline, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("(\(categoryEvents.count))")
                        .font(.lexend(.subheadline, weight: .regular))
                        .foregroundStyle(AppColors.textSecondary)

                    Spacer()

                    Image(systemName: isCategoryExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .animation(.easeInOut(duration: 0.2), value: isCategoryExpanded)
                }
                .padding(Layout.Spacing.md)
                .background(AppColors.surface)
                .clipShape(.rect(cornerRadius: Layout.CornerRadius.lg))
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityLabel("Toggle \(accordionLabel) list")

            // Accordion body — opacity only, no move, strictly clipped
            if isCategoryExpanded {
                if !categoryEvents.isEmpty {
                    VStack(spacing: 1) {
                        ForEach(categoryEvents) { event in
                            CategoryEventRow(
                                event: event,
                                color: selectedCategory?.color ?? eventColor(for: event.type)
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = event.start
                                    currentMonth = event.start
                                }
                                HapticFeedbackManager.shared.lightImpact()
                            }
                        }
                    }
                    .background(AppColors.surface.opacity(0.5))
                    .clipShape(.rect(cornerRadius: Layout.CornerRadius.lg))
                    .transition(.opacity)
                } else {
                    HStack {
                        Spacer()
                        Text("No upcoming events")
                            .font(.lexend(.caption, weight: .regular))
                            .foregroundStyle(AppColors.textTertiary)
                        Spacer()
                    }
                    .padding(Layout.Spacing.md)
                    .background(AppColors.surface.opacity(0.5))
                    .clipShape(.rect(cornerRadius: Layout.CornerRadius.lg))
                    .transition(.opacity)
                }
            }
        }
        .clipped()
    }


    // MARK: - Day Events Section

    private var dayEventsSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            // Section label
            HStack {
                Text(selectedDayLabel)
                    .font(.lexend(.subheadline, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
            }
            .padding(.top, Layout.Spacing.xs)

            if eventsForSelectedDate.isEmpty {
                VStack(spacing: Layout.Spacing.sm) {
                    Image(systemName: "calendar")
                        .font(.system(size: 28))
                        .foregroundStyle(AppColors.textTertiary)

                    Text(selectedCategory == nil ? "No events on this day" : "No \(selectedCategory!.label.lowercased()) on this day")
                        .font(.lexend(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Layout.Spacing.xl)
            } else {
                ForEach(eventsForSelectedDate) { event in
                    FriendEventCard(
                        event: event,
                        color: eventColor(for: event.type)
                    )
                }
            }
        }
    }

    private var selectedDayLabel: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: selectedDate)
        }
    }

    // MARK: - Loading / Empty States

    private var loadingState: some View {
        VStack(spacing: Layout.Spacing.lg) {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                .scaleEffect(1.2)
            Text("Loading schedule...")
                .font(.lexend(size: 14, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Layout.Spacing.lg) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(AppColors.textTertiary)

            Text("No schedule available")
                .font(.lexend(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)

            Text("This friend hasn't added any events yet.")
                .font(.lexend(size: 14, weight: .regular))
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, Layout.Spacing.xl)
    }

    // MARK: - Helpers

    private func eventColor(for type: EventItem.EventType) -> Color {
        switch type {
        case .assignment:        return AppColors.eventAssignment
        case .quiz:              return AppColors.eventQuiz
        case .midterm, .final:  return AppColors.eventExam
        case .lab:               return AppColors.eventLab
        case .lecture:           return AppColors.eventLecture
        default:                 return AppColors.accent
        }
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let label: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.lexend(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? (label == "All" ? AppColors.background : color) : AppColors.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule()
                        .fill(label == "All" ? AppColors.textSecondary : color.opacity(0.2))
                        .overlay(
                            Capsule()
                                .strokeBorder(label == "All" ? AppColors.textSecondary : color, lineWidth: 1.5)
                        )
                } else {
                    Capsule()
                        .fill(AppColors.surfaceSecondary)
                }
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Category Event Row (Accordion Item)

private struct CategoryEventRow: View {
    let event: EventItem
    let color: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Layout.Spacing.md) {
                // Color bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 3, height: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.lexend(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if !event.courseCode.isEmpty {
                            Text(event.courseCode)
                                .font(.lexend(size: 11, weight: .medium))
                                .foregroundStyle(AppColors.accent)
                        }
                        Text(rowDateString(for: event.start))
                            .font(.lexend(size: 11, weight: .regular))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, Layout.Spacing.md)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(event.title), \(rowDateString(for: event.start))")
        .accessibilityHint("Tap to jump to this date")
    }

    private func rowDateString(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Friend Event Card (Day Events Section)

private struct FriendEventCard: View {
    let event: EventItem
    let color: Color

    var body: some View {
        HStack(spacing: Layout.Spacing.md) {
            // Color bar
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.lexend(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: Layout.Spacing.sm) {
                    if !event.courseCode.isEmpty {
                        Text(event.courseCode)
                            .font(.lexend(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.accent.opacity(0.15))
                            )
                    }

                    Text(timeString(for: event))
                        .font(.lexend(size: 12, weight: .regular))
                        .foregroundStyle(AppColors.textSecondary)
                }

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                        Text(location)
                            .font(.lexend(size: 12, weight: .regular))
                    }
                    .foregroundStyle(AppColors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(Layout.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                        .strokeBorder(color.opacity(0.25), lineWidth: 1)
                )
        )
        .accessibilityElement(children: .combine)
    }

    private func timeString(for event: EventItem) -> String {
        if event.needsDate { return "Date TBD" }
        if event.allDay == true { return "All Day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var str = formatter.string(from: event.start)
        if let end = event.end {
            str += " – \(formatter.string(from: end))"
        }
        return str
    }
}
