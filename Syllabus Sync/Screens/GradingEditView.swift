//
//  GradingEditView.swift
//  Syllabus Sync
//
//  Sheet for editing grading breakdown entries for a course.
//  Supports add, remove, reorder, and inline editing of name/weight/type.
//

import SwiftUI

struct GradingEditView: View {
    let courseId: String
    let entries: [GradingSchemeEntry]

    @EnvironmentObject var gradingRepository: GradingRepository
    @Environment(\.dismiss) private var dismiss

    @State private var editableEntries: [EditableGradingEntry] = []
    @State private var isSaving = false
    @State private var showingDeleteConfirm = false
    @State private var entryToDelete: EditableGradingEntry?

    // MARK: - Derived

    private var totalWeight: Double {
        editableEntries.compactMap(\.weight).reduce(0, +)
    }

    private var totalPercent: Int {
        Int(totalWeight * 100)
    }

    private var weightWarning: String? {
        let pct = totalPercent
        if pct == 0 { return nil }
        if pct < 100 { return "Total is \(pct)% — \(100 - pct)% unaccounted" }
        if pct > 100 { return "Total exceeds 100% by \(pct - 100)%" }
        return nil
    }

    private var hasChanges: Bool {
        let current = editableEntries.map { $0.toGradingSchemeEntry(courseId: courseId) }
        return current != entries
    }

