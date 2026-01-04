//
//  PreviewView.swift
//  Syllabus Sync
//

import SwiftUI
import UIKit

struct PreviewView: View {
    @EnvironmentObject var importViewModel: ImportViewModel
    @EnvironmentObject var eventStore: EventStore
    @State private var selectedTab: PreviewTab = .events
    @State private var editingEvent: EventItem?

    private var events: [EventItem] {
        let parsed = importViewModel.events
        if parsed.isEmpty {
            return eventStore.events
        }
        return parsed
    }
    
    enum PreviewTab: String, CaseIterable {
        case events = "Events"
        case rawOCR = "Raw OCR"
        case processedOCR = "Processed OCR"
        case aiOutput = "AI Output"

        var icon: String {
            switch self {
            case .events: return "calendar"
            case .rawOCR: return "doc.plaintext"
            case .processedOCR: return "doc.text"
            case .aiOutput: return "brain"
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            let headerHeight = geo.safeAreaInsets.top + 4
            
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    headerSection
                        .padding(Layout.Spacing.lg)
                        .padding(.top, 60)
                    
                    // Tab Selector
                    Picker("Preview Tab", selection: $selectedTab) {
                        ForEach(PreviewTab.allCases, id: \.self) { tab in
                            HStack(spacing: Layout.Spacing.xs) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 14, weight: .medium))
                                Text(tab.rawValue)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .tag(tab)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, Layout.Spacing.lg)
                    .padding(.bottom, Layout.Spacing.md)
                    
                    // Tab Content
                    ScrollView {
                        switch selectedTab {
                        case .events:
                            eventsTabContent
                        case .rawOCR:
                            rawOCRTabContent
                        case .processedOCR:
                            processedOCRTabContent
                        case .aiOutput:
                            aiOutputTabContent
                        }
                    }
                    .background(AppColors.background)
                }
                .background(AppColors.background)
                
                // Custom Top Bar (Sticky)
                VStack(spacing: 0) {
                    HStack {
                        Text("Preview")
                            .font(.titleL)
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Spacer()
                        
                        Image(systemName: "person.circle")
                            .font(.system(size: 28))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    .padding(.horizontal, Layout.Spacing.md)
                    .padding(.bottom, Layout.Spacing.sm)
                    .padding(.top, geo.safeAreaInsets.top)
                    .background(AppColors.background.opacity(0.95))
                    .overlay(alignment: .bottom) {
                        Divider().opacity(0.5)
                    }
                    
                    Spacer()
                }
                .frame(height: headerHeight + 50)
                .ignoresSafeArea(edges: .top)
            }
            .background(AppColors.background)
        }
        .fullScreenCover(item: $editingEvent) { event in
            EventEditView(event: event) { updated in
                Task { await importViewModel.applyEditedEvent(updated) }
                editingEvent = nil
            } onCancel: {
                editingEvent = nil
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            if let image = importViewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(Layout.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            }

            if let message = eventStore.debugMessage {
                Text(message)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color.green)
                    .padding(.horizontal, Layout.Spacing.md)
                    .padding(.vertical, Layout.Spacing.xs)
                    .background(AppColors.surface)
                    .cornerRadius(Layout.CornerRadius.sm)
            }

            if let diagnostics = importViewModel.diagnosticsString {
                Text(diagnostics)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Layout.Spacing.md)
                    .padding(.vertical, Layout.Spacing.xs)
                    .background(AppColors.surface)
                    .cornerRadius(Layout.CornerRadius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.sm)
                            .stroke(AppColors.separator, lineWidth: 1)
                    )
            }

            Text(events.isEmpty ? "No events parsed yet" : "\(events.count) Events Ready")
                .font(.titleM)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            Text("Review the extracted assignments, exams, and deadlines before syncing to Calendar.")
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var eventsTabContent: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
            if events.isEmpty {
                PreviewEmptyStateView()
            } else {
                eventsSection
            }
        }
        .padding(Layout.Spacing.lg)
        .padding(.bottom, 80) // Add bottom padding for tab bar
    }
    
    private var aiOutputTabContent: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
            if let rawResponse = importViewModel.rawAIResponse {
                AIOutputView(rawResponse: rawResponse)
            } else {
                AIOutputEmptyStateView()
            }
        }
        .padding(Layout.Spacing.lg)
        .padding(.bottom, 80) // Add bottom padding for tab bar
    }

    private var rawOCRTabContent: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            if let tsvData = importViewModel.parserInputText, !tsvData.isEmpty {
                VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                    HStack(spacing: Layout.Spacing.sm) {
                        Image(systemName: "doc.plaintext")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.orange)

                        Text("Raw OCR TSV")
                            .font(.titleS)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    }

                    Text("This is the original OCR output before any preprocessing is applied.")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    ScrollView([.horizontal, .vertical]) {
                        Text(tsvData)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(Layout.Spacing.md)
                            .background(AppColors.surface)
                            .cornerRadius(Layout.CornerRadius.sm)
                    }
                    .frame(maxHeight: 400)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .stroke(AppColors.separator, lineWidth: 1)
                    )
                }
            } else {
                missingOCRState
            }
        }
        .padding(Layout.Spacing.lg)
        .padding(.bottom, 80) // Add bottom padding for tab bar
    }

    private var processedOCRTabContent: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            if let tsvData = importViewModel.parserInputText, !tsvData.isEmpty {
                VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                    HStack(spacing: Layout.Spacing.sm) {
                        Image(systemName: "eye.trianglebadge.exclamationmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                        
                        Text("OCR TSV Data Sent to AI")
                            .font(.titleS)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    Text("This is the preprocessed OCR data returned by the parser service with event markers ready for the AI call.")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

                    ScrollView([.horizontal, .vertical]) {
                        Text(importViewModel.preprocessedParserInputText ?? tsvData)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(Layout.Spacing.md)
                            .background(AppColors.surface)
                            .cornerRadius(Layout.CornerRadius.sm)
                    }
                    .frame(maxHeight: 400)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .stroke(AppColors.separator, lineWidth: 1)
                    )
                }
            } else {
                missingOCRState
            }
        }
        .padding(Layout.Spacing.lg)
        .padding(.bottom, 80) // Add bottom padding for tab bar
    }

    private var missingOCRState: some View {
        VStack(spacing: Layout.Spacing.md) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            Text("No OCR data available yet")
                .font(.titleS)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            Text("Import a PDF to see the OCR-extracted structured data here.")
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(Layout.Spacing.xl)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .stroke(AppColors.separator, lineWidth: 1)
        )
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            ForEach(events) { event in
                PreviewEventCard(event: event)
                    .onTapGesture { editingEvent = event }
            }
        }
    }
}

