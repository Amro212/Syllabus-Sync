import SwiftUI

struct EventEditView: View {
    @Environment(\.dismiss) private var dismiss

    let event: EventItem
    let onSave: (EventItem) -> Void
    let onCancel: () -> Void

    @State private var title: String
    @State private var type: EventItem.EventType
    @State private var startDate: Date
    @State private var includeEndDate: Bool
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var showRecurrence: Bool
    @State private var selectedRecurrence: RecurrenceFrequency
    @State private var lastNonNoneRecurrence: RecurrenceFrequency
    @State private var location: String
    @State private var notes: String

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case title
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
            case .none: return "Doesn't repeat"
            case .daily: return "Repeats daily"
            case .weekly: return "Repeats weekly"
            case .monthly: return "Repeats monthly"
            }
        }

        var recurrenceRule: String? {
            switch self {
            case .none:
                return nil
            case .daily:
                return "FREQ=DAILY"
            case .weekly:
                return "FREQ=WEEKLY"
            case .monthly:
                return "FREQ=MONTHLY"
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

    init(event: EventItem, onSave: @escaping (EventItem) -> Void, onCancel: @escaping () -> Void) {
        self.event = event
        self.onSave = onSave
        self.onCancel = onCancel

        _title = State(initialValue: event.title)
        _type = State(initialValue: event.type)
        _startDate = State(initialValue: event.start)
        let defaultEnd = event.end ?? event.start.addingTimeInterval(60 * 60)
        _endDate = State(initialValue: defaultEnd)
        _includeEndDate = State(initialValue: event.end != nil)
        _isAllDay = State(initialValue: event.allDay ?? false)
        let initialRecurrence = RecurrenceFrequency.frequency(from: event.recurrenceRule)
        _showRecurrence = State(initialValue: initialRecurrence != .none)
        _selectedRecurrence = State(initialValue: initialRecurrence)
        let initialLast = initialRecurrence == .none ? .weekly : initialRecurrence
        _lastNonNoneRecurrence = State(initialValue: initialLast)
        _location = State(initialValue: event.location ?? "")
        _notes = State(initialValue: event.notes ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Layout.Spacing.lg) {
                    titleSection
                    timingSection
                    recurrenceSection
                    locationSection
                    notesSection
                }
                .padding(.horizontal, Layout.Spacing.lg)
                .padding(.top, Layout.Spacing.xl)
                .padding(.bottom, Layout.Spacing.massive)
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { cancelEdit() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEdit() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(hasUnsavedChanges)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                focusedField = .title
            }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            Text("Details")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: Layout.Spacing.sm) {
                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    Text("Title")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)

                    TextField("Event title", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .disableAutocorrection(true)
                        .focused($focusedField, equals: .title)
                        .padding()
                        .background(AppColors.surface)
                        .cornerRadius(Layout.CornerRadius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                }

                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    Text("Type")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)

                    Menu {
                        Picker(selection: $type) {
                            ForEach(EventItem.EventType.allCases, id: \.self) { value in
                                Text(displayName(for: value)).tag(value)
                            }
                        } label: {
                            EmptyView()
                        }
                    } label: {
                        HStack(spacing: Layout.Spacing.xs) {
                            Text(displayName(for: type))
                                .font(.body)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "chevron.down")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(AppColors.accent)
                        }
                        .padding(.horizontal, Layout.Spacing.md)
                        .padding(.vertical, Layout.Spacing.md)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.md, style: .continuous)
                                .fill(AppColors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.md, style: .continuous)
                                .stroke(AppColors.border, lineWidth: 1)
                        )
                    }
                    .menuIndicator(.hidden)
                    .menuStyle(.automatic)
                    .frame(maxWidth: .infinity)
                }

                Toggle("All-day", isOn: $isAllDay)
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.accent))
                    .padding()
                    .background(AppColors.surface)
                    .cornerRadius(Layout.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            }
        }
    }

    private var timingSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            Text("Date & Time")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: Layout.Spacing.md) {
                DatePicker(selection: $startDate, displayedComponents: timeComponents(for: isAllDay)) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(AppColors.accent)
                        Text("Start")
                            .font(.body.weight(.semibold))
                    }
                }
                .datePickerStyle(.compact)

                Toggle("Add end time", isOn: $includeEndDate.animation(.easeInOut(duration: 0.2)))
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.accent))

                if includeEndDate {
                    DatePicker(selection: $endDate, in: startDate..., displayedComponents: timeComponents(for: isAllDay)) {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(AppColors.accentSecondary)
                            Text("End")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .datePickerStyle(.compact)
                }
            }
            .padding()
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
    }

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            Text("Recurrence")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                Toggle("Repeats", isOn: $showRecurrence.animation(.easeInOut(duration: 0.2)))
                    .toggleStyle(SwitchToggleStyle(tint: AppColors.accent))

                if showRecurrence {
                    Picker("Repeat", selection: $selectedRecurrence) {
                        ForEach(RecurrenceFrequency.allCases.filter { $0 != .none }, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding()
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
        .onChange(of: showRecurrence) { newValue in
            if newValue {
                selectedRecurrence = lastNonNoneRecurrence
            } else {
                selectedRecurrence = .none
            }
        }
        .onChange(of: selectedRecurrence) { newValue in
            if newValue != .none {
                lastNonNoneRecurrence = newValue
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            Text("Location")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            TextField("Add location", text: $location)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .focused($focusedField, equals: .location)
                .padding()
                .background(AppColors.surface)
                .cornerRadius(Layout.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            Text("Notes")
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)

            TextEditor(text: $notes)
                .focused($focusedField, equals: .notes)
                .frame(minHeight: 120)
                .padding(8)
                .background(AppColors.surface)
                .cornerRadius(Layout.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        }
    }

    private var hasUnsavedChanges: Bool {
        if title != event.title { return true }
        if type != event.type { return true }
        if startDate != event.start { return true }
        if includeEndDate != (event.end != nil) { return true }
        if includeEndDate, let end = event.end, endDate != end { return true }
        if isAllDay != (event.allDay ?? false) { return true }
        if (event.location ?? "") != location { return true }
        if (event.notes ?? "") != notes { return true }
        if showRecurrence != (event.recurrenceRule != nil) { return true }
        if selectedRecurrence.recurrenceRule != event.recurrenceRule { return true }
        return false
    }

    private func timeComponents(for allDay: Bool) -> DatePickerComponents {
        allDay ? [.date] : [.date, .hourAndMinute]
    }

    private func saveEdit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let normalizedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let recurrenceValue = showRecurrence ? selectedRecurrence.recurrenceRule : nil

        let updated = EventItem(
            id: event.id,
            courseCode: event.courseCode,
            type: type,
            title: trimmedTitle,
            start: startDate,
            end: includeEndDate ? endDate : nil,
            allDay: isAllDay ? true : nil,
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
        case .other: return "Other"
        }
    }
    }
