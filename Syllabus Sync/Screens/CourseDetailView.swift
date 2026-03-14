//
//  CourseDetailView.swift
//  Syllabus Sync
//
//  Displays a real Course with events from EventStore and
//  a persistent grading breakdown from GradingRepository.
//  Reworked with modern SwiftUI best-practices.
//

import SwiftUI

// MARK: - Main View

struct CourseDetailView: View {
    let course: Course
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var gradingRepository: GradingRepository
    @EnvironmentObject var courseRepository: CourseRepository
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab: CourseTab = .all
    @State private var showingGradingEdit = false
    @State private var isEditing = false
    @State private var editTitle = ""
    @State private var editInstructor = ""
    @State private var editColorHex = ""
    @State private var editEmail = "" // TODO: Persist when instructorEmail field added to Course model

    private let availableColors: [(name: String, hex: String)] = [
        ("Blue",   "#3478F6"),
        ("Green",  "#34C759"),
        ("Purple", "#AF52DE"),
        ("Orange", "#FF9500"),
        ("Red",    "#FF3B30"),
        ("Pink",   "#FF2D55"),
        ("Teal",   "#5AC8FA"),
        ("Indigo", "#5856D6")
    ]

    // MARK: - Tab enum

    enum CourseTab: String, CaseIterable {
        case all = "All"
        case assignments = "Assignments"
        case exams = "Exams"
        case lectures = "Lectures"
        case labs = "Labs"

        var icon: String {
            switch self {
            case .all:         return "list.bullet"
            case .assignments: return "doc.text"
            case .exams:       return "graduationcap"
            case .lectures:    return "person.fill"
            case .labs:        return "flask"
            }
        }

        func matches(_ type: EventItem.EventType) -> Bool {
            switch self {
            case .all:         return true
            case .assignments: return type == .assignment
            case .exams:       return type == .midterm || type == .final || type == .quiz
            case .lectures:    return type == .lecture || type == .tutorial
            case .labs:        return type == .lab
            }
        }
    }

    // MARK: - Derived data

    private var courseEvents: [EventItem] {
        eventStore.events.filter { $0.courseCode == course.code }
    }

    private var filteredEvents: [EventItem] {
        courseEvents
            .filter { selectedTab.matches($0.type) }
            .sorted { $0.start < $1.start }
    }

    private var gradingEntries: [GradingSchemeEntry] {
        gradingRepository.gradingByCourse[course.id] ?? []
    }

    private var liveCourse: Course {
        courseRepository.courses.first(where: { $0.id == course.id }) ?? course
    }

    private var courseColor: Color {
        if let hex = liveCourse.colorHex {
            return Color(hex: hex)
        }
        return AppColors.accent
    }

    private var editingColor: Color {
        if isEditing, !editColorHex.isEmpty {
            return Color(hex: editColorHex)
        }
        return courseColor
    }

    private var upcomingCount: Int {
        courseEvents.filter { !$0.needsDate && $0.start >= Date() }.count
    }