// MARK: - Event Card

struct PreviewEventCard: View {
    let event: EventItem

    private var eventColor: Color {
        switch event.type {
        case .assignment: return Color.orange
        case .quiz: return Color.yellow
        case .midterm: return Color.pink
        case .final: return Color.red
        case .lab: return Color.green
        case .lecture: return Color.blue
        case .other: return AppColors.accent
        }
    }

    private var iconName: String {
        switch event.type {
        case .assignment: return "doc.text"
        case .quiz: return "questionmark.circle"
        case .midterm: return "graduationcap"
        case .final: return "rosette"
        case .lab: return "flask"
        case .lecture: return "person.fill"
        case .other: return "bookmark"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    private static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    private func formatEventTime(_ event: EventItem) -> String {
        if event.allDay == true {
            // Show date followed by "All Day"
            let dateString = Self.dateOnlyFormatter.string(from: event.start)
            return "\(dateString), All Day"
        }
        
        if let recurrenceRule = event.recurrenceRule {
            // For recurring events, show pattern instead of specific date
            let dayPattern = extractDayPattern(from: recurrenceRule)
            let timeString = Self.timeOnlyFormatter.string(from: event.start)
            
            if let end = event.end {
                let endTimeString = Self.timeOnlyFormatter.string(from: end)
                return "\(dayPattern) \(timeString)-\(endTimeString)"
            } else {
                return "\(dayPattern) \(timeString)"
            }
        } else {
            // For single events, show full date and time
            return Self.dateFormatter.string(from: event.start)
        }
    }
    
    private func extractDayPattern(from rrule: String) -> String {
        // Extract BYDAY from RRULE format like "FREQ=WEEKLY;BYDAY=TU,TH;UNTIL=2025-12-12"
        guard let byDayRange = rrule.range(of: "BYDAY=") else {
            return "Weekly"
        }
        
        let afterByDay = String(rrule[byDayRange.upperBound...])
        let endIndex = afterByDay.firstIndex(of: ";") ?? afterByDay.endIndex
        let dayString = String(afterByDay[..<endIndex])
        
        // Convert day codes to readable format
        let dayMap: [String: String] = [
            "MO": "Mon", "TU": "Tue", "WE": "Wed", "TH": "Thu", 
            "FR": "Fri", "SA": "Sat", "SU": "Sun"
        ]
        
        let days = dayString.components(separatedBy: ",")
        let readableDays = days.compactMap { dayMap[$0.trimmingCharacters(in: .whitespaces)] }
        
        if readableDays.isEmpty {
            return "Weekly"
        } else if readableDays.count <= 2 {
            return readableDays.joined(separator: "/")
        } else {
            return readableDays.joined(separator: ", ")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            HStack(alignment: .center, spacing: Layout.Spacing.md) {
                VStack(alignment: .center, spacing: Layout.Spacing.xs) {
                    Text(Self.dayFormatter.string(from: event.start))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppColors.textSecondary)
                    Text(Self.shortDateFormatter.string(from: event.start))
                        .font(.titleS)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                }
                .frame(width: 54)

                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    HStack(spacing: Layout.Spacing.xs) {
                        Image(systemName: iconName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(eventColor)

                        Text(event.type.rawValue.capitalized)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(eventColor)
                            .padding(.horizontal, Layout.Spacing.xs)
                            .padding(.vertical, 2)
                            .background(eventColor.opacity(0.12))
                            .cornerRadius(Layout.CornerRadius.xs)
                        
                        Spacer()
                        
                        Text(event.courseCode)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accent)
                    }

                    Text(event.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: Layout.Spacing.xs) {
                        Text(formatEventTime(event))
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                        
                        if event.recurrenceRule != nil {
                            Image(systemName: "repeat")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.accent)
                        }
                    }

                    if let location = event.location, !location.isEmpty {
                        HStack(spacing: Layout.Spacing.xs) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                            Text(location)
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    if let notes = event.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundColor(AppColors.textTertiary)
                            .lineLimit(3)
                    }
                }
            }
            .padding(Layout.Spacing.md)
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                    .stroke(AppColors.separator, lineWidth: 1)
            )
            .cardShadowLight()
        }
    }
}

