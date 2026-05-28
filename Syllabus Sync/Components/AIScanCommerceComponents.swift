//
//  AIScanCommerceComponents.swift
//  Syllabus Sync
//

import SwiftUI

struct AIScanUsagePill: View {
    let snapshot: AIScanUsageSnapshot?

    var body: some View {
        HStack(spacing: Layout.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.lexend(size: 13, weight: .semibold))
                .foregroundColor(AppColors.accent)

            Text(label)
                .font(.lexend(size: 13, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, Layout.Spacing.md)
        .frame(height: 36)
        .background(
            Capsule()
                .fill(AppColors.surface)
                .overlay(
                    Capsule()
                        .stroke(AppColors.border.opacity(0.45), lineWidth: 1)
                )
        )
    }

    private var label: String {
        guard let snapshot else { return "Checking AI scans" }
        if snapshot.totalRemaining > 0 {
            return snapshot.totalRemaining == 1 ? "1 scan left" : "\(snapshot.totalRemaining) scans left"
        }
        return "Unlock 5 more scans"
    }
}

struct AIScanInlineCard: View {
    let snapshot: AIScanUsageSnapshot?
    let isBusy: Bool
    let onPurchase: () -> Void
    let onSync: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    Text("AI SCANS")
                        .font(.lexend(size: 11, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                        .tracking(0.6)

                    Text(snapshot?.heroLine ?? "Checking AI scans")
                        .font(.lexend(size: 20, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)

                    Text(snapshot?.freeLine ?? "First 2 scans are free")
                        .font(.lexend(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(AIScanCommerceConfig.compareAtPrice)
                        .font(.lexend(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textTertiary)
                        .strikethrough()

                    Text(AIScanCommerceConfig.salePrice)
                        .font(.lexend(size: 24, weight: .bold))
                        .foregroundColor(AppColors.accent)
                }
            }

            HStack(spacing: Layout.Spacing.sm) {
                benefitChip("Deadlines")
                benefitChip("Exams")
                benefitChip("Grading")
            }

            HStack(spacing: Layout.Spacing.sm) {
                Button(action: onPurchase) {
                    HStack(spacing: Layout.Spacing.sm) {
                        if isBusy {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(AppColors.background)
                        } else {
                            Image(systemName: "cart.fill")
                                .font(.lexend(size: 14, weight: .semibold))
                        }
                        Text("Get 5 scans")
                            .font(.lexend(size: 15, weight: .bold))
                    }
                    .foregroundColor(AppColors.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                            .fill(AppColors.accent)
                    )
                }
                .disabled(isBusy)

                Button(action: onSync) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.lexend(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 50, height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                                .fill(AppColors.surfaceSecondary)
                        )
                }
                .disabled(isBusy)
                .accessibilityLabel("Sync purchases")
            }
        }
        .padding(Layout.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                        .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func benefitChip(_ text: String) -> some View {
        Text(text)
            .font(.lexend(size: 12, weight: .semibold))
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, Layout.Spacing.sm)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(AppColors.surfaceSecondary)
            )
    }
}

struct AIScanPaywallPopup: View {
    let snapshot: AIScanUsageSnapshot?
    let isPurchasing: Bool
    let errorMessage: String?
    let onPurchase: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("LIMITED OFFER")
                    .font(.lexend(size: 11, weight: .bold))
                    .foregroundColor(AppColors.background)
                    .padding(.horizontal, Layout.Spacing.sm)
                    .frame(height: 26)
                    .background(
                        Capsule()
                            .fill(AppColors.accent)
                    )

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.lexend(size: 14, weight: .bold))
                        .foregroundColor(AppColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(AppColors.surfaceSecondary)
                        )
                }
            }
            .padding(.bottom, Layout.Spacing.lg)

            VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
                Text("Scan 5 more syllabi in seconds")
                    .font(.lexend(size: 28, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Text("Keep instant syllabus-to-calendar sync going without manual date entry.")
                    .font(.lexend(size: 15, weight: .medium))
                    .foregroundColor(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .lastTextBaseline, spacing: Layout.Spacing.sm) {
                Text(AIScanCommerceConfig.compareAtPrice)
                    .font(.lexend(size: 18, weight: .medium))
                    .foregroundColor(AppColors.textTertiary)
                    .strikethrough()

                Text(AIScanCommerceConfig.salePrice)
                    .font(.lexend(size: 34, weight: .bold))
                    .foregroundColor(AppColors.accent)

                Text("for \(AIScanCommerceConfig.packCredits) scans")
                    .font(.lexend(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.bottom, 4)
            }
            .padding(.top, Layout.Spacing.lg)

            VStack(spacing: Layout.Spacing.sm) {
                paywallBenefit("assignment turn-ins and exam dates in one import")
                paywallBenefit("grading breakdown pulled into course view")
                paywallBenefit(snapshot?.freeLine ?? "first 2 scans already included free")
            }
            .padding(.top, Layout.Spacing.lg)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.lexend(size: 13, weight: .medium))
                    .foregroundColor(AppColors.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Layout.Spacing.md)
            }

            Button(action: onPurchase) {
                HStack(spacing: Layout.Spacing.sm) {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(AppColors.background)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.lexend(size: 16, weight: .bold))
                    }

                    Text(isPurchasing ? "Contacting App Store..." : "Get 5 scans")
                        .font(.lexend(size: 16, weight: .bold))
                }
                .foregroundColor(AppColors.background)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                        .fill(AppColors.accent)
                )
            }
            .disabled(isPurchasing)
            .padding(.top, Layout.Spacing.xl)

            Text("Purchase handled by App Store. Credits apply to this account.")
                .font(.lexend(size: 11, weight: .medium))
                .foregroundColor(AppColors.textTertiary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Layout.Spacing.md)
        }
        .padding(Layout.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.xl)
                .fill(AppColors.background)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.CornerRadius.xl)
                        .stroke(AppColors.border.opacity(0.35), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 16)
        )
        .padding(.horizontal, Layout.Spacing.lg)
    }

    private func paywallBenefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Layout.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.lexend(size: 14, weight: .bold))
                .foregroundColor(AppColors.accent)
                .padding(.top, 2)

            Text(text)
                .font(.lexend(size: 14, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
