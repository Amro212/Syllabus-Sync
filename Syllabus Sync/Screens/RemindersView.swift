//
//  RemindersView.swift
//  Syllabus Sync
//
//  Created by Assistant on 2024-01-01.
//

import SwiftUI

struct RemindersView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var eventStore: EventStore
    @EnvironmentObject var importViewModel: ImportViewModel
    @State private var isRefreshing = false
    @State private var showShimmer = false
    @State private var buttonScale: CGFloat = 1.0
    @State private var showingImportView = false
    @State private var fabPressed = false
    @State private var fabExpanded = false
    @State private var editingEvent: EventItem?
    @State private var isCreatingNewEvent = false
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        NavigationView {
            GeometryReader { geo in
                let headerHeight = geo.safeAreaInsets.top + 4

                ZStack(alignment: .top) {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                if showShimmer {
                                    RemindersShimmerView()
                                        .transition(.opacity)
                                } else if eventStore.events.isEmpty {
                                    RemindersEmptyView(showingImportView: $showingImportView)
                                        .transition(.opacity)
                                } else {
                                    RemindersEventList(events: eventStore.events, onEventTapped: { event in
                                        editingEvent = event
                                    })
                                        .transition(.opacity)
                                }
                            }
                            .padding(.top, 60)
                            .padding(.bottom, 80) // Add bottom padding for tab bar
                        }
                        .background(AppColors.background)
                        .refreshable {
                            await performRefreshAsync()
                        }
                        .onAppear {
                            scrollProxy = proxy
                        }
                        .onChange(of: navigationManager.scrollToEventId) { eventId in
                            if let eventId = eventId {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    withAnimation {
                                        proxy.scrollTo(eventId, anchor: .center)
                                    }
                                    navigationManager.scrollToEventId = nil
                                }
                            }
                        }
                    }

                    // Custom Top Bar (Sticky)
                    VStack(spacing: 0) {
                        HStack {
                            Text("Reminders")
                                .font(.titleL)
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.textPrimary)
                            
                            Spacer()
                            
                            Image(systemName: "person.circle")
                                .font(.system(size: 28))
                                .foregroundColor(AppColors.textPrimary)
                        }
                        .padding(.horizontal, Layout.Spacing.md)
                        .padding(.bottom, Layout.Spacing.sm)
                        .padding(.top, geo.safeAreaInsets.top)
                        .background(AppColors.background.opacity(0.95))
                        .overlay(alignment: .bottom) {
                            Divider().opacity(0.5)
                        }
                        
                        Spacer()
                    }
                    .frame(height: headerHeight + 50)
                    .ignoresSafeArea(edges: .top)
                }
                .background(AppColors.background)
                .overlay(alignment: .bottomTrailing) {
                    fabButton
                        .padding(.trailing, Layout.Spacing.xl)
                        .padding(.bottom, Layout.Spacing.xl)
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingImportView) {
            AISyllabusScanModal()
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
        }
        .fullScreenCover(item: $editingEvent) { event in
            EventEditView(event: event) { updated in
                if isCreatingNewEvent {
                    Task { 
                        await eventStore.update(event: updated)
                        isCreatingNewEvent = false
                    }
                } else {
                    Task { await importViewModel.applyEditedEvent(updated) }
                }
                editingEvent = nil
            } onCancel: {
                isCreatingNewEvent = false
                editingEvent = nil
            }
        }
        .onChange(of: showingImportView) { newValue in
            if !newValue { fabExpanded = false }
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

private extension RemindersView {
    var fabButton: some View {
        ZStack(alignment: .bottomTrailing) {
            // Backdrop dimming
            if fabExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            fabExpanded = false
                        }
                    }
                    .transition(.opacity)
            }
            
            VStack(alignment: .trailing, spacing: Layout.Spacing.md) {
                // Expanded options
                if fabExpanded {
                    VStack(spacing: Layout.Spacing.sm) {
                        // Add Reminder option
                        FABOption(
                            icon: "plus.circle.fill",
                            label: "Add Reminder",
                            color: Color.blue,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    fabExpanded = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    createNewEvent()
                                }
                            }
                        )
                        
                        // Upload Syllabus option
                        FABOption(
                            icon: "doc.badge.plus",
                            label: "Upload Syllabus",
                            color: AppColors.accent,
                            action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    fabExpanded = false
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    showingImportView = true
                                }
                            }
                        )
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                
                // Main FAB button
                Button(action: handleFabTap) {
                    Image(systemName: fabExpanded ? "xmark" : "plus")
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
                        .rotationEffect(.degrees(fabExpanded ? 135 : 0))
                }
                .scaleEffect(fabPressed ? 0.90 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: fabPressed)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: fabExpanded)
                .accessibilityLabel(fabExpanded ? "Close menu" : "Open quick actions")
            }
        }
    }

    func handleFabTap() {
        HapticFeedbackManager.shared.mediumImpact()
        fabPressed = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            fabPressed = false
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            fabExpanded.toggle()
        }
    }

    func createNewEvent() {
        let now = Date()
        let newEvent = EventItem(
            id: UUID().uuidString,
            courseCode: "", // Empty courseCode to avoid deletion conflicts
            type: .assignment,
            title: "",
            start: now,
            end: nil,
            allDay: false,
            location: nil,
            notes: nil,
            recurrenceRule: nil,
            reminderMinutes: 1440,
            confidence: 1.0
        )
        isCreatingNewEvent = true
        editingEvent = newEvent
    }
}