    // MARK: - Body

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Layout.Spacing.lg) {
                        // Weight summary
                        weightSummaryCard

                        // Entries
                        if editableEntries.isEmpty {
                            emptyState
                        } else {
                            entriesList
                        }
                    }
                    .padding(Layout.Spacing.lg)
                    .padding(.bottom, Layout.Spacing.xxxl)
                }
            }
            .navigationTitle("Edit Grading")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveEntries() }
                        .foregroundStyle(AppColors.accent)
                        .fontWeight(.semibold)
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .bottomBar) {
                    addEntryButton
                }
            }
        }
        .onAppear { loadEntries() }
        .alert("Remove Entry?", isPresented: $showingDeleteConfirm) {
            Button("Remove", role: .destructive) {
                if let entry = entryToDelete {
                    removeEntry(entry)
                }
            }
            Button("Cancel", role: .cancel) {
                entryToDelete = nil
            }
        } message: {
            if let entry = entryToDelete {
                Text("Remove \"\(entry.name)\" from the grading breakdown?")
            }
        }
    }

    // MARK: - Weight Summary

    private var weightSummaryCard: some View {
        VStack(spacing: Layout.Spacing.sm) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.lexend(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.accent)

                Text("Weight Summary")
                    .font(.titleS)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Text("\(totalPercent)%")
                    .font(.titleS)
                    .fontWeight(.bold)
                    .foregroundStyle(totalPercent == 100 ? .green : (totalPercent > 100 ? .red : AppColors.accent))
                    .monospacedDigit()
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.surfaceSecondary)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(totalPercent == 100 ? Color.green : (totalPercent > 100 ? Color.red : AppColors.accent))
                        .frame(width: min(geo.size.width * totalWeight, geo.size.width))
                        .animation(.easeInOut(duration: 0.3), value: totalWeight)
                }
            }
            .frame(height: 6)

            if let warning = weightWarning {
                HStack(spacing: Layout.Spacing.xs) {
                    Image(systemName: totalPercent > 100 ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .font(.caption)
                    Text(warning)
                        .font(.caption)
                }
                .foregroundStyle(totalPercent > 100 ? .red : AppColors.textSecondary)
            }
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .clipShape(.rect(cornerRadius: Layout.CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .stroke(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Entries List

    private var entriesList: some View {
        VStack(spacing: Layout.Spacing.sm) {
            ForEach($editableEntries) { $entry in
                GradingEntryRow(
                    entry: $entry,
                    onDelete: {
                        entryToDelete = entry
                        showingDeleteConfirm = true
                    }
                )
            }
            .onMove { source, destination in
                editableEntries.move(fromOffsets: source, toOffset: destination)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Layout.Spacing.md) {
            Image(systemName: "chart.pie")
                .font(.system(size: 40))
                .foregroundStyle(AppColors.textTertiary)

            Text("No grading entries")
                .font(.titleS)
                .fontWeight(.semibold)
                .foregroundStyle(AppColors.textSecondary)

            Text("Tap the button below to add your first entry.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Layout.Spacing.xxxl)
    }

    // MARK: - Add Button

    private var addEntryButton: some View {
        Button {
            HapticFeedbackManager.shared.lightImpact()
            addEntry()
        } label: {
            HStack(spacing: Layout.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.lexend(size: 18, weight: .semibold))
                Text("Add Entry")
                    .font(.body)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(AppColors.accent)
        }
    }

    // MARK: - Actions

    private func loadEntries() {
        editableEntries = entries.enumerated().map { index, entry in
            EditableGradingEntry(from: entry, sortOrder: index)
        }
    }

    private func addEntry() {
        let new = EditableGradingEntry(
            id: UUID().uuidString,
            name: "",
            weight: nil,
            type: "OTHER",
            sortOrder: editableEntries.count
        )
        withAnimation(.easeInOut(duration: 0.2)) {
            editableEntries.append(new)
        }
    }

    private func removeEntry(_ entry: EditableGradingEntry) {
        withAnimation(.easeInOut(duration: 0.2)) {
            editableEntries.removeAll { $0.id == entry.id }
        }
        entryToDelete = nil
    }

    private func saveEntries() {
        isSaving = true
        HapticFeedbackManager.shared.mediumImpact()

        let domain = editableEntries.enumerated().map { index, entry in
            GradingSchemeEntry(
                id: entry.id,
                name: entry.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : entry.name.trimmingCharacters(in: .whitespaces),
                weight: entry.weight,
                type: entry.type,
                courseId: courseId,
                sortOrder: index
            )
        }

        Task {
            await gradingRepository.save(entries: domain, forCourseId: courseId)
            await MainActor.run {
                isSaving = false
                HapticFeedbackManager.shared.success()
                dismiss()
            }
        }
    }
}

// MARK: - Editable Entry Model

struct EditableGradingEntry: Identifiable, Equatable {
    let id: String
    var name: String
    var weight: Double?
    var type: String
    var sortOrder: Int

    init(id: String = UUID().uuidString, name: String, weight: Double?, type: String, sortOrder: Int) {
        self.id = id
        self.name = name
        self.weight = weight
        self.type = type
        self.sortOrder = sortOrder
    }

    init(from entry: GradingSchemeEntry, sortOrder: Int) {
        self.id = entry.id
        self.name = entry.name
        self.weight = entry.weight
        self.type = entry.type
        self.sortOrder = entry.sortOrder ?? sortOrder
    }

    func toGradingSchemeEntry(courseId: String) -> GradingSchemeEntry {
        GradingSchemeEntry(
            id: id,
            name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled" : name.trimmingCharacters(in: .whitespaces),
            weight: weight,
            type: type,
            courseId: courseId,
            sortOrder: sortOrder
        )
    }
}

// MARK: - Grading Entry Row

private struct GradingEntryRow: View {
    @Binding var entry: EditableGradingEntry
    let onDelete: () -> Void

    @State private var weightText: String = ""
    @FocusState private var isNameFocused: Bool
    @FocusState private var isWeightFocused: Bool

    private let typeOptions: [(label: String, value: String)] = [
        ("Assignment", "ASSIGNMENT"),
        ("Quiz", "QUIZ"),
        ("Midterm", "MIDTERM"),
        ("Final", "FINAL"),
        ("Lab", "LAB"),
        ("Lecture", "LECTURE"),
        ("Tutorial", "TUTORIAL"),
        ("Other", "OTHER")
    ]

    var body: some View {
        VStack(spacing: Layout.Spacing.sm) {
            // Name + delete
            HStack {
                TextField("Entry name", text: $entry.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textPrimary)
                    .focused($isNameFocused)

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.lexend(size: 18, weight: .regular))
                        .foregroundStyle(AppColors.textTertiary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: Layout.Spacing.md) {
                // Weight field
                HStack(spacing: Layout.Spacing.xs) {
                    TextField("0", text: $weightText)
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundStyle(AppColors.textPrimary)
                        .keyboardType(.decimalPad)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                        .focused($isWeightFocused)
                        .onChange(of: weightText) { newValue in
                            if let val = Double(newValue), val >= 0, val <= 100 {
                                entry.weight = val / 100.0
                            } else if newValue.isEmpty {
                                entry.weight = nil
                            }
                        }

                    Text("%")
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.horizontal, Layout.Spacing.sm)
                .padding(.vertical, Layout.Spacing.xs)
                .background(AppColors.surfaceSecondary)
                .clipShape(.rect(cornerRadius: Layout.CornerRadius.sm))

                // Type picker
                Menu {
                    ForEach(typeOptions, id: \.value) { option in
                        Button {
                            entry.type = option.value
                        } label: {
                            HStack {
                                Text(option.label)
                                if entry.type == option.value {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: Layout.Spacing.xs) {
                        Circle()
                            .fill(colorForType(entry.type))
                            .frame(width: 8, height: 8)

                        Text(labelForType(entry.type))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(AppColors.textSecondary)

                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(.horizontal, Layout.Spacing.sm)
                    .padding(.vertical, Layout.Spacing.xs)
                    .background(AppColors.surfaceSecondary)
                    .clipShape(.rect(cornerRadius: Layout.CornerRadius.sm))
                }
            }
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .clipShape(.rect(cornerRadius: Layout.CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .onAppear {
            if let w = entry.weight {
                weightText = String(Int(w * 100))
            }
        }
    }

    private func colorForType(_ raw: String) -> Color {
        switch raw {
        case "ASSIGNMENT": return .orange
        case "QUIZ":       return .yellow
        case "MIDTERM":    return .pink
        case "FINAL":      return .red
        case "LAB":        return .green
        case "LECTURE":    return .blue
        case "TUTORIAL":   return .teal
        default:           return .gray
        }
    }

    private func labelForType(_ raw: String) -> String {
        switch raw {
        case "ASSIGNMENT": return "Assignment"
        case "QUIZ":       return "Quiz"
        case "MIDTERM":    return "Midterm"
        case "FINAL":      return "Final"
        case "LAB":        return "Lab"
        case "LECTURE":    return "Lecture"
        case "TUTORIAL":   return "Tutorial"
        default:           return "Other"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct GradingEditView_Previews: PreviewProvider {
    static var previews: some View {
        GradingEditView(
            courseId: "preview-123",
            entries: [
                GradingSchemeEntry(name: "Assignments", weight: 0.3, type: "ASSIGNMENT"),
                GradingSchemeEntry(name: "Midterm", weight: 0.25, type: "MIDTERM"),
                GradingSchemeEntry(name: "Final Exam", weight: 0.35, type: "FINAL"),
                GradingSchemeEntry(name: "Labs", weight: 0.1, type: "LAB")
            ]
        )
        .environmentObject(GradingRepository())
    }
}
#endif
