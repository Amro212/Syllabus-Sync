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
    @State private var showingEditSheet = false
    @State private var showingGradingEdit = false

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

    private var courseColor: Color {
        if let hex = course.colorHex {
            return Color(hex: hex)
        }
        return AppColors.accent
    }

    private var upcomingCount: Int {
        courseEvents.filter { $0.start >= Date() }.count
    }

    private var nextEventDate: String? {
        guard let next = courseEvents
            .filter({ $0.start >= Date() })
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
        .sheet(isPresented: $showingEditSheet) {
            CourseEditSheet(course: course) { updated in
                Task { await courseRepository.saveCourse(updated) }
                showingEditSheet = false
            }
        }
        .sheet(isPresented: $showingGradingEdit) {
            GradingEditView(courseId: course.id, entries: gradingEntries)
        }
        .task {
            _ = await gradingRepository.fetch(forCourseId: course.id)
        }
    }

    // MARK: - Header

    private var courseHeader: some View {
        VStack(spacing: 0) {
            // Color accent strip
            courseColor
                .frame(height: 140)
                .overlay(alignment: .topLeading) {
                    // Decorative circles
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 180, height: 180)
                            .offset(x: -40, y: -60)
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .frame(width: 120, height: 120)
                            .offset(x: 200, y: -20)
                    }
                }
                .overlay(alignment: .top) {
                    // Navigation bar
                    HStack {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.lexend(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial.opacity(0.6))
                                .background(Color.black.opacity(0.15))
                                .clipShape(Circle())
                        }

                        Spacer()

                        Button {
                            HapticFeedbackManager.shared.lightImpact()
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.lexend(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 36, height: 36)
                                .background(.ultraThinMaterial.opacity(0.6))
                                .background(Color.black.opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, Layout.Spacing.lg)
                    .padding(.top, 56)
                }

            // Course info card -- overlaps the color strip
            VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                // Course code badge
                Text(course.code)
                    .font(.captionL)
                    .fontWeight(.bold)
                    .foregroundStyle(courseColor)
                    .padding(.horizontal, Layout.Spacing.sm)
                    .padding(.vertical, Layout.Spacing.xs)
                    .background(courseColor.opacity(0.12))
                    .clipShape(.rect(cornerRadius: Layout.CornerRadius.sm))

                // Course title
                Text(course.title ?? course.code)
                    .font(.titleL)
                    .fontWeight(.bold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Instructor row
                if let instructor = course.instructor, !instructor.isEmpty {
                    HStack(spacing: Layout.Spacing.xs) {
                        Image(systemName: "person.circle.fill")
                            .font(.lexend(size: 14, weight: .regular))
                            .foregroundStyle(AppColors.textTertiary)
                        Text(instructor)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Layout.Spacing.lg)
            .background(AppColors.surface)
            .clipShape(.rect(
                topLeadingRadius: Layout.CornerRadius.xl,
                topTrailingRadius: Layout.CornerRadius.xl
            ))
            .offset(y: -Layout.Spacing.xl)
        }
        .padding(.bottom, -Layout.Spacing.xl) // Compensate for offset
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

// MARK: - Course Edit Sheet

private struct CourseEditSheet: View {
    let course: Course
    let onSave: (Course) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var courseName: String = ""
    @State private var instructorName: String = ""
    @State private var selectedColorHex: String = ""

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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.Spacing.xl) {
                    // Course Name
                    VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                        Text("Course Name")
                            .font(.titleS)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.textPrimary)
                        TextField("Introduction to Computer Science", text: $courseName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Instructor
                    VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                        Text("Instructor")
                            .font(.titleS)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.textPrimary)
                        TextField("Dr. Sarah Chen", text: $instructorName)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Color Selection
                    VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                        Text("Course Color")
                            .font(.titleS)
                            .fontWeight(.semibold)
                            .foregroundStyle(AppColors.textPrimary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: Layout.Spacing.md) {
                            ForEach(availableColors, id: \.hex) { color in
                                CourseColorButton(
                                    color: Color(hex: color.hex),
                                    isSelected: selectedColorHex == color.hex
                                ) {
                                    selectedColorHex = color.hex
                                    HapticFeedbackManager.shared.lightImpact()
                                }
                            }
                        }
                    }
                }
                .padding(Layout.Spacing.lg)
            }
            .scrollIndicators(.hidden)
            .background(AppColors.background)
            .navigationTitle("Edit Course")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        HapticFeedbackManager.shared.mediumImpact()
                        var updated = course
                        updated.title = courseName.isEmpty ? nil : courseName
                        updated.instructor = instructorName.isEmpty ? nil : instructorName
                        updated.colorHex = selectedColorHex.isEmpty ? nil : selectedColorHex
                        onSave(updated)
                    }
                    .foregroundStyle(AppColors.accent)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            courseName = course.title ?? ""
            instructorName = course.instructor ?? ""
            selectedColorHex = course.colorHex ?? ""
        }
    }
}

// MARK: - Color Selection Button

private struct CourseColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 40, height: 40)

                if isSelected {
                    Circle()
                        .stroke(AppColors.accent, lineWidth: 3)
                        .frame(width: 40, height: 40)

                    Image(systemName: "checkmark")
                        .font(.lexend(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
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
