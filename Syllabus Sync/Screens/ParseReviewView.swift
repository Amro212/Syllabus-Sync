//
//  ParseReviewView.swift
//  Syllabus Sync
//
//  Review screen shown after AI parsing when some events are missing dates.
//  Splits events into "Successfully Extracted" (with dates) and
//  "Action Required" (missing dates). The user can set dates via EventEditView
//  before continuing to save.
//

import SwiftUI

struct ParseReviewView: View {
    @EnvironmentObject var importViewModel: ImportViewModel
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var eventStore: EventStore

    @State private var editingEvent: EventItem?
    @State private var showSkipAlert = false
    @State private var isSaving = false

    // MARK: - Derived data

    private var allEvents: [EventItem] {
        importViewModel.parsedEventsForReview
    }

    private var completeEvents: [EventItem] {
        allEvents.filter { !$0.needsDate }
    }

    private var incompleteEvents: [EventItem] {
        allEvents.filter { $0.needsDate }
    }

    private var allResolved: Bool {
        incompleteEvents.isEmpty
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.Spacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                        Text("Review Extracted Events")
                            .font(.titleM)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)

                        Text("\(allEvents.count) events found — \(incompleteEvents.count) need your attention")
                            .font(.bodyS)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, Layout.Spacing.lg)
                    .padding(.top, Layout.Spacing.md)

                    // Grading Breakdown (if scheme was extracted)
                    if !importViewModel.gradingScheme.isEmpty {
                        GradingBreakdownCard(entries: importViewModel.gradingScheme)
                            .padding(.horizontal, Layout.Spacing.lg)
                    }

                    // Successfully Extracted section
                    if !completeEvents.isEmpty {
                        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                            sectionHeader(
                                title: "SUCCESSFULLY EXTRACTED",
                                color: AppColors.success
                            )

                            ForEach(completeEvents) { event in
                                ReviewCompleteCard(event: event)
                            }
                        }
                        .padding(.horizontal, Layout.Spacing.lg)
                    }

                    // Action Required section
                    if !incompleteEvents.isEmpty {
                        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                            sectionHeader(
                                title: "ACTION REQUIRED",
                                color: AppColors.warning,
                                icon: "exclamationmark.triangle.fill"
                            )

                            ForEach(incompleteEvents) { event in
                                ReviewActionCard(event: event) {
                                    editingEvent = event
                                }
                            }
                        }
                        .padding(.horizontal, Layout.Spacing.lg)
                    }

                    // Bottom padding for the CTA
                    Spacer().frame(height: 100)
                }
            }
            .background(AppColors.background.ignoresSafeArea())

            // Fixed bottom CTA
            VStack(spacing: 0) {
                Divider()
                    .background(AppColors.separator)

                PrimaryCTAButton(
                    "Continue",
                    icon: "arrow.right",
                    isLoading: isSaving
                ) {
                    handleContinue()
                }
                .padding(.horizontal, Layout.Spacing.xl)
                .padding(.vertical, Layout.Spacing.md)
            }
            .background(AppColors.surface.ignoresSafeArea(edges: .bottom))
        }
        .sheet(item: $editingEvent) { event in
            DatePickerSheet(event: eventForEditing(event)) { updatedEvent in
                var resolved = updatedEvent
                resolved.needsDate = false
                importViewModel.updateReviewEvent(resolved)
                editingEvent = nil
            } onCancel: {
                editingEvent = nil
            }
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
        .alert("Events Without Dates", isPresented: $showSkipAlert) {
            Button("Go Back", role: .cancel) {}
            Button("Save Anyway") {
                Task { await saveAndContinue() }
            }
        } message: {
            Text("\(incompleteEvents.count) event\(incompleteEvents.count == 1 ? "" : "s") still \(incompleteEvents.count == 1 ? "has" : "have") no date. They'll be saved and you can set dates later.")
        }
    }

    // MARK: - Section header

    @ViewBuilder
    private func sectionHeader(title: String, color: Color, icon: String? = nil) -> some View {
        HStack(spacing: Layout.Spacing.xs) {
            if let icon {
                Image(systemName: icon)
                    .font(.lexend(size: 12, weight: .semibold))
                    .foregroundColor(color)
            }

            Text(title)
                .font(.captionL)
                .fontWeight(.bold)
                .foregroundColor(color)
                .tracking(1.2)
        }
        .padding(.top, Layout.Spacing.sm)
    }

    // MARK: - Actions

    private func handleContinue() {
        if allResolved {
            Task { await saveAndContinue() }
        } else {
            showSkipAlert = true
        }
    }

    private func saveAndContinue() async {
        isSaving = true
        await importViewModel.completeReviewAndSave(events: allEvents)
        isSaving = false
        navigationManager.showParseReview = false
        navigationManager.switchTab(to: .preview)
    }

    /// Provide a sensible default date when opening the editor for a dateless event.
    /// If the AI guessed a date (low confidence), keep it as a starting point.
    private func eventForEditing(_ event: EventItem) -> EventItem {
        guard event.start == .distantFuture else { return event } // AI has a guess — keep it
        var copy = event
        copy.start = Date() // No AI guess — default to now
        return copy
    }
}

