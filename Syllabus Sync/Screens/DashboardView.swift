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
                        // Custom header with consistent padding
                        VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                            Text("Dashboard")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Text("Welcome aboard! Let's get your semester organized.")
                                .font(.body)
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, Layout.Spacing.md)
                        .padding(.top, Layout.Spacing.lg)
                        .padding(.bottom, Layout.Spacing.md)
                        
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
                        .padding(.trailing, Layout.Spacing.xl)
                        .padding(.bottom, Layout.Spacing.xl)
                }
            }
            .navigationBarHidden(true)
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
                    Text("Nothing here yet! Upload a syllabus to get started.")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, Layout.Spacing.xl)
                }
            }
            .padding(.horizontal, Layout.Spacing.md)
            
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
                    .frame(maxWidth: 280) // Decreased width
                    .frame(height: 65)     // Increased height
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.886, green: 0.714, blue: 0.275), // Medium gold
                                Color(red: 0.722, green: 0.565, blue: 0.110)  // Darker gold
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(Layout.CornerRadius.lg)
                    .shadow(color: AppColors.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                }
                .scaleEffect(buttonScale)
            }
            .padding(.bottom, Layout.Spacing.xl)
        }
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

            VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                ForEach(events) { event in
                    PreviewEventCard(event: event)
                        .onTapGesture { onEventTapped(event) }
                }
            }
        }
        .padding(.horizontal, Layout.Spacing.md)
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
            .padding(.top, Layout.Spacing.lg)
            
            // Content Shimmer
            VStack(spacing: Layout.Spacing.lg) {
                ForEach(0..<3, id: \.self) { _ in
                    ShimmerCard()
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, Layout.Spacing.md)
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
        .environmentObject(EventStore())
        .environmentObject(ImportViewModel(
            extractor: PDFKitExtractor(),
            parser: SyllabusParserRemote(apiClient: URLSessionAPIClient(
                configuration: URLSessionAPIClient.Configuration(
                    baseURL: URL(string: "https://api.example.com")!,
                    requestTimeout: 30,
                    maxRetryCount: 1
                )
            )),
            eventStore: EventStore()
        ))
}
