//
//  CourseChipView.swift
//  Syllabus Sync
//
//  Compact course pill for the Dashboard. Shows course code + event count
//  in a tappable capsule-style chip.
//

import SwiftUI

struct CourseChipView: View {
    let course: Course
    let eventCount: Int
    let onTap: () -> Void

    private var courseColor: Color {
        if let hex = course.colorHex {
            return Color(hex: hex)
        }
        return AppColors.accent
    }

    var body: some View {
        Button {
            HapticFeedbackManager.shared.lightImpact()
            onTap()
        } label: {
            HStack(spacing: Layout.Spacing.sm) {
                // Color indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(courseColor)
                    .frame(width: 4, height: 20)

                // Course code
                Text(course.code)
                    .font(.captionL)
                    .fontWeight(.semibold)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)

                // Event count badge
                if eventCount > 0 {
                    Text("\(eventCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textTertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(AppColors.surfaceSecondary)
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(AppColors.textTertiary)
            }
            .padding(.horizontal, Layout.Spacing.md)
            .padding(.vertical, Layout.Spacing.sm)
            .background(AppColors.surface)
            .clipShape(.rect(cornerRadius: Layout.CornerRadius.xl))
            .overlay(
                RoundedRectangle(cornerRadius: Layout.CornerRadius.xl)
                    .stroke(AppColors.border, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct CourseChipView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: Layout.Spacing.sm) {
            CourseChipView(
                course: Course(code: "CIS*2750", colorHex: "#34C759"),
                eventCount: 7,
                onTap: {}
            )
            CourseChipView(
                course: Course(code: "ENGG*4540", colorHex: "#FF9500"),
                eventCount: 6,
                onTap: {}
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