// MARK: - Complete Event Card (has date + evidence)

private struct ReviewCompleteCard: View {
    let event: EventItem

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            HStack(spacing: Layout.Spacing.md) {
                // Event type icon
                eventTypeIcon

                // Title & course
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(event.courseCode)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Date display
                VStack(alignment: .trailing, spacing: 2) {
                    Text(Self.shortDateFormatter.string(from: event.start))
                        .font(.bodyS)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textPrimary)

                    Text(event.allDay == true ? "All Day" : Self.timeFormatter.string(from: event.start))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }

                // Green checkmark
                Image(systemName: "checkmark.circle.fill")
                    .font(.lexend(size: 22, weight: .medium))
                    .foregroundColor(AppColors.success)
            }

            // Evidence quote
            if let source = event.dateSource, !source.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 10))
                    Text("\"\(source)\"")
                        .lineLimit(2)
                }
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary.opacity(0.8))
                .padding(.leading, 40 + Layout.Spacing.md) // align with title
            }
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .stroke(AppColors.separator, lineWidth: 1)
        )
        .cardShadowLight()
    }

    private var eventTypeIcon: some View {
        let (color, icon) = Self.eventTypeStyle(event.type)
        return Image(systemName: icon)
            .font(.lexend(size: 16, weight: .medium))
            .foregroundColor(color)
            .frame(width: 40, height: 40)
            .background(color.opacity(0.15))
            .cornerRadius(Layout.CornerRadius.sm)
    }

    // MARK: - Formatters

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    static func eventTypeStyle(_ type: EventItem.EventType) -> (Color, String) {
        switch type {
        case .assignment: return (Color.orange, "doc.text")
        case .quiz:       return (Color.yellow, "questionmark.circle")
        case .midterm:    return (Color.pink, "graduationcap")
        case .final:      return (Color.red, "rosette")
        case .lab:        return (Color.green, "flask")
        case .lecture:    return (Color.blue, "person.fill")
        case .tutorial:   return (Color.teal, "person.2.fill")
        case .officeHours: return (Color.indigo, "clock.fill")
        case .importantDate: return (Color.orange, "exclamationmark.triangle.fill")
        case .other:      return (AppColors.accent, "bookmark")
        }
    }
}

// MARK: - Action Required Card (missing or uncertain date)

private struct ReviewActionCard: View {
    let event: EventItem
    let onSetDate: () -> Void

