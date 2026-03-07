//
//  CourseCardView.swift
//  Syllabus Sync
//
//  Compact card that shows a course with color bar, event count badge,
//  and a mini grading weight bar. Tappable to navigate to CourseDetailView.
//

import SwiftUI

struct CourseCardView: View {
    let course: Course
    let eventCount: Int
    let gradingEntries: [GradingSchemeEntry]
    let onTap: () -> Void

    private var courseColor: Color {
        if let hex = course.colorHex {
            return Color(hex: hex)
        }
        return AppColors.accent
    }

    private var totalWeight: Double {
        min(gradingEntries.compactMap(\.weight).reduce(0, +), 1.0)
    }

    var body: some View {
        Button(action: {
            HapticFeedbackManager.shared.lightImpact()
            onTap()
        }) {
            VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                // Color bar + code
                HStack(spacing: Layout.Spacing.sm) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(courseColor)
                        .frame(width: 4, height: 28)

                    Text(course.code)
                        .font(.captionL)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                }

                // Title
                Text(course.title ?? course.code)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)

                // Mini grading bar (if entries exist)
                if !gradingEntries.isEmpty {
                    VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                        HStack(spacing: 1) {
                            ForEach(gradingEntries) { entry in
                                if let weight = entry.weight, weight > 0 {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(colorForType(entry.type))
                                        .frame(height: 4)
                                        .frame(maxWidth: .infinity)
                                        .scaleEffect(x: weight / max(totalWeight, 0.01), anchor: .leading)
                                }
                            }
                        }
                        .frame(height: 4)
                        .clipShape(.rect(cornerRadius: 2))

                        Text("\(Int(totalWeight * 100))% graded")
                            .font(.captionS)
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }

                // Bottom row: event count
                HStack(spacing: Layout.Spacing.xs) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textTertiary)

                    Text("\(eventCount) event\(eventCount == 1 ? "" : "s")")
                        .font(.captionS)
                        .foregroundStyle(AppColors.textTertiary)

                    if let instructor = course.instructor, !instructor.isEmpty {
                        Spacer()
                        Text(instructor)
                            .font(.captionS)
                            .foregroundStyle(AppColors.textTertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(Layout.Spacing.md)
            .frame(width: 180, height: 180)
            .background(AppColors.surface)
            .clipShape(.rect(cornerRadius: Layout.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                    .stroke(AppColors.border, lineWidth: 1)
            )
            .cardShadowLight()
        }
        .buttonStyle(.plain)
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
}

// MARK: - Preview

#if DEBUG
struct CourseCardView_Previews: PreviewProvider {
    static var previews: some View {
        CourseCardView(
            course: Course(code: "CS 101", title: "Intro to Computer Science", colorHex: "#3478F6", instructor: "Dr. Chen"),
            eventCount: 12,
            gradingEntries: [
                GradingSchemeEntry(name: "Assignments", weight: 0.3, type: "ASSIGNMENT"),
                GradingSchemeEntry(name: "Midterm", weight: 0.25, type: "MIDTERM"),
                GradingSchemeEntry(name: "Final", weight: 0.35, type: "FINAL"),
                GradingSchemeEntry(name: "Labs", weight: 0.1, type: "LAB")
            ],
            onTap: {}
        )
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
