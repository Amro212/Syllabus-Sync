//
//  ImportView.swift
//  Syllabus Sync
//
//  Created by Assistant on 2024-01-01.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var importViewModel: ImportViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingFilePicker = false
    @State private var currentImportTask: Task<Void, Never>? = nil

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                if importViewModel.isProcessing {
                    ProcessingView(
                        progress: importViewModel.progress,
                        step: importViewModel.statusMessage
                    )
                    .transition(.opacity)
                } else {
                    ImportContentView(
                        onFilePicker: { isShowingFilePicker = true }
                    )
                    .transition(.opacity)
                }

                if let errorState = importViewModel.errorState {
                    ImportErrorOverlay(
                        errorState: errorState,
                        onRetry: {
                            Task {
                                await importViewModel.retryLastImport()
                            }
                        },
                        onContinue: {
                            HapticFeedbackManager.shared.lightImpact()
                            importViewModel.errorState = nil
                            dismiss()
                            navigationManager.switchTab(to: .preview)
                        }
                    )
                    .transition(.opacity)
                }
            }
            .navigationTitle("Import Syllabus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticFeedbackManager.shared.lightImpact()
                        if importViewModel.isProcessing {
                            importViewModel.cancelImport()
                            currentImportTask?.cancel()
                        }
                        dismiss()
                    }
                    .foregroundColor(AppColors.textTertiary)
                }
            }
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            currentImportTask?.cancel()
            let task = Task {
                await MainActor.run { isShowingFilePicker = false }
                let success = await importViewModel.importSyllabus(from: url)
                if success && !Task.isCancelled {
                    await MainActor.run {
                        dismiss()
                        navigationManager.switchTab(to: .preview)
                    }
                }
                // Cleanup after task completes
                await MainActor.run { currentImportTask = nil }
            }
            currentImportTask = task
        case .failure(let error):
            print("File import error: \(error)")
        }
    }
}

private struct ImportErrorOverlay: View {
    let errorState: ImportErrorState
    let onRetry: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: Layout.Spacing.lg) {
            VStack(spacing: Layout.Spacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(AppColors.accent)

                Text(title)
                    .font(.titleM)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Text(errorState.message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.horizontal, Layout.Spacing.lg)
            }

            VStack(spacing: Layout.Spacing.sm) {
                Button(action: onRetry) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry Parse")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(AppColors.accent)
                    .cornerRadius(Layout.CornerRadius.md)
                }

                Button(action: onContinue) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        Text("Continue Without Events")
                    }
                    .font(.body)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AppColors.surface)
                    .cornerRadius(Layout.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .stroke(AppColors.separator, lineWidth: 1)
                    )
                }
            }

            Text("Request ID: \(errorState.requestID)\nLogged: \(formattedTimestamp)")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Layout.Spacing.lg)
        }
        .padding(Layout.Spacing.xl)
        .frame(maxWidth: 360)
        .background(AppColors.background)
        .cornerRadius(Layout.CornerRadius.lg)
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: Layout.CornerRadius.lg)
                .stroke(AppColors.separator, lineWidth: 1)
        )
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4).ignoresSafeArea())
    }

    private var title: String {
        switch errorState.type {
        case .network:
            return "Connection Issue"
        case .server:
            return "Parser Error"
        case .invalidResponse:
            return "Unexpected Response"
        case .validation:
            return "Content Issue"
        case .unknown:
            return "Something Went Wrong"
        }
    }

    private var iconName: String {
        switch errorState.type {
        case .network:
            return "wifi.exclamationmark"
        case .server:
            return "bolt.horizontal.icloud"
        case .invalidResponse:
            return "exclamationmark.triangle"
        case .validation:
            return "doc.text.magnifyingglass"
        case .unknown:
            return "questionmark.circle"
        }
    }

    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: errorState.timestamp)
    }
}

// MARK: - Import Content View

