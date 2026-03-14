//
//  CourseChipView.swift
//  Syllabus Sync
//
//  Compact course card for the Dashboard. Shows course code and a quick
//  status summary in a tappable horizontal rail item.
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
            VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                HStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(courseColor.opacity(0.16))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "book.closed.fill")
                                .font(.lexend(size: 16, weight: .semibold))
                                .foregroundStyle(courseColor)
                        }

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.captionL)
                        .foregroundStyle(AppColors.textTertiary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(course.code)
                        .font(.body)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(course.title ?? "\(eventCount) upcoming item\(eventCount == 1 ? "" : "s")")
                        .font(.captionL)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: Layout.Spacing.xs) {
                    Text(eventCount == 0 ? "No upcoming items" : "\(eventCount) upcoming")
                        .font(.captionL)
                        .foregroundStyle(eventCount == 0 ? AppColors.textSecondary : courseColor)
                        .padding(.horizontal, Layout.Spacing.sm)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill((eventCount == 0 ? AppColors.surfaceSecondary : courseColor.opacity(0.12)))
                        )

                    Spacer()
                }
            }
            .frame(width: 184, alignment: .leading)
            .padding(Layout.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(AppColors.surfaceSecondary.opacity(0.6))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppColors.border.opacity(0.4), lineWidth: 1)
                    }
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