// MARK: - FAB Option

private struct FABOption: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isPressed = false
            }
            action()
        }) {
            HStack(spacing: Layout.Spacing.sm) {
                Text(label)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(color)
                            .shadow(color: color.opacity(0.3), radius: 8, x: 0, y: 4)
                    )
            }
            .padding(.horizontal, Layout.Spacing.md)
            .padding(.vertical, Layout.Spacing.sm)
            .background(
                Capsule()
                    .fill(AppColors.surface)
                    .shadow(color: AppColors.shadow.opacity(0.15), radius: 8, x: 0, y: 4)
            )
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
    }
}

// MARK: - Reminders Empty State

struct RemindersEmptyView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @State private var buttonScale: CGFloat = 1.0
    @State private var showGlow: Bool = false
    @Binding var showingImportView: Bool
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xxl) {
            // Illustration from reminders-icon.png
            VStack(spacing: Layout.Spacing.xl) {
                ZStack {
                    Image("RemindersIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 280, maxHeight: 240)
                        .scaleEffect(showGlow ? 1.04 : 0.95)
                        .opacity(showGlow ? 1.0 : 0.85)
                        .animation(
                            Animation.easeInOut(duration: 2.8)
                                .repeatForever(autoreverses: true),
                            value: showGlow
                        )
                        .onAppear { 
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                showGlow = true 
                            }
                        }
                }
                .frame(width: 280, height: 240)
                .clipped()
                
                // Concise Copy
                VStack(spacing: Layout.Spacing.md) {
                    Text("No reminders set up yet! Import a syllabus to create reminders.")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, Layout.Spacing.xl)
                }
            }
            .padding(.horizontal, Layout.Spacing.md)
            
            // Action Section
            VStack(spacing: Layout.Spacing.lg) {
                Spacer(minLength: 40) // Adds vertical empty space above the button (tweak value if needed)
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
                    .frame(height: 55)     // Increased height
                    .frame(maxWidth: 320) // Decreased width
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

private struct RemindersEventList: View {
    let events: [EventItem]
    let onEventTapped: (EventItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.Spacing.lg) {
            VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                Text("Upcoming Reminders")
                    .font(.titleS)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Text("Tap to edit reminder details.")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            VStack(alignment: .leading, spacing: Layout.Spacing.md) {
                ForEach(events) { event in
                    PreviewEventCard(event: event)
                        .id(event.id)
                        .onTapGesture { onEventTapped(event) }
                }
            }
        }
        .padding(.horizontal, Layout.Spacing.md)
        .padding(.vertical, Layout.Spacing.xl)
    }
}


// MARK: - Reminders Shimmer

struct RemindersShimmerView: View {
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

// MARK: - Preview

#Preview {
    RemindersView()
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