struct ImportContentView: View {
    let onFilePicker: () -> Void
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xxxl) {
            Spacer()
            
            // Main content area
            VStack(spacing: Layout.Spacing.xl) {
                // Icon and illustration
                VStack(spacing: Layout.Spacing.lg) {
                    ZStack {
                        // Background circles
                        Circle()
                            .fill(AppColors.accent.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .fill(AppColors.accent.opacity(0.15))
                            .frame(width: 100, height: 100)
                        
                        // Upload icon
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(AppColors.accent)
                    }
                    .shadow(color: AppColors.accent.opacity(0.2), radius: 20, x: 0, y: 10)
                }
                
                // Text content
                VStack(spacing: Layout.Spacing.md) {
                    Text("Import Your Syllabi")
                        .font(.titleL)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("Select your syllabus PDF files using the button below to get started.")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, Layout.Spacing.md)
                }
            }
            
            
            Spacer()
            
            // Action buttons
            VStack(spacing: Layout.Spacing.lg) {
                // Primary file picker button - Main action for iOS
                Button {
                    HapticFeedbackManager.shared.mediumImpact()
                    onFilePicker()
                } label: {
                    HStack(spacing: Layout.Spacing.sm) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 20, weight: .semibold))
                        
                        Text("Select PDF Files")
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
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
                
                
                // Help text
                Text("Supports PDF files up to 25MB. We'll extract dates, assignments, and deadlines automatically.")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Layout.Spacing.lg)
            }
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.bottom, Layout.Spacing.xl)
        }
        .padding(.horizontal, Layout.Spacing.lg)
    }
    
}

// MARK: - Processing View

struct ProcessingView: View {
    let progress: Double
    let step: String

    @State private var animationLoopsActive = false
    @State private var messageIndex = 0
    @State private var iconIndex = 0
    @State private var animateBackground = false
    @State private var showCompletionState = false
    @State private var completionScale: CGFloat = 0.8

    private static let statusMessages: [[MessageSegment]] = [
        [
            MessageSegment(text: "Reading your ", accent: false),
            MessageSegment(text: "syllabus…", accent: true)
        ],
        [
            MessageSegment(text: "Finding important ", accent: false),
            MessageSegment(text: "dates & deadlines…", accent: true)
        ],
        [
            MessageSegment(text: "Almost ready - building your ", accent: false),
            MessageSegment(text: "calendar!", accent: true)
        ]
    ]

