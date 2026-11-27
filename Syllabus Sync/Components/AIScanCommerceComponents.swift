//
//  AIScanCommerceComponents.swift
//  Syllabus Sync
//

import SwiftUI

struct AIScanCommerceCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject private var usageStore: AIScanUsageStore

    var usageOverride: AIScanUsageSnapshot?
    var onCreditsAvailable: (() -> Void)?
    var onDismiss: (() -> Void)?

    private var usage: AIScanUsageSnapshot? {
        usageOverride ?? usageStore.snapshot
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack(alignment: .top, spacing: Layout.Spacing.sm) {
                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    Text(usage?.canScan == false ? "You’re out of AI scans" : "AI syllabus scans")
                        .font(.titleL.bold())
                        .foregroundStyle(AppColors.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    Text("Turn a syllabus PDF into reminders for assignments, quizzes, and exams.")
                        .font(.body)
                        .foregroundStyle(AppColors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AppColors.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(AppColors.surfaceSecondary, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
            }

            HStack(spacing: Layout.Spacing.md) {
                packDetails
                Spacer(minLength: 0)
                if !dynamicTypeSize.isAccessibilitySize {
                    AIScanPromoArtwork()
                }
            }
            .padding(Layout.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surfaceSecondary, in: .rect(cornerRadius: Layout.CornerRadius.lg))

            if let message = usageStore.lastErrorMessage {
                Label(message, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            actions
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface, in: .rect(cornerRadius: Layout.CornerRadius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: Layout.CornerRadius.xl)
                .strokeBorder(AppColors.border.opacity(0.45), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .task {
            async let price: Void = usageStore.loadProduct()
            async let balance: Void = usageStore.refresh(force: false)
            _ = await (price, balance)
        }
    }

    private var packDetails: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
            Text("\(AIScanCommerceConfig.packCredits) AI scans")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            if usageStore.snapshot?.purchasesAvailable == false {
                Text("Purchases are temporarily unavailable")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            } else if let price = usageStore.displayPrice {
                Text(price)
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.accent)
            } else if usageStore.isLoadingProduct {
                ProgressView("Checking price…")
                    .font(.footnote)
            } else {
                Text("Price unavailable")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Text("One-time purchase")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)

            if let usage {
                Text(usage.heroLine)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: Layout.Spacing.xs) {
            Button {
                Task {
                    if usageStore.canPurchase {
                        if await usageStore.purchaseTopUp() {
                            onCreditsAvailable?()
                        }
                    } else {
                        async let price: Void = usageStore.loadProduct()
                        async let balance: Void = usageStore.refresh()
                        _ = await (price, balance)
                    }
                }
            } label: {
                HStack(spacing: Layout.Spacing.xs) {
                    if usageStore.isPurchasing {
                        ProgressView()
                            .tint(AppColors.background)
                    }
                    Text(purchaseButtonTitle)
                        .font(.headline)
                }
                .foregroundStyle(AppColors.background)
                .frame(maxWidth: .infinity, minHeight: 50)
                .padding(.horizontal, Layout.Spacing.sm)
                .background(AppColors.accent, in: .rect(cornerRadius: Layout.CornerRadius.lg))
            }
            .buttonStyle(.plain)
            .disabled(usageStore.isPurchasing || usageStore.isLoadingProduct)

            Button {
                Task {
                    if await usageStore.syncPurchases(), usageStore.snapshot?.canScan == true {
                        onCreditsAvailable?()
                    }
                }
            } label: {
                Text("Sync purchases")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(usageStore.isPurchasing)
        }
    }

    private var purchaseButtonTitle: String {
        if usageStore.isPurchasing { return "Contacting the App Store…" }
        if usageStore.isLoadingProduct { return "Checking availability…" }
        return usageStore.canPurchase ? "Buy \(AIScanCommerceConfig.packCredits) scans" : "Check availability"
    }
}

private struct AIScanPromoArtwork: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.accent.opacity(0.16))
                .frame(width: 76, height: 76)
                .offset(x: 15, y: 10)

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.surface)
                .frame(width: 58, height: 72)
                .overlay(
                    VStack(alignment: .leading, spacing: 7) {
                        Capsule()
                            .fill(Color(hex: "9BC292").opacity(0.70))
                            .frame(width: 36, height: 5)
                        Capsule()
                            .fill(Color(hex: "9BC292").opacity(0.55))
                            .frame(width: 29, height: 5)
                        Capsule()
                            .fill(Color(hex: "9BC292").opacity(0.40))
                            .frame(width: 40, height: 5)
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                )
                .rotationEffect(.degrees(7))
                .shadow(color: AppColors.shadow.opacity(0.12), radius: 10, x: 0, y: 6)
                .offset(x: 17, y: 3)

            Circle()
                .fill(Color(hex: "E8D8F0"))
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(AppColors.surface, lineWidth: 7)
                )
                .overlay(
                    Circle()
                        .stroke(Color(hex: "D6C0E3"), lineWidth: 1)
                )
                .offset(x: -18, y: 9)

            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(AppColors.surface)
                .frame(width: 38, height: 8)
                .rotationEffect(.degrees(-42))
                .offset(x: -38, y: 31)

            Circle()
                .fill(Color(hex: "95D08F"))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("A+")
                        .font(.lexend(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.surface)
                )
                .shadow(color: AppColors.shadow.opacity(0.12), radius: 8, x: 0, y: 5)
                .offset(x: 39, y: -31)

            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColors.accent.opacity(0.65))
                .offset(x: -46, y: -20)

            Image(systemName: "sparkle")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(AppColors.accent.opacity(0.55))
                .offset(x: 4, y: -38)
        }
        .frame(width: 108, height: 96)
        .accessibilityHidden(true)
    }
}
