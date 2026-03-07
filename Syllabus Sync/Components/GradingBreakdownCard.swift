//
//  GradingBreakdownCard.swift
//  Syllabus Sync
//
//  Displays the extracted grading scheme as a visual breakdown card.
//  Shows each graded component with its weight and type.
//

import SwiftUI

struct GradingBreakdownCard: View {
    let entries: [GradingSchemeEntry]
    /// Optional edit callback. When provided, shows a pencil icon in the header.
    var onEdit: (() -> Void)? = nil

    /// Total of all extracted weights (may be < 1.0 if scheme is partial).
    /// Capped at 1.0 to prevent display glitches from parent/child overlap.
    private var totalWeight: Double {
        min(entries.compactMap(\.weight).reduce(0, +), 1.0)
    }

    /// Raw sum before capping — used to detect overflow.
    private var rawTotalWeight: Double {
        entries.compactMap(\.weight).reduce(0, +)
    }

    private var hasWeights: Bool {
        entries.contains { $0.weight != nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            // Header
            HStack(spacing: Layout.Spacing.xs) {
                Image(systemName: "chart.pie.fill")
                    .font(.lexend(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.accent)

                Text("Grading Breakdown")
                    .font(.titleS)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                if hasWeights {
                    HStack(spacing: 2) {
                        if rawTotalWeight > 1.02 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        Text("\(Int(min(rawTotalWeight, 1.0) * 100))% total")
                            .font(.caption)
                            .foregroundStyle(rawTotalWeight > 1.02 ? .orange : AppColors.textSecondary)
                    }
                }

                if let onEdit {
                    Button {
                        HapticFeedbackManager.shared.lightImpact()
                        onEdit()
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.lexend(size: 20, weight: .regular))
                            .foregroundStyle(AppColors.accent)
                    }
                    .buttonStyle(.plain)
                }
            }

            if entries.isEmpty {
                // Empty state — invite user to add grading
                Button {
                    HapticFeedbackManager.shared.lightImpact()
                    onEdit?()
                } label: {
                    HStack(spacing: Layout.Spacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.lexend(size: 18, weight: .medium))
                            .foregroundStyle(AppColors.accent)
                        Text("Add grading scheme")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(AppColors.accent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Layout.Spacing.md)
                    .background(AppColors.accent.opacity(0.08))
                    .clipShape(.rect(cornerRadius: Layout.CornerRadius.md))
                }
                .buttonStyle(.plain)
            } else {
                // Weight bar (stacked horizontal)
                if hasWeights {
                    GeometryReader { geo in
                        HStack(spacing: 1) {
                            ForEach(entries) { entry in
                                if let weight = entry.weight, weight > 0 {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(colorForType(entry.type))
                                        .frame(width: max(geo.size.width * weight / max(totalWeight, 0.01), 4))
                                }
                            }
                        }
                    }
                    .frame(height: 8)
                    .clipShape(.rect(cornerRadius: 4))
                }

                // Entry rows
                VStack(spacing: Layout.Spacing.xs) {
                    ForEach(entries) { entry in
                        HStack(spacing: Layout.Spacing.sm) {
                            Circle()
                                .fill(colorForType(entry.type))
                                .frame(width: 8, height: 8)

                            Text(entry.name)
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            if let weight = entry.weight {
                                Text("\(Int(weight * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .monospacedDigit()
                            } else {
                                Text("—")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
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
    }

    // MARK: - Helpers

    private func colorForType(_ rawType: String) -> Color {
        switch rawType {
        case "ASSIGNMENT": return .orange
        case "QUIZ":       return .yellow
        case "MIDTERM":    return .pink
        case "FINAL":      return .red
        case "LAB":        return .green
        case "LECTURE":    return .blue
        case "TUTORIAL":   return .teal
        case "OTHER":      return AppColors.accent
        default:           return .gray
        }
    }
}