    var body: some View {
        ZStack {
            ProcessingBackgroundView(animate: animateBackground || showCompletionState)

            VStack(spacing: Layout.Spacing.xxxl) {
                Spacer(minLength: Layout.Spacing.xxxl)

                VStack(spacing: Layout.Spacing.xl) {
                    AnimatedImportIllustration(
                        activeState: showCompletionState ? .calendar : IllustrationState(rawValue: iconIndex) ?? .document,
                        showCompletion: showCompletionState,
                        completionScale: completionScale
                    )

                    VStack(spacing: Layout.Spacing.md) {
                        headerText
                            .font(.titleL)
                            .multilineTextAlignment(.center)
                            .id(showCompletionState ? "header-complete" : "header-active")

                        activeStatusText
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Layout.Spacing.lg)
                            .id(showCompletionState ? "status-complete" : "status-\(messageIndex)")
                            .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                }

                Spacer()

                VStack(spacing: Layout.Spacing.lg) {
                    VStack(spacing: Layout.Spacing.sm) {
                        HStack {
                            Text(step)
                                .font(.callout.weight(.medium))
                                .foregroundColor(AppColors.textPrimary)

                            Spacer()

                            Text("\(Int(progress * 100))%")
                                .font(.callout.weight(.semibold))
                                .foregroundColor(showCompletionState ? AppColors.success : AppColors.accent)
                        }

                        AnimatedProgressBar(progress: progress, isComplete: showCompletionState)
                            .frame(height: 12)
                    }

                    Text(showCompletionState ? "Great news — your events are synced and ready to review." : "Hang tight while we parse everything for your calendar.")
                        .font(.caption)
                        .foregroundColor(AppColors.textTertiary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, Layout.Spacing.lg)
                .padding(.bottom, Layout.Spacing.xl)
            }
            .padding(.horizontal, Layout.Spacing.lg)
        }
        .onAppear {
            animationLoopsActive = true
            animateBackground = true
        }
        .onDisappear {
            animationLoopsActive = false
        }
        .onChange(of: progress, perform: handleProgressChange)
        .task(id: animationLoopsActive) {
            await runAnimationLoops()
        }
    }

    private var headerText: Text {
        if showCompletionState {
            return Text("Calendar ")
                .foregroundColor(AppColors.textPrimary)
                .fontWeight(.semibold)
            + Text("ready!")
                .foregroundColor(AppColors.accent)
                .fontWeight(.heavy)
        } else {
            return Text("Processing ")
                .foregroundColor(AppColors.accent)
                .fontWeight(.heavy)
            + Text("your syllabus")
                .foregroundColor(AppColors.textPrimary)
                .fontWeight(.semibold)
        }
    }

    private var activeStatusText: Text {
        if showCompletionState {
            return Text("Import complete — ")
                .foregroundColor(AppColors.textSecondary)
            + Text("calendar ready.")
                .foregroundColor(AppColors.accent)
                .fontWeight(.semibold)
        }

        let segments = Self.statusMessages[messageIndex]
        return segments.dropFirst().reduce(
            Text(segments.first?.text ?? "")
                .foregroundColor(segments.first?.accent == true ? AppColors.accent : AppColors.textSecondary)
                .fontWeight(segments.first?.accent == true ? .semibold : .regular)
        ) { partial, segment in
            partial + Text(segment.text)
                .foregroundColor(segment.accent ? AppColors.accent : AppColors.textSecondary)
                .fontWeight(segment.accent ? .semibold : .regular)
        }
    }

    private func handleProgressChange(_ value: Double) {
        let clamped = min(max(value, 0), 1)

        if clamped >= 1.0 {
            guard !showCompletionState else { return }
            showCompletionState = true
            animationLoopsActive = false
            messageIndex = Self.statusMessages.count - 1
            iconIndex = IllustrationState.calendar.rawValue

            completionScale = 0.8
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0.4)) {
                completionScale = 1.05
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85, blendDuration: 0.3)) {
                    completionScale = 0.95
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.9, blendDuration: 0.3)) {
                        completionScale = 1.0
                    }
                }
            }
        } else {
            if showCompletionState {
                showCompletionState = false
                completionScale = 0.8
            }
            if !animationLoopsActive {
                animationLoopsActive = true
            }
        }
    }

    private func runAnimationLoops() async {
        let tick: UInt64 = 120_000_000 // 0.12s
        var messageElapsed: Double = 0
        var iconElapsed: Double = 0

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: tick)

            if showCompletionState {
                messageElapsed = 0
                iconElapsed = 0
                continue
            }

            messageElapsed += 0.12
            iconElapsed += 0.12

            if messageElapsed >= 3.0 {
                messageElapsed = 0
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.45)) {
                        messageIndex = (messageIndex + 1) % Self.statusMessages.count
                    }
                }
            }

            if iconElapsed >= 1.8 {
                iconElapsed = 0
                await MainActor.run {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.85, blendDuration: 0.5)) {
                        iconIndex = (iconIndex + 1) % IllustrationState.allCases.count
                    }
                }
            }
        }
    }
}

private struct MessageSegment: Hashable {
    let text: String
    let accent: Bool
}

private enum IllustrationState: Int, CaseIterable {
    case document
    case scanning
    case calendar
}

private struct AnimatedImportIllustration: View {
    let activeState: IllustrationState
    let showCompletion: Bool
    let completionScale: CGFloat

