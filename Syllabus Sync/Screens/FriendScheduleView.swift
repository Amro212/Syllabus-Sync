//
//  FriendScheduleView.swift
//  Syllabus Sync
//
//  Read-only schedule viewer for a selected friend.
//  Reuses the same calendar components (DayCell, MonthCalendarView,
//  WeekStripView, CalendarViewModeToggle) for visual consistency.
//

import SwiftUI

struct FriendScheduleView: View {
    @ObservedObject var viewModel: SocialHubViewModel
    let friend: FriendDisplay
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date = Date()
    @State private var currentMonth: Date = Date()
    @State private var viewMode: CalendarViewMode = .week

    /// Wrap friend events into CalendarEvent so we can share the same calendar components.
    private var calendarEvents: [CalendarEvent] {
        CalendarEvent.make(from: viewModel.friendEvents)
    }

    private var eventsForSelectedDate: [EventItem] {
        viewModel.friendEvents
            .filter { Calendar.current.isDate($0.start, inSameDayAs: selectedDate) }
            .sorted { $0.start < $1.start }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                header
                    .padding(.top, Layout.Spacing.md)

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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(friend.displayName ?? friend.username)'s Schedule")
                    .font(.lexend(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text("@\(friend.username)")
                    .font(.lexend(size: 13, weight: .regular))
                    .foregroundColor(AppColors.textSecondary)
            }

            Spacer()

            Button {
                HapticFeedbackManager.shared.lightImpact()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.lexend(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, Layout.Spacing.lg)
    }

    // MARK: - Schedule Content

    private var scheduleContent: some View {
        VStack(spacing: 0) {
            // Month title + View mode toggle (same as CalendarView)
            VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                Text(monthYearString)
                    .font(.lexend(.title2, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.leading, Layout.Spacing.sm)

                CalendarViewModeToggle(selectedMode: $viewMode)
            }
            .padding(.horizontal, Layout.Spacing.md)
            .padding(.top, Layout.Spacing.md)
            .padding(.bottom, Layout.Spacing.sm)

            // Calendar Grid (reuse same components)
            ScrollView {
                VStack(spacing: Layout.Spacing.md) {
                    if viewMode == .week {
                        WeekStripView(
                            selectedDate: $selectedDate,
                            currentMonth: $currentMonth,
                            events: calendarEvents
                        )
                    } else {
                        MonthCalendarView(
                            currentMonth: $currentMonth,
                            selectedDate: $selectedDate,
                            events: calendarEvents
                        )
                    }

                    // Separator
                    Divider()
                        .overlay(AppColors.surfaceSecondary)
                        .padding(.horizontal, Layout.Spacing.lg)

                    // Events list
                    VStack(spacing: Layout.Spacing.md) {
                        if eventsForSelectedDate.isEmpty {
                            VStack(spacing: Layout.Spacing.md) {
                                Image(systemName: "calendar")
                                    .font(.lexend(size: 28, weight: .regular))
                                    .foregroundColor(AppColors.textTertiary)

                                Text("No events on this day")
                                    .font(.lexend(size: 14, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, Layout.Spacing.xl)
                        } else {
                            ForEach(eventsForSelectedDate) { event in
                                friendEventCard(event)
                            }
                        }
                    }
                    .padding(.horizontal, Layout.Spacing.md)
                    .padding(.bottom, 100)
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Event Card

    private func friendEventCard(_ event: EventItem) -> some View {
        HStack(spacing: Layout.Spacing.md) {
            // Time bar
            RoundedRectangle(cornerRadius: 2)
                .fill(eventColor(for: event.type))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.lexend(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)

                HStack(spacing: Layout.Spacing.sm) {
                    if !event.courseCode.isEmpty {
                        Text(event.courseCode)
                            .font(.lexend(size: 12, weight: .medium))
                            .foregroundColor(AppColors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(AppColors.accent.opacity(0.15))
                            )
                    }

                    Text(timeString(for: event))
                        .font(.lexend(size: 12, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                }

                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.lexend(size: 11, weight: .regular))
                        Text(location)
                            .font(.lexend(size: 12, weight: .regular))
                    }
                    .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()
        }
        .padding(Layout.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .fill(AppColors.surface)
        )
    }

    // MARK: - Helpers

    private func timeString(for event: EventItem) -> String {
        if event.allDay == true { return "All Day" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var str = formatter.string(from: event.start)
        if let end = event.end {
            str += " - \(formatter.string(from: end))"
        }
        return str
    }

    private func eventColor(for type: EventItem.EventType) -> Color {
        switch type {
        case .assignment: return AppColors.eventAssignment
        case .quiz:       return AppColors.eventQuiz
        case .midterm, .final: return AppColors.eventExam
        case .lab:        return AppColors.eventLab
        case .lecture:    return AppColors.eventLecture
        default:          return AppColors.accent
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
                .foregroundColor(AppColors.textSecondary)
            Spacer()
        }
    }

    private var emptyState: some View {
        VStack(spacing: Layout.Spacing.lg) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.lexend(size: 48, weight: .regular))
                .foregroundColor(AppColors.textTertiary)

            Text("No schedule available")
                .font(.lexend(size: 18, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)

            Text("This friend hasn't added any events yet.")
                .font(.lexend(size: 14, weight: .regular))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, Layout.Spacing.xl)
    }
}
