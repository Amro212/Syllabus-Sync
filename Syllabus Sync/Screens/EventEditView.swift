import SwiftUI

struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var eventStore: EventStore

    let event: EventItem
    let isCreatingNew: Bool
    let onSave: (EventItem) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var courseCode: String
    @State private var type: EventItem.EventType
    @State private var startDate: Date
    @State private var includeEndDate: Bool
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var selectedRecurrence: RecurrenceFrequency
    @State private var location: String
    @State private var notes: String

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
        case courseCode
        case location
        case notes
    }

    enum RecurrenceFrequency: String, CaseIterable, Identifiable {
        case none
        case daily
        case weekly
        case monthly

        var id: String { rawValue }

        var label: String {
            switch self {
            case .none: return "Does not repeat"
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .monthly: return "Monthly"
            }
        }

        var recurrenceRule: String? {
            switch self {
            case .none: return nil
            case .daily: return "FREQ=DAILY"
            case .weekly: return "FREQ=WEEKLY"
            case .monthly: return "FREQ=MONTHLY"
            }
        }

        static func frequency(from recurrenceRule: String?) -> RecurrenceFrequency {
            guard let rule = recurrenceRule?.uppercased() else { return .none }
            if rule.contains("FREQ=DAILY") { return .daily }
            if rule.contains("FREQ=WEEKLY") { return .weekly }
            if rule.contains("FREQ=MONTHLY") { return .monthly }
            return .none
        }
    }

    init(event: EventItem, isCreatingNew: Bool = false, onSave: @escaping (EventItem) -> Void, onCancel: @escaping () -> Void) {
        self.event = event
        self.isCreatingNew = isCreatingNew
        self.onSave = onSave
        self.onCancel = onCancel

        _title = State(initialValue: event.title)
        _courseCode = State(initialValue: event.courseCode)
        _type = State(initialValue: event.type)

        let effectiveStart = event.needsDate ? Date() : event.start
        _startDate = State(initialValue: effectiveStart)
        let defaultEnd = event.end ?? effectiveStart.addingTimeInterval(60 * 60)
        _endDate = State(initialValue: defaultEnd)
        _includeEndDate = State(initialValue: event.end != nil)

        _isAllDay = State(initialValue: event.allDay ?? false)
        _selectedRecurrence = State(initialValue: RecurrenceFrequency.frequency(from: event.recurrenceRule))
        _location = State(initialValue: event.location ?? "")
        _notes = State(initialValue: event.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        heroCard
                        eventDetailsSection
                        eventTypeAndRecurrenceSection
                        dateAndTimeSection
                        locationAndNotesSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 110)
                }
            }
            .navigationTitle(isCreatingNew ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { cancelEdit() } label: {
                        Image(systemName: "xmark")
                            .font(.lexend(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppColors.surface)
                            .clipShape(Circle())
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEdit() }
                        .font(.bodyRegular)
                        .fontWeight(.medium)
                        .foregroundColor(canSave ? AppColors.accent : AppColors.textTertiary)
                        .disabled(!canSave)
                }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onAppear {
            if isCreatingNew {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    focusedField = .title
                }
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isCreatingNew ? "Create Event" : "Update Event")
                        .font(.titleS)
                        .foregroundColor(AppColors.textPrimary)

                    Text(heroSummaryText)
                        .font(.captionRegular)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(displayName(for: type))
                    .font(.captionL)
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(AppColors.accent.opacity(0.12))
                    .clipShape(Capsule())
            }

            Divider()
                .overlay(AppColors.border.opacity(0.5))

            HStack(spacing: 12) {
                Label(courseBadgeText, systemImage: "book.closed")
                Label(startDate.formatted(date: .abbreviated, time: isAllDay ? .omitted : .shortened), systemImage: "calendar")
            }
            .font(.captionRegular)
            .foregroundColor(AppColors.textSecondary)
        }
        .padding(16)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var eventDetailsSection: some View {
        sectionCard(title: "Event Details", icon: "square.and.pencil") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                        .font(.captionL)
                        .foregroundColor(AppColors.accent)

                    TextField("e.g., Problem Set 4 Due", text: $title)
                        .font(.bodyRegular)
                        .textInputAutocapitalization(.sentences)
                        .focused($focusedField, equals: .title)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(AppColors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.border.opacity(0.4), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Course Code")
                        .font(.captionL)
                        .foregroundColor(AppColors.accent)

                    HStack(spacing: 0) {
                        TextField("e.g., CS 101", text: $courseCode)
                            .font(.bodyRegular)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .focused($focusedField, equals: .courseCode)

                        if !existingCourses.isEmpty {
                            Menu {
                                ForEach(existingCourses, id: \.self) { course in
                                    Button(course) {
                                        courseCode = course
                                        HapticFeedbackManager.shared.selection()
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.down.circle.fill")
                                    .font(.lexend(size: 20, weight: .regular))
                                    .foregroundColor(AppColors.accent)
                            }
                            .menuIndicator(.hidden)
                        }
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .background(AppColors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(AppColors.border.opacity(0.4), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    private var eventTypeAndRecurrenceSection: some View {
        sectionCard(title: "Type & Recurrence", icon: "rectangle.grid.2x2") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Event Type")
                        .font(.captionL)
                        .foregroundColor(AppColors.accent)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                        ForEach(EventItem.EventType.allCases, id: \.self) { value in
                            Button {
                                type = value
                                HapticFeedbackManager.shared.selection()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: iconName(for: value))
                                        .font(.caption)
                                    Text(displayName(for: value))
                                        .font(.captionRegular)
                                        .lineLimit(1)
                                }
                                .foregroundColor(type == value ? AppColors.surface : AppColors.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .padding(.horizontal, 12)
                                .background(type == value ? AppColors.accent : AppColors.surfaceSecondary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(type == value ? AppColors.accent : AppColors.border.opacity(0.35), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Recurrence")
                        .font(.captionL)
                        .foregroundColor(AppColors.accent)

                    Menu {
                        Picker(selection: $selectedRecurrence) {
                            ForEach(RecurrenceFrequency.allCases, id: \.self) { option in
                                Text(option.label).tag(option)
                            }
                        } label: { EmptyView() }
                    } label: {
                        HStack {
                            Text(selectedRecurrence.label)
                                .font(.bodyRegular)
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(AppColors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .menuIndicator(.hidden)
                }
            }
        }
    }

    private var dateAndTimeSection: some View {
        sectionCard(title: "Date & Time", icon: "calendar.badge.clock") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("All-day")
                        .font(.bodyRegular)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $isAllDay)
                        .toggleStyle(SwitchToggleStyle(tint: AppColors.accent))
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Date")
                        .font(.captionL)
                        .foregroundColor(AppColors.accent)

                    HStack {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(AppColors.surfaceSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                if !isAllDay {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Time")
                            .font(.captionL)
                            .foregroundColor(AppColors.accent)

                        HStack {
                            DatePicker("", selection: $startDate, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.compact)
                                .labelsHidden()
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(AppColors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                HStack {
                    Text("Add end time")
                        .font(.bodyRegular)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $includeEndDate.animation(.easeInOut(duration: 0.2)))
                        .toggleStyle(SwitchToggleStyle(tint: AppColors.accent))
                        .labelsHidden()
                }

                if includeEndDate {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("End")
                            .font(.captionL)
                            .foregroundColor(AppColors.accent)

                        HStack {
                            DatePicker(
                                "",
                                selection: $endDate,
                                in: startDate...,
                                displayedComponents: isAllDay ? .date : [.date, .hourAndMinute]
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(AppColors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
    }

    private var locationAndNotesSection: some View {
        sectionCard(title: "Location & Notes", icon: "mappin.and.ellipse") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Location (Optional)")
                        .font(.captionL)
                        .foregroundColor(AppColors.accent)

                    TextField("e.g., Online, Room 101", text: $location)
                        .font(.bodyRegular)
                        .textInputAutocapitalization(.words)
                        .focused($focusedField, equals: .location)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(AppColors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes (Optional)")
                        .font(.captionL)
                        .foregroundColor(AppColors.accent)

                    TextField("Any additional details...", text: $notes, axis: .vertical)
                        .font(.bodyRegular)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .notes)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(AppColors.surfaceSecondary)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    // MARK: - Helpers

    private var courseBadgeText: String {
        let normalized = courseCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "Course" : normalized.uppercased()
    }

    private var heroSummaryText: String {
        if isCreatingNew {
            return "Add details, choose type, and save when ready."
        }
        return "Refine the event details and keep your schedule accurate."
    }

    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(AppColors.accent)
                    .frame(width: 24, height: 24)
                    .background(AppColors.accent.opacity(0.12))
                    .clipShape(Circle())

                Text(title)
                    .font(.titleS)
                    .foregroundColor(AppColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(16)
            .background(AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var existingCourses: [String] {
        let courses = Set(eventStore.events.map { $0.courseCode }).filter { !$0.isEmpty }
        return courses.sorted()
    }

    private var canSave: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCourseCode = courseCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedTitle.isEmpty && !trimmedCourseCode.isEmpty
    }

    private var hasUnsavedChanges: Bool {
        if title != event.title { return true }
        if type != event.type { return true }
        if event.needsDate { return true }
        if startDate != event.start { return true }
        if includeEndDate != (event.end != nil) { return true }
        if includeEndDate, let end = event.end, endDate != end { return true }
        if isAllDay != (event.allDay ?? false) { return true }
        if (event.location ?? "") != location { return true }
        if (event.notes ?? "") != notes { return true }
        if selectedRecurrence.recurrenceRule != event.recurrenceRule { return true }
        return false
    }

    private func saveEdit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCourseCode = courseCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmedTitle.isEmpty && !trimmedCourseCode.isEmpty else { return }

        let normalizedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let recurrenceValue = selectedRecurrence.recurrenceRule

        let updated = EventItem(
            id: event.id,
            courseCode: trimmedCourseCode,
            type: type,
            title: trimmedTitle,
            start: startDate,
            end: includeEndDate ? endDate : nil,
            allDay: isAllDay,
            location: normalizedLocation.isEmpty ? nil : normalizedLocation,
            notes: normalizedNotes.isEmpty ? nil : normalizedNotes,
            recurrenceRule: recurrenceValue,
            reminderMinutes: event.reminderMinutes,
            confidence: event.confidence
        )

        HapticFeedbackManager.shared.lightImpact()
        onSave(updated)
        dismiss()
    }

    private func cancelEdit() {
        HapticFeedbackManager.shared.selection()
        onCancel()
        dismiss()
    }

    private func displayName(for type: EventItem.EventType) -> String {
        switch type {
        case .assignment: return "Assignment"
        case .quiz: return "Quiz"
        case .midterm: return "Midterm"
        case .final: return "Final"
        case .lab: return "Lab"
        case .lecture: return "Lecture"
        case .tutorial: return "Tutorial"
        case .officeHours: return "Office Hours"
        case .importantDate: return "Important Date"
        case .other: return "Other"
        }
    }

    private func iconName(for type: EventItem.EventType) -> String {
        switch type {
        case .assignment: return "doc.text"
        case .quiz: return "checkmark.circle"
        case .midterm: return "pencil.and.ruler"
        case .final: return "graduationcap"
        case .lab: return "flask"
        case .lecture: return "person.2"
        case .tutorial: return "book"
        case .officeHours: return "clock"
        case .importantDate: return "star"
        case .other: return "calendar"
        }
    }

}