    /// True when the AI assigned a date (but low confidence / no evidence)
    private var hasAIGuess: Bool {
        event.start != .distantFuture
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            HStack(spacing: Layout.Spacing.md) {
                // Event type icon
                eventTypeIcon

                // Title, course, status
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(event.courseCode)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)

                    if hasAIGuess {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 9))
                            Text("Low Confidence — \(Self.shortDateFormatter.string(from: event.start))")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.warning)
                    } else {
                        Text("Missing Due Date")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.error)
                    }
                }

                Spacer()

                // Set Date pill button
                Button(action: onSetDate) {
                    Text(hasAIGuess ? "Review" : "Set Date")
                        .font(.captionL)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.background)
                        .padding(.horizontal, Layout.Spacing.md)
                        .padding(.vertical, Layout.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.xl)
                                .fill(AppColors.accent)
                        )
                }
            }

            // Evidence quote (or lack thereof)
            HStack(spacing: 4) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 10))
                if let source = event.dateSource, !source.isEmpty {
                    Text("\"\(source)\"")
                        .lineLimit(2)
                } else {
                    Text("No date found in syllabus")
                        .italic()
                }
            }
            .font(.caption2)
            .foregroundColor(AppColors.textSecondary.opacity(0.8))
            .padding(.leading, 40 + Layout.Spacing.md) // align with title
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .stroke(AppColors.separator, lineWidth: 1)
        )
        .cardShadowLight()
    }

    private var eventTypeIcon: some View {
        let (color, icon) = ReviewCompleteCard.eventTypeStyle(event.type)
        return Image(systemName: icon)
            .font(.lexend(size: 16, weight: .medium))
            .foregroundColor(color)
            .frame(width: 40, height: 40)
            .background(color.opacity(0.15))
            .cornerRadius(Layout.CornerRadius.sm)
    }

    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}

// MARK: - Date Picker Sheet

/// Compact date-only picker shown when the user taps "Set Date" on an action-required event.
private struct DatePickerSheet: View {
    @State private var selectedDate: Date
    @State private var isAllDay: Bool
    private let event: EventItem
    private let onSave: (EventItem) -> Void
    private let onCancel: () -> Void

    init(event: EventItem, onSave: @escaping (EventItem) -> Void, onCancel: @escaping () -> Void) {
        self.event = event
        self.onSave = onSave
        self.onCancel = onCancel
        _selectedDate = State(initialValue: event.start)
        _isAllDay = State(initialValue: event.allDay ?? true)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: Layout.Spacing.lg) {
                // Event info header
                HStack(spacing: Layout.Spacing.md) {
                    let (color, icon) = ReviewCompleteCard.eventTypeStyle(event.type)
                    Image(systemName: icon)
                        .font(.lexend(size: 16, weight: .medium))
                        .foregroundColor(color)
                        .frame(width: 36, height: 36)
                        .background(color.opacity(0.15))
                        .cornerRadius(Layout.CornerRadius.sm)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.title)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        Text(event.courseCode)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, Layout.Spacing.lg)

                Divider().background(AppColors.separator)

                // Date picker
                DatePicker(
                    "Due Date",
                    selection: $selectedDate,
                    displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .tint(AppColors.accent)
                .padding(.horizontal, Layout.Spacing.md)

                Toggle("All Day", isOn: $isAllDay)
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)
                    .tint(AppColors.accent)
                    .padding(.horizontal, Layout.Spacing.lg)

                Spacer()
            }
            .padding(.top, Layout.Spacing.md)
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Set Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(AppColors.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = event
                        updated.start = selectedDate
                        updated.allDay = isAllDay
                        onSave(updated)
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.accent)
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ParseReviewView_Previews: PreviewProvider {
    static var previews: some View {
        ParseReviewView()
            .environmentObject(ImportViewModel(
                extractor: PDFKitExtractor(),
                parser: SyllabusParserRemote(apiClient: URLSessionAPIClient(configuration: .init(baseURL: URL(string: "http://localhost:8787")!))),
                eventStore: EventStore(),
                courseRepository: CourseRepository(),
                gradingRepository: GradingRepository()
            ))
            .environmentObject(AppNavigationManager())
            .environmentObject(EventStore())
    }
}
#endif