// MARK: - Empty State

private struct PreviewEmptyStateView: View {
    var body: some View {
        VStack(spacing: Layout.Spacing.md) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            Text("No events to show yet")
                .font(.titleS)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            Text("Import a syllabus to see extracted assignments, quizzes, and exams here.")
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(Layout.Spacing.xl)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .stroke(AppColors.separator, lineWidth: 1)
        )
    }
}

// MARK: - AI Output Views

private struct AIOutputView: View {
    let rawResponse: String
    @State private var isExpanded: Bool = false
    
    private var formattedJSON: String {
        // Try to format the JSON for better readability
        if let data = rawResponse.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return prettyString
        }
        return rawResponse
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack(spacing: Layout.Spacing.sm) {
                Image(systemName: "brain")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Raw AI Response")
                    .font(.titleS)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                HStack(spacing: Layout.Spacing.sm) {
                    if isExpanded {
                        Button(action: {
                            UIPasteboard.general.string = rawResponse
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button(action: { isExpanded.toggle() }) {
                        Text(isExpanded ? "Collapse" : "Expand")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            Text("This shows the raw JSON response from the AI parser for debugging purposes.")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
            
            if isExpanded {
                ScrollView([.horizontal, .vertical]) {
                    Text(formattedJSON)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppColors.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(Layout.Spacing.md)
                        .background(AppColors.surface)
                        .cornerRadius(Layout.CornerRadius.sm)
                }
                .frame(maxHeight: 400)
                .frame(maxWidth: .infinity)
            } else {
                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    Text(String(rawResponse.prefix(500)) + (rawResponse.count > 500 ? "..." : ""))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if rawResponse.count > 500 {
                        Text("Tap 'Expand' to see full response")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                            .italic()
                    }
                }
                .padding(Layout.Spacing.md)
                .background(AppColors.surface)
                .cornerRadius(Layout.CornerRadius.sm)
            }
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                .stroke(AppColors.separator, lineWidth: 1)
        )
    }
}

private struct AIOutputEmptyStateView: View {
    var body: some View {
        VStack(spacing: Layout.Spacing.md) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            Text("No AI output yet")
                .font(.titleS)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)

            Text("Import a syllabus with AI parsing to see the raw AI response here.")
                .font(.body)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Layout.Spacing.lg)
        }
        .frame(maxWidth: .infinity)
        .padding(Layout.Spacing.xl)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .stroke(AppColors.separator, lineWidth: 1)
        )
    }
}
