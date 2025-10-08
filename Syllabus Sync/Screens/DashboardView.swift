//
//  DashboardView.swift
//  Syllabus Sync
//
//  Created by Assistant on 2024-01-01.
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var importViewModel: ImportViewModel
    @State private var isRefreshing = false
    @State private var showShimmer = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var showingImportView = false
    @State private var fabPressed = false
    @State private var editingEvent: EventItem?

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if showShimmer {
                            DashboardShimmerView()
                                .transition(.opacity)
                        } else if eventStore.events.isEmpty {
                            DashboardEmptyView(showingImportView: $showingImportView)
                                .transition(.opacity)
                        } else {
                            DashboardEventList(events: eventStore.events, onEventTapped: { event in
                                editingEvent = event
                            })
                                .transition(.opacity)
                        }
                    }
                }
                .background(AppColors.background)

                if !eventStore.events.isEmpty {
                    fabButton
                        .padding(.trailing, Layout.Spacing.lg)
                        .padding(.bottom, Layout.Spacing.lg)
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await performRefreshAsync()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingImportView) {
            ImportView()
                .environmentObject(navigationManager)
        }
        .fullScreenCover(item: $editingEvent) { event in
            EventEditView(event: event) { updated in
                Task { await importViewModel.applyEditedEvent(updated) }
                editingEvent = nil
            } onCancel: {
                editingEvent = nil
            }
        }
    }
    
    private func performRefreshAsync() async {
        await MainActor.run {
            isRefreshing = true
            showShimmer = true
            HapticFeedbackManager.shared.lightImpact()
        }

        await eventStore.refresh()

        await MainActor.run {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isRefreshing = false
                showShimmer = false
            }
        }
    }
}

// MARK: - Floating Action Button

private extension DashboardView {
    var fabButton: some View {
        Button(action: handleFabTap) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .padding(24)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.886, green: 0.714, blue: 0.275), // #E2B646
                            Color(red: 0.816, green: 0.612, blue: 0.118)  // #D09C1E
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .elevatedShadowLight()
        }
        .scaleEffect(fabPressed ? 0.90 : 1)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: fabPressed)
        .accessibilityLabel("Import syllabus")
    }

    func handleFabTap() {
        HapticFeedbackManager.shared.mediumImpact()
        fabPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            fabPressed = false
        }
        showingImportView = true
    }
}

// MARK: - Dashboard Empty State

struct DashboardEmptyView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @State private var buttonScale: CGFloat = 1.0
    @State private var showGlow: Bool = false
    @Binding var showingImportView: Bool
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xxl) {
            Spacer()
            
            // Illustration from dashboard-image.png
            VStack(spacing: Layout.Spacing.xl) {
                Image("DashboardEmpty")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 280, maxHeight: 240)
                    .scaleEffect(showGlow ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: showGlow)
                    .onAppear {
                        showGlow = true
                    }
                
                // Concise Copy
                VStack(spacing: Layout.Spacing.md) {
                    Text("Import your syllabi and we'll handle the dates, assignments, and reminders for you.")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, Layout.Spacing.lg)
                }
            }
            
            Spacer()
            
            // Action Section
            VStack(spacing: Layout.Spacing.lg) {
                // Primary CTA - Large gradient button
                Button {
                    HapticFeedbackManager.shared.mediumImpact()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        buttonScale = 0.95
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            buttonScale = 1.0
                        }
                    }
                    showingImportView = true
                } label: {
                    HStack(spacing: Layout.Spacing.sm) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Import Syllabus PDFs")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.purple,
                                Color.blue
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(Layout.CornerRadius.lg)
                    .shadow(color: AppColors.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .scaleEffect(buttonScale)
                
                // Secondary CTA - Preview Sample card
                Button {
                    HapticFeedbackManager.shared.lightImpact()
                    navigationManager.switchTab(to: .preview) // Switch to Calendar tab
                } label: {
                    HStack(spacing: Layout.Spacing.md) {
                        Image(systemName: "calendar")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(AppColors.accent)
                            .frame(width: 40, height: 40)
                            .background(AppColors.accent.opacity(0.1))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                            Text("Preview Sample")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("See how it works with sample data")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    .padding(Layout.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.surface)
                    .cornerRadius(Layout.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                    .shadow(color: AppColors.textPrimary.opacity(0.05), radius: 8, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.bottom, Layout.Spacing.xl)
        }
        .padding(.horizontal, Layout.Spacing.lg)
    }
}

// MARK: - Event List

private struct DashboardEventList: View {
    let events: [EventItem]
    let onEventTapped: (EventItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
            VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                Text("Upcoming Events")
                    .font(.titleS)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Text("Tap to edit event details.")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, Layout.Spacing.lg)

            VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                ForEach(events) { event in
                    PreviewEventCard(event: event)
                        .padding(.horizontal, Layout.Spacing.lg)
                        .onTapGesture { onEventTapped(event) }
                }
            }
        }
        .padding(.vertical, Layout.Spacing.xl)
    }
}


// MARK: - Dashboard Shimmer

struct DashboardShimmerView: View {
    @State private var animateShimmer = false
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xl) {
            // Header Section
            VStack(spacing: Layout.Spacing.lg) {
                HStack {
                    Text("Refreshing...")
                        .font(.titleM)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.accent))
                        .scaleEffect(0.8)
                }
                
                Rectangle()
                    .fill(AppColors.separator)
                    .frame(height: 1)
            }
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.top, Layout.Spacing.lg)
            
            // Content Shimmer
            VStack(spacing: Layout.Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerCard()
                }
            }
            .padding(.horizontal, Layout.Spacing.lg)
            
            Spacer()
        }
    }
}

struct ShimmerCard: View {
    @State private var animateGradient = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.md) {
            HStack {
                ShimmerRectangle(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: Layout.CornerRadius.sm))
                
                VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                    ShimmerRectangle(width: 120, height: 16)
                    ShimmerRectangle(width: 80, height: 14)
                }
                
                Spacer()
                
                ShimmerRectangle(width: 30, height: 30)
                    .clipShape(Circle())
            }
            
            VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                ShimmerRectangle(width: .infinity, height: 12)
                ShimmerRectangle(width: 200, height: 12)
            }
        }
        .padding(Layout.Spacing.md)
        .background(AppColors.surface)
        .cornerRadius(Layout.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                .stroke(AppColors.border, lineWidth: 1)
        )
        .cardShadowLight()
    }
}

struct ShimmerRectangle: View {
    let width: CGFloat?
    let height: CGFloat
    @State private var animateGradient = false
    
    init(width: CGFloat?, height: CGFloat) {
        self.width = width
        self.height = height
    }
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        AppColors.separator.opacity(0.3),
                        AppColors.separator.opacity(0.1),
                        AppColors.separator.opacity(0.3)
                    ]),
                    startPoint: animateGradient ? .leading : .trailing,
                    endPoint: animateGradient ? .trailing : .leading
                )
            )
            .frame(width: width, height: height)
            .cornerRadius(Layout.CornerRadius.xs)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
    }
}


// MARK: - Preview

#Preview {
    DashboardView()
        .environmentObject(AppNavigationManager())
        .environmentObject(ThemeManager())
}
