//
//  AdminDebugView.swift
//  Syllabus Sync
//
//  Admin debug panel for testing and development.
//

import SwiftUI

struct AdminDebugView: View {
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var navigationManager: AppNavigationManager
    @Environment(\.dismiss) private var dismiss

    @State private var showResetAlert = false
    @State private var showDeleteCloudAlert = false
    @State private var showClearCacheAlert = false
    @State private var showToast = false
    @State private var toastMessage = ""

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Layout.Spacing.xl) {
                        // Warning header
                        VStack(spacing: Layout.Spacing.md) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.lexend(size: 48, weight: .regular))
                                .foregroundColor(.orange)

                            Text("Admin Debug Panel")
                                .font(.lexend(size: 24, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)

                            Text("These actions are for testing only. Use with caution.")
                                .font(.lexend(size: 14, weight: .regular))
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, Layout.Spacing.xl)

                        // Debug Info Section
                        debugInfoSection

                        // Actions Section
                        actionsSection

                        // Danger Zone
                        dangerZoneSection
                    }
                    .padding(Layout.Spacing.lg)
                    .padding(.bottom, Layout.Spacing.massive)
                }

                // Toast overlay
                if showToast {
                    VStack {
                        Spacer()
                        Text(toastMessage)
                            .font(.lexend(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, Layout.Spacing.lg)
                            .padding(.vertical, Layout.Spacing.sm)
                            .background(
                                Capsule().fill(AppColors.surface)
                                    .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                            )
                            .padding(.horizontal, Layout.Spacing.xl)
                            .padding(.bottom, Layout.Spacing.xl)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .navigationTitle("Admin Debug")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.accent)
                }
            }
        }
        .onChange(of: showToast) { _, show in
            if show {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { showToast = false }
                }
            }
        }
    }

    // MARK: - Debug Info Section

    private var debugInfoSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            Text("DEBUG INFO")
                .font(.lexend(size: 13, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            VStack(spacing: Layout.Spacing.sm) {
                debugInfoRow(title: "Events Count", value: "\(eventStore.events.count)")
                debugInfoRow(title: "Authenticated", value: SupabaseAuthService.shared.isAuthenticated ? "Yes" : "No")
                debugInfoRow(title: "Current User", value: SupabaseAuthService.shared.currentUser?.email ?? "None")
                debugInfoRow(title: "User ID", value: SupabaseAuthService.shared.currentUser?.id.prefix(8).description ?? "N/A")
            }
        }
    }

    private func debugInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.lexend(size: 14, weight: .medium))
                .foregroundColor(AppColors.textSecondary)

            Spacer()

            Text(value)
                .font(.lexend(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.lg)
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            Text("QUICK ACTIONS")
                .font(.lexend(size: 13, weight: .bold))
                .foregroundColor(AppColors.textSecondary)
                .tracking(1)

            VStack(spacing: Layout.Spacing.sm) {
                actionButton(
                    title: "Refresh Events",
                    icon: "arrow.clockwise",
                    color: AppColors.accent
                ) {
                    Task {
                        await eventStore.refresh()
                        showToastMessage("Events refreshed")
                    }
                }

                actionButton(
                    title: "Clear Local Cache",
                    icon: "trash.circle",
                    color: .orange
                ) {
                    showClearCacheAlert = true
                }
            }
        }
        .alert("Clear Cache", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("This will clear all locally cached data. Events will be re-fetched from the server.")
        }
    }

    // MARK: - Danger Zone

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.sm) {
            HStack(spacing: Layout.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.lexend(size: 14, weight: .medium))
                    .foregroundColor(.red)

                Text("DANGER ZONE")
                    .font(.lexend(size: 13, weight: .bold))
                    .foregroundColor(.red)
                    .tracking(1)
            }

            VStack(spacing: Layout.Spacing.sm) {
                actionButton(
                    title: "Delete Cloud Backup",
                    icon: "cloud.slash.fill",
                    color: .red
                ) {
                    showDeleteCloudAlert = true
                }

                actionButton(
                    title: "Reset All App Data",
                    icon: "arrow.counterclockwise.circle.fill",
                    color: .red
                ) {
                    showResetAlert = true
                }

                actionButton(
                    title: "Sign Out",
                    icon: "rectangle.portrait.and.arrow.right",
                    color: .red
                ) {
                    Task {
                        await performSignOut()
                    }
                }
            }
        }
        .alert("Delete Cloud Backup", isPresented: $showDeleteCloudAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteCloudData()
            }
        } message: {
            Text("This will permanently delete all your synced courses and events from the cloud.")
        }
        .alert("Reset App Data", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAppData()
            }
        } message: {
            Text("This will clear all local data and sign you out. You'll need to set up the app again.")
        }
    }

    // MARK: - Helper Views

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Layout.Spacing.md) {
                Image(systemName: icon)
                    .font(.lexend(size: 18, weight: .medium))
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(title)
                    .font(.lexend(size: 16, weight: .medium))
                    .foregroundColor(color)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.lexend(size: 14, weight: .semibold))
                    .foregroundColor(color.opacity(0.6))
            }
            .padding(Layout.Spacing.md)
            .background(AppColors.surface)
            .cornerRadius(Layout.CornerRadius.lg)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Actions

    private func clearCache() {
        // For now just refresh from server
        Task {
            await eventStore.fetchEvents()
            showToastMessage("Cache cleared, events refreshed")
        }
    }

    private func deleteCloudData() {
        Task {
            if let dataService = SupabaseDataService.shared as? SupabaseDataService {
                await dataService.deleteAllData()
                showToastMessage("Cloud data deleted")
            }
        }
    }

    private func resetAppData() {
        Task {
            await performSignOut()
        }
    }

    private func performSignOut() async {
        // CRITICAL: Sign out from Supabase FIRST to invalidate the session.
        // This prevents background fetches from re-populating local stores
        // with the old user's data.

        // 1. Sign out from Supabase (invalidates JWT immediately)
        do {
            try await SupabaseAuthService.shared.signOut()
            print("✅ Signed out from Supabase")
        } catch {
            print("⚠️ Sign out error: \(error)")
        }

        // 2. Clear Event Store (safe now — any re-fetch will fail auth)
        await MainActor.run {
            eventStore.clearEvents()
        }
        print("✅ EventStore cleared")

        // 3. Clear UserDefaults
        if let bundleId = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
            UserDefaults.standard.synchronize()
            print("✅ UserDefaults cleared")
        }

        // 4. Navigate to auth screen
        await MainActor.run {
            dismiss()
            navigationManager.setRoot(to: .auth)
            print("✅ Navigated to auth screen")
        }
    }

    private func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true
        HapticFeedbackManager.shared.lightImpact()
    }
}
