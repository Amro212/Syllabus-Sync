//
//  PreviewView.swift
//  Syllabus Sync
//

import SwiftUI
import UIKit

struct PreviewView: View {
    @EnvironmentObject var importViewModel: ImportViewModel
    @State private var selectedTab: PreviewTab = .events

    private var events: [EventItem] { importViewModel.events }
    
    enum PreviewTab: String, CaseIterable {
        case events = "Events"
        case aiOutput = "AI Output"
        
        var icon: String {
            switch self {
            case .events: return "calendar"
            case .aiOutput: return "brain"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                headerSection
                    .padding(Layout.Spacing.lg)
                
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
                    case .aiOutput:
                        aiOutputTabContent
                    }
                }
                .background(AppColors.background)
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
    }

    private var eventsSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            ForEach(events) { event in
                PreviewEventCard(event: event)
            }
        }
    }
}

// MARK: - Event Card

private struct PreviewEventCard: View {
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
                    }

                    Text(event.title)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)

                    Text(Self.dateFormatter.string(from: event.start))
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)

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
