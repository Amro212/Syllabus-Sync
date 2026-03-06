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

    /// Total of all extracted weights (may be < 1.0 if scheme is partial).
    private var totalWeight: Double {
        entries.compactMap(\.weight).reduce(0, +)
    }

    private var hasWeights: Bool {
        entries.contains { $0.weight != nil }
    }

    var body: some View {
        if entries.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                // Header
                HStack(spacing: Layout.Spacing.xs) {
                    Image(systemName: "chart.pie.fill")
                        .font(.lexend(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.accent)

                    Text("Grading Breakdown")
                        .font(.titleS)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer()

                    if hasWeights {
                        Text("\(Int(totalWeight * 100))% total")
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

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
                    .clipShape(RoundedRectangle(cornerRadius: 4))
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
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(1)

                            Spacer()

                            if let weight = entry.weight {
                                Text("\(Int(weight * 100))%")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                    .monospacedDigit()
                            } else {
                                Text("—")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                }
            }
            .padding(Layout.Spacing.md)
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                    .stroke(AppColors.border, lineWidth: 1)
            )
        }
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