    private var nextEventDate: String? {
        guard let next = courseEvents
            .filter({ !$0.needsDate && $0.start >= Date() })
            .sorted(by: { $0.start < $1.start })
            .first else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: next.start, relativeTo: Date())
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                courseHeader
                quickStatsRow
                gradingSection
                tabBar
                eventsList
            }
        }
        .scrollIndicators(.hidden)
        .background(AppColors.background)
        .navigationBarHidden(true)
        .sheet(isPresented: $showingGradingEdit) {
            GradingEditView(courseId: course.id, entries: gradingEntries)
        }
        .task {
            _ = await gradingRepository.fetch(forCourseId: course.id)
        }
    }

    // MARK: - Header

    private var courseHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Navigation row
            HStack(spacing: Layout.Spacing.sm) {
                Button {
                    if isEditing { cancelEditing() }
                    dismiss()
                } label: {
                    HStack(spacing: Layout.Spacing.xs) {
                        Image(systemName: "chevron.left")
                            .font(.lexend(size: 14, weight: .semibold))
                        Text("Back")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(AppColors.textPrimary)
                }

                Spacer()

                if isEditing {
                    Button {
                        cancelEditing()
                        HapticFeedbackManager.shared.lightImpact()
                    } label: {
                        Text("Cancel")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Button {
                        saveEditing()
                        HapticFeedbackManager.shared.mediumImpact()
                    } label: {
                        Text("Save")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, Layout.Spacing.md)
                            .padding(.vertical, Layout.Spacing.xs + 2)
                            .background(AppColors.accent)
                            .clipShape(.rect(cornerRadius: Layout.CornerRadius.md))
                    }
                } else {
                    Button {
                        startEditing()
                        HapticFeedbackManager.shared.lightImpact()
                    } label: {
                        HStack(spacing: Layout.Spacing.xs) {
                            Image(systemName: "pencil")
                                .font(.lexend(size: 13, weight: .medium))
                            Text("Edit")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(AppColors.accent)
                    }
                }
            }
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.vertical, Layout.Spacing.sm)

            // Thin accent color divider
            editingColor
                .frame(height: 6)
                .clipShape(.rect(cornerRadius: 3))
                .padding(.horizontal, Layout.Spacing.lg)
                .padding(.bottom, Layout.Spacing.md)
                .animation(.easeInOut(duration: 0.2), value: editColorHex)

            // Course info section
            VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                // Course code badge
                Text(liveCourse.code)
                    .font(.captionL)
                    .fontWeight(.bold)
                    .foregroundStyle(editingColor)
                    .padding(.horizontal, Layout.Spacing.sm)
                    .padding(.vertical, Layout.Spacing.xs)
                    .background(editingColor.opacity(0.12))
                    .clipShape(.rect(cornerRadius: Layout.CornerRadius.sm))

                // Course title
                if isEditing {
                    TextField("Course Name", text: $editTitle)
                        .font(.titleL)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textPrimary)
                        .textFieldStyle(.plain)
                } else {
                    Text(liveCourse.title ?? liveCourse.code)
                        .font(.titleL)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Instructor
                HStack(spacing: Layout.Spacing.xs) {
                    Image(systemName: "person.circle.fill")
                        .font(.lexend(size: 14, weight: .regular))
                        .foregroundStyle(AppColors.textTertiary)
                    if isEditing {
                        TextField("Instructor Name", text: $editInstructor)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .textFieldStyle(.plain)
                    } else {
                        let hasInstructor = liveCourse.instructor?.isEmpty == false
                        Text(hasInstructor ? liveCourse.instructor! : "No instructor")
                            .font(.subheadline)
                            .foregroundStyle(hasInstructor ? AppColors.textSecondary : AppColors.textTertiary)
                    }
                }

                // Instructor email placeholder
                // TODO: Add instructorEmail to Course model + Supabase schema
                HStack(spacing: Layout.Spacing.xs) {
                    Image(systemName: "envelope")
                        .font(.lexend(size: 14, weight: .regular))
                        .foregroundStyle(AppColors.textTertiary)
                    if isEditing {
                        TextField("Instructor Email", text: $editEmail)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                            .textFieldStyle(.plain)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                    } else {
                        Text("No email added")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                // View Syllabus CTA placeholder
                // TODO: Store syllabusURL on Course model + Supabase. Enable button when URL is available.
                Button {
                    // TODO: Open syllabus PDF when syllabusURL is stored on Course
                } label: {
                    HStack(spacing: Layout.Spacing.xs) {
                        Image(systemName: "doc.text.fill")
                            .font(.lexend(size: 14, weight: .medium))
                        Text("View Syllabus PDF")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(AppColors.textTertiary)
                    .padding(.horizontal, Layout.Spacing.md)
                    .padding(.vertical, Layout.Spacing.sm)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(.rect(cornerRadius: Layout.CornerRadius.md))
                }
                .buttonStyle(.plain)
                .disabled(true)
                .padding(.top, Layout.Spacing.xs)

                // Inline color picker (editing only)
                if isEditing {
                    VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                        Text("Course Color")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(AppColors.textTertiary)

                        HStack(spacing: Layout.Spacing.sm) {
                            ForEach(availableColors, id: \.hex) { colorOption in
                                Button {
                                    editColorHex = colorOption.hex
                                    HapticFeedbackManager.shared.lightImpact()
                                } label: {
                                    Circle()
                                        .fill(Color(hex: colorOption.hex))
                                        .frame(width: 32, height: 32)
                                        .overlay {
                                            if editColorHex == colorOption.hex {
                                                Image(systemName: "checkmark")
                                                    .font(.lexend(size: 12, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .overlay {
                                            Circle()
                                                .stroke(
                                                    editColorHex == colorOption.hex ? Color.white : Color.clear,
                                                    lineWidth: 2
                                                )
                                        }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, Layout.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.bottom, Layout.Spacing.md)
        }
        .background(AppColors.surface)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isEditing)
    }

    // MARK: - Quick Stats

    private var quickStatsRow: some View {
        HStack(spacing: Layout.Spacing.sm) {
            CourseStatPill(
                icon: "calendar",
                value: "\(courseEvents.count)",
                label: "Events",
                color: .blue
            )
            CourseStatPill(
                icon: "clock",
                value: "\(upcomingCount)",
                label: "Upcoming",
                color: .orange
            )
            if let nextDate = nextEventDate {
                CourseStatPill(
                    icon: "arrow.right.circle",
                    value: nextDate,
                    label: "Next",
                    color: .green
                )
            } else {
                CourseStatPill(
                    icon: "checkmark.circle",
                    value: "\u{2014}",
                    label: "Next",
                    color: .green
                )
            }
        }
        .padding(.horizontal, Layout.Spacing.lg)
        .padding(.top, Layout.Spacing.sm)
    }

    // MARK: - Grading Section

    private var gradingSection: some View {
        GradingBreakdownCard(entries: gradingEntries, onEdit: {
            showingGradingEdit = true
        })
        .padding(.horizontal, Layout.Spacing.lg)
        .padding(.top, Layout.Spacing.md)
    }

    // MARK: - Tab bar

    private var tabBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Layout.Spacing.sm) {
                ForEach(CourseTab.allCases, id: \.self) { tab in
                    CourseTabChip(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        eventCount: eventCount(for: tab)
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedTab = tab
                        }
                        HapticFeedbackManager.shared.lightImpact()
                    }
                }
            }
            .padding(.horizontal, Layout.Spacing.lg)
        }
        .scrollIndicators(.hidden)
        .padding(.top, Layout.Spacing.lg)
        .padding(.bottom, Layout.Spacing.sm)
    }

    // MARK: - Events List

    private var eventsList: some View {
        LazyVStack(spacing: Layout.Spacing.sm) {
            if filteredEvents.isEmpty {
                emptyEventsView
            } else {
                ForEach(filteredEvents) { event in
                    CourseEventRow(event: event)
                }
            }
        }
        .padding(.horizontal, Layout.Spacing.lg)
        .padding(.bottom, Layout.Spacing.xxl)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)
    }

    // MARK: - Helpers

    private func eventCount(for tab: CourseTab) -> Int {
        courseEvents.filter { tab.matches($0.type) }.count
    }

    private var emptyEventsView: some View {
        VStack(spacing: Layout.Spacing.md) {
            Image(systemName: "tray")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(AppColors.textTertiary)

            VStack(spacing: Layout.Spacing.xs) {
                Text("No events found")
                    .font(.titleS)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textSecondary)
                Text("Events in this category will show here")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textTertiary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.Spacing.xxxl)
    }

    // MARK: - Inline Editing

    private func startEditing() {
        editTitle = liveCourse.title ?? ""
        editInstructor = liveCourse.instructor ?? ""
        editColorHex = liveCourse.colorHex ?? ""
        editEmail = "" // TODO: Load from liveCourse.instructorEmail when field exists
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
    }

    private func saveEditing() {
        var updated = liveCourse
        updated.title = editTitle.isEmpty ? nil : editTitle
        updated.instructor = editInstructor.isEmpty ? nil : editInstructor
        updated.colorHex = editColorHex.isEmpty ? nil : editColorHex
        // TODO: Save editEmail when instructorEmail field exists on Course
        Task { await courseRepository.saveCourse(updated) }
        isEditing = false
    }
}

// MARK: - Stat Pill

private struct CourseStatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Layout.Spacing.xs) {
            HStack(spacing: Layout.Spacing.xs) {
                Image(systemName: icon)
                    .font(.lexend(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.titleS)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(label)
                .font(.caption)
                .foregroundStyle(AppColors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.Spacing.sm + 2)
        .background(AppColors.surface)
        .clipShape(.rect(cornerRadius: Layout.CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .stroke(AppColors.border.opacity(0.5), lineWidth: 0.5)
        )
    }
}

// MARK: - Tab Chip

private struct CourseTabChip: View {
    let tab: CourseDetailView.CourseTab
    let isSelected: Bool
    let eventCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.Spacing.xs) {
                Image(systemName: tab.icon)
                    .font(.lexend(size: 13, weight: .medium))

                Text(tab.rawValue)
                    .font(.captionL)
                    .fontWeight(.medium)

                if eventCount > 0 {
                    Text("\(eventCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : AppColors.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white.opacity(0.25) : AppColors.surfaceSecondary)
                        )
                }
            }
            .padding(.horizontal, Layout.Spacing.md)
            .padding(.vertical, Layout.Spacing.sm)
            .foregroundStyle(isSelected ? .white : AppColors.textSecondary)
            .background(isSelected ? AppColors.accent : AppColors.surface)
            .clipShape(.rect(cornerRadius: Layout.CornerRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.xl)
                    .stroke(isSelected ? Color.clear : AppColors.border.opacity(0.4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - Event Row

private struct CourseEventRow: View {
    let event: EventItem

    private var isPast: Bool {
        !event.needsDate && event.start < Date()
    }

    var body: some View {
        HStack(alignment: .top, spacing: Layout.Spacing.md) {
            // Date column
            dateColumn

            // Content
            VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                // Type badge + status
                HStack(spacing: Layout.Spacing.xs) {
                    eventTypeBadge

                    Spacer()

                    if isPast {
                        Text("Past")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }

                // Title
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Location
                if let location = event.location, !location.isEmpty {
                    HStack(spacing: Layout.Spacing.xs) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.lexend(size: 11, weight: .regular))
                            .foregroundStyle(AppColors.textTertiary)
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                // Time
                if !event.needsDate && event.allDay != true {
                    HStack(spacing: Layout.Spacing.xs) {
                        Image(systemName: "clock")
                            .font(.lexend(size: 11, weight: .regular))
                            .foregroundStyle(AppColors.textTertiary)
                        Text(event.start, format: .dateTime.hour().minute())
                            .font(.caption)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
            }
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .clipShape(.rect(cornerRadius: Layout.CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .stroke(AppColors.border.opacity(0.3), lineWidth: 0.5)
        )
        .opacity(isPast ? 0.65 : 1.0)
    }

    // MARK: - Date Column

    private var dateColumn: some View {
        Group {
            if event.needsDate {
                VStack(spacing: 2) {
                    Text("TBD")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textTertiary)
                }
            } else {
                VStack(spacing: 2) {
                    Text(event.start, format: .dateTime.month(.abbreviated))
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(event.type.color)
                        .textCase(.uppercase)
                    Text(event.start, format: .dateTime.day())
                        .font(.titleS)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textPrimary)
                }
            }
        }
        .frame(width: 44)
        .padding(.vertical, Layout.Spacing.xs)
    }

    // MARK: - Type Badge

    private var eventTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: event.type.icon)
                .font(.lexend(size: 10, weight: .medium))
            Text(event.type.displayName)
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(event.type.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(event.type.color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - EventType helpers

extension EventItem.EventType {
    var icon: String {
        switch self {
        case .assignment:     return "doc.text"
        case .quiz:           return "questionmark.circle"
        case .midterm:        return "graduationcap"
        case .final:          return "graduationcap.fill"
        case .lab:            return "flask"
        case .lecture:        return "person.fill"
        case .tutorial:       return "person.2"
        case .officeHours:    return "clock"
        case .importantDate:  return "star.fill"
        case .other:          return "calendar"
        }
    }

    var color: Color {
        switch self {
        case .assignment:     return .orange
        case .quiz:           return .yellow
        case .midterm:        return .pink
        case .final:          return .red
        case .lab:            return .green
        case .lecture:        return .blue
        case .tutorial:       return .teal
        case .officeHours:    return .purple
        case .importantDate:  return AppColors.accent
        case .other:          return .gray
        }
    }

    var displayName: String {
        switch self {
        case .assignment:     return "Assignment"
        case .quiz:           return "Quiz"
        case .midterm:        return "Midterm"
        case .final:          return "Final"
        case .lab:            return "Lab"
        case .lecture:        return "Lecture"
        case .tutorial:       return "Tutorial"
        case .officeHours:    return "Office Hours"
        case .importantDate:  return "Important"
        case .other:          return "Other"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CourseDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let sample = Course(code: "CS 101", title: "Intro to Computer Science", colorHex: "#3478F6", instructor: "Dr. Chen")
        CourseDetailView(course: sample)
            .environmentObject(AppNavigationManager())
            .environmentObject(EventStore())
            .environmentObject(GradingRepository())
            .environmentObject(CourseRepository())
    }
}
#endif
