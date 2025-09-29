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
    @State private var location: String
    @State private var notes: String
    @State private var recurrenceRule: String

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
        _location = State(initialValue: event.location ?? "")
        _notes = State(initialValue: event.notes ?? "")
        _recurrenceRule = State(initialValue: event.recurrenceRule ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                        .textInputAutocapitalization(.sentences)

                    Picker("Type", selection: $type) {
                        ForEach(EventItem.EventType.allCases, id: \.self) { value in
                            Text(displayName(for: value)).tag(value)
                        }
                    }

                    Toggle("All Day", isOn: $isAllDay)
                }

                Section("Timing") {
                    DatePicker("Start", selection: $startDate, displayedComponents: [.date, .hourAndMinute])

                    Toggle("Add End Time", isOn: $includeEndDate)

                    if includeEndDate {
                        DatePicker("End", selection: $endDate, in: startDate..., displayedComponents: [.date, .hourAndMinute])
                    }

                    TextField("Recurrence Rule", text: $recurrenceRule)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled(true)
                }

                Section("Location") {
                    TextField("Location", text: $location)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancelEdit() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEdit() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func saveEdit() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let normalizedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRecurrence = recurrenceRule.trimmingCharacters(in: .whitespacesAndNewlines)

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
            recurrenceRule: normalizedRecurrence.isEmpty ? nil : normalizedRecurrence,
            reminderMinutes: event.reminderMinutes,
            confidence: event.confidence
        )

        HapticFeedbackManager.shared.success()
        onSave(updated)
        dismiss()
    }

    private func cancelEdit() {
        HapticFeedbackManager.shared.warning()
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
