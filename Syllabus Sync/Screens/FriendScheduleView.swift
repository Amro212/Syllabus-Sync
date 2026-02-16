//
//  FriendScheduleView.swift
//  Syllabus Sync
//
//  Read-only schedule viewer for a selected friend.
//  Shows events grouped by day, with week/month toggle.
//

import SwiftUI

struct FriendScheduleView: View {
    @ObservedObject var viewModel: SocialHubViewModel
    let friend: FriendDisplay
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date = Date()

    private var eventsForSelectedDate: [EventItem] {
        viewModel.friendEvents
            .filter { Calendar.current.isDate($0.start, inSameDayAs: selectedDate) }
            .sorted { $0.start < $1.start }
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
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
            // Month/Year label
            Text(monthYearString)
                .font(.lexend(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Layout.Spacing.lg)
                .padding(.top, Layout.Spacing.md)

            // Date strip
            dateStrip
                .padding(.top, Layout.Spacing.sm)

            Divider()
                .overlay(AppColors.surfaceSecondary)
                .padding(.horizontal, Layout.Spacing.lg)
                .padding(.top, Layout.Spacing.sm)

            // Events list
            ScrollView {
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
                    .padding(.top, Layout.Spacing.xxl)
                } else {
                    LazyVStack(spacing: Layout.Spacing.sm) {
                        ForEach(eventsForSelectedDate) { event in
                            friendEventCard(event)
                        }
                    }
                    .padding(.horizontal, Layout.Spacing.lg)
                    .padding(.top, Layout.Spacing.md)
                }

                Spacer(minLength: Layout.Spacing.massive)
            }
        }
    }

    // MARK: - Month Calendar Grid

    private var dateStrip: some View {
        let days = daysForMonth()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(days, id: \.self) { day in
                dayCell(day)
            }
        }
        .padding(.horizontal, Layout.Spacing.lg)
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let hasEvents = viewModel.friendEvents.contains { Calendar.current.isDate($0.start, inSameDayAs: date) }

        let dayNumber: String = {
            let formatter = DateFormatter()
            formatter.dateFormat = "d"
            return formatter.string(from: date)
        }()

        return Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                selectedDate = date
            }
            HapticFeedbackManager.shared.lightImpact()
        } label: {
            VStack(spacing: 4) {
                Text(dayNumber)
                    .font(.lexend(size: 14, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? .white : isToday ? AppColors.accent : AppColors.textPrimary)

                Circle()
                    .fill(hasEvents ? AppColors.accent : Color.clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                    .fill(isSelected
                        ? LinearGradient(
                            colors: [
                                Color(red: 0.886, green: 0.714, blue: 0.275),
                                Color(red: 0.816, green: 0.612, blue: 0.118)
                            ],
                            startPoint: .top, endPoint: .bottom)
                        : LinearGradient(colors: [Color.clear], startPoint: .top, endPoint: .bottom))
            )
        }
    }

    private func daysForMonth() -> [Date] {
        let calendar = Calendar.current
        guard let range = calendar.range(of: .day, in: .month, for: selectedDate),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: selectedDate)) else {
            return []
        }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: firstOfMonth) }
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