    @State private var pulse = false
    @State private var orbit = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.accent.opacity(0.2),
                            AppColors.accentSecondary.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 220, height: 220)
                .scaleEffect(pulse ? 1.05 : 0.94)
                .animation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true), value: pulse)

            Circle()
                .stroke(AppColors.accent.opacity(0.18), lineWidth: 1.5)
                .frame(width: 200, height: 200)

            Circle()
                .fill(AppColors.surfaceSecondary.opacity(0.55))
                .frame(width: 168, height: 168)
                .shadow(color: AppColors.accent.opacity(0.25), radius: 24, x: 0, y: 18)

            ForEach(IllustrationState.allCases, id: \.self) { state in
                IllustrationSymbol(state: state)
                    .opacity(activeState == state && !showCompletion ? 1 : 0)
                    .scaleEffect(activeState == state && !showCompletion ? 1 : 0.9)
                    .animation(.easeInOut(duration: 0.55), value: activeState)
            }

            if showCompletion {
                Circle()
                    .fill(AppColors.success)
                    .frame(width: 124, height: 124)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 56, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .scaleEffect(completionScale)
                    .shadow(color: AppColors.success.opacity(0.3), radius: 24, x: 0, y: 14)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Circle()
                    .stroke(AppColors.accent.opacity(0.22), lineWidth: 1.5)
                    .frame(width: 150, height: 150)
                    .offset(x: orbit ? 8 : -8, y: orbit ? -6 : 6)
                    .animation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true), value: orbit)
            }
        }
        .frame(width: 220, height: 220)
        .onAppear {
            pulse = true
            orbit = true
        }
    }
}

private struct IllustrationSymbol: View {
    let state: IllustrationState

    var body: some View {
        switch state {
        case .document:
            ZStack {
                Image(systemName: "doc.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColors.surface, AppColors.accent)
                    .font(.system(size: 62, weight: .regular))
                    .shadow(color: AppColors.accent.opacity(0.25), radius: 16, x: 0, y: 10)

                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(AppColors.accent)
                    .offset(x: 30, y: -34)
                    .shadow(color: AppColors.accent.opacity(0.4), radius: 12, x: 0, y: 6)
            }
        case .scanning:
            ZStack {
                Image(systemName: "doc.text")
                    .font(.system(size: 52, weight: .regular))
                    .foregroundColor(AppColors.textSecondary.opacity(0.85))
                    .offset(x: -12, y: 8)

                Image(systemName: "magnifyingglass.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(AppColors.accent, AppColors.surface)
                    .font(.system(size: 72, weight: .bold))
                    .shadow(color: AppColors.accent.opacity(0.3), radius: 18, x: 0, y: 12)
                    .offset(x: 28, y: -22)
            }
        case .calendar:
            Image(systemName: "calendar")
                .symbolRenderingMode(.palette)
                .foregroundStyle(AppColors.accent, AppColors.surface)
                .font(.system(size: 74, weight: .semibold))
                .shadow(color: AppColors.accent.opacity(0.32), radius: 20, x: 0, y: 12)
        }
    }
}

private struct AnimatedProgressBar: View {
    let progress: Double
    let isComplete: Bool

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(progress, 0), 1)
            let trackCorner = Layout.CornerRadius.xs
            let track = RoundedRectangle(cornerRadius: trackCorner)

            ZStack(alignment: .leading) {
                track
                    .fill(AppColors.surfaceSecondary.opacity(0.6))

                if clamped > 0 {
                    let fillWidth = geometry.size.width * clamped

                    track
                        .fill(
                            LinearGradient(
                                colors: isComplete
                                    ? [AppColors.success, AppColors.success.opacity(0.85)]
                                    : [AppColors.accent, AppColors.accentSecondary],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: fillWidth)
                        .shadow(color: (isComplete ? AppColors.success : AppColors.accent).opacity(0.25), radius: 14, x: 0, y: 8)
                        .animation(.easeInOut(duration: 0.35), value: fillWidth)
                }
            }
        }
        .frame(height: 12)
    }
}

private struct ProcessingBackgroundView: View {
    let animate: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColors.background,
                    AppColors.background.opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.accentSecondary.opacity(0.28),
                    Color.clear
                ]),
                center: .center,
                startRadius: 40,
                endRadius: 360
            )
            .blendMode(.screen)
            .opacity(animate ? 1 : 0)

            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.accent.opacity(0.22),
                    Color.clear
                ]),
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 320
            )
            .blendMode(.screen)
            .opacity(animate ? 0.85 : 0)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Preview

#Preview {
    ImportView()
        .environmentObject(AppNavigationManager())
}
