import SwiftUI

struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss

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
    @State private var reminderMinutes: Int

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
        _startDate = State(initialValue: event.start)
        let defaultEnd = event.end ?? event.start.addingTimeInterval(60 * 60)
        _endDate = State(initialValue: defaultEnd)
        _includeEndDate = State(initialValue: event.end != nil)
        _isAllDay = State(initialValue: event.allDay ?? false)
        _selectedRecurrence = State(initialValue: RecurrenceFrequency.frequency(from: event.recurrenceRule))
        _location = State(initialValue: event.location ?? "")
        _notes = State(initialValue: event.notes ?? "")
        _reminderMinutes = State(initialValue: event.reminderMinutes ?? 1440)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    eventDetailsSection
                    eventTypeAndRecurrenceSection
                    dateAndTimeSection
                    reminderSection
                    locationAndNotesSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(isCreatingNew ? "New Event" : "Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { cancelEdit() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
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
                        .foregroundColor(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? AppColors.textTertiary : AppColors.accent)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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

    // MARK: - Event Details Section
    private var eventDetailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header OUTSIDE card
            Text("Event Details")
                .font(.titleS)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            // Card
            VStack(alignment: .leading, spacing: 16) {
                // Title Field
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
                        .cornerRadius(12)
                }

                // Course Code Field
                VStack(alignment: .leading, spacing: 6) {
                    Text("Course Code (Optional)")
                        .font(.captionL)
                        .foregroundColor(AppColors.accent)
                    
                    TextField("e.g., CS 101", text: $courseCode)
                        .font(.bodyRegular)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: .courseCode)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(AppColors.surfaceSecondary)
                        .cornerRadius(12)
                }
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(16)
        }
    }

    // MARK: - Event Type & Recurrence Section
    private var eventTypeAndRecurrenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header OUTSIDE card
            Text("Event Type & Recurrence")
                .font(.titleS)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            // Card
            VStack(alignment: .leading, spacing: 16) {
                // Type Dropdown
                VStack(alignment: .leading, spacing: 6) {
                    Text("Type of Event")
                        .font(.captionL)
                        .foregroundColor(AppColors.accent)
                    
                    Menu {
                        Picker(selection: $type) {
                            ForEach(EventItem.EventType.allCases, id: \.self) { value in
                                Text(displayName(for: value)).tag(value)
                            }
                        } label: { EmptyView() }
                    } label: {
                        HStack {
                            Text(displayName(for: type))
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
                        .cornerRadius(12)
                    }
                    .menuIndicator(.hidden)
                }

                // Recurrence Dropdown
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
                        .cornerRadius(12)
                    }
                    .menuIndicator(.hidden)
                }
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(16)
        }
    }

    // MARK: - Date & Time Section
    private var dateAndTimeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Card with header INSIDE
            VStack(alignment: .leading, spacing: 12) {
                // Section header inside card
                Text("Date & Time")
                    .font(.titleS)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.bottom, 4)

                // All-Day Toggle
                HStack {
                    Text("All-day")
                        .font(.bodyRegular)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $isAllDay)
                        .toggleStyle(SwitchToggleStyle(tint: AppColors.accent))
                        .labelsHidden()
                }
                
                // Date Field - full width
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
                    .cornerRadius(12)
                }

                // Time Field - full width (hidden when All-Day)
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
                        .cornerRadius(12)
                    }
                }
                
                // Add end time toggle
                HStack {
                    Text("Add end time")
                        .font(.bodyRegular)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Toggle("", isOn: $includeEndDate.animation(.easeInOut(duration: 0.2)))
                        .toggleStyle(SwitchToggleStyle(tint: AppColors.accent))
                        .labelsHidden()
                }

                // End Date/Time (if enabled)
                if includeEndDate {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("End")
                            .font(.captionL)
                            .foregroundColor(AppColors.accent)
                        
                        HStack {
                            DatePicker("", selection: $endDate, in: startDate..., displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                                .datePickerStyle(.compact)
                                .labelsHidden()
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(AppColors.surfaceSecondary)
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(16)
        }
    }

    // MARK: - Location & Notes Section
    private var locationAndNotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header OUTSIDE card
            Text("Location & Notes")
                .font(.titleS)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            // Card
            VStack(alignment: .leading, spacing: 16) {
                // Location Field
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
                        .cornerRadius(12)
                }

                // Notes Field
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
                        .cornerRadius(12)
                }
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(16)
        }
    }

    // MARK: - Reminder Section
    private var reminderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section header OUTSIDE card
            Text("Reminder")
                .font(.titleS)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            // Card (just the dropdown)
            Menu {
                Picker(selection: $reminderMinutes) {
                    Text("At time of event").tag(0)
                    Text("5 minutes before").tag(5)
                    Text("15 minutes before").tag(15)
                    Text("30 minutes before").tag(30)
                    Text("1 hour before").tag(60)
                    Text("1 day before").tag(1440)
                } label: { EmptyView() }
            } label: {
                HStack {
                    Text(reminderLabel(for: reminderMinutes))
                        .font(.bodyRegular)
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(AppColors.surface)
                .cornerRadius(16)
            }
            .menuIndicator(.hidden)
        }
    }

    // MARK: - Helpers

    private var hasUnsavedChanges: Bool {
        if title != event.title { return true }
        if type != event.type { return true }
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
        guard !trimmedTitle.isEmpty else { return }

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
            reminderMinutes: reminderMinutes,
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
        case .other: return "Other"
        }
    }

    private func reminderLabel(for minutes: Int) -> String {
        switch minutes {
        case 0: return "At time of event"
        case 5: return "5 minutes before"
        case 15: return "15 minutes before"
        case 30: return "30 minutes before"
        case 60: return "1 hour before"
        case 1440: return "1 day before"
        default: return "\(minutes) minutes before"
        }
    }
}
