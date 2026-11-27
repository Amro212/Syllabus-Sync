//
//  AISyllabusScanModal.swift
//  Syllabus Sync
//
//  Created by Assistant on 2024-01-03.
//

import SwiftUI
import UniformTypeIdentifiers

enum AIScanConsent {
    static let title = "Share syllabus text with OpenRouter?"
    static let message = "Syllabus Sync extracts text from your PDF on your device. It sends the text to OpenRouter and the AI provider it routes to, so they can identify course dates and grading details. The text can include names, email addresses, and other information in the syllabus."
}

struct AISyllabusScanModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var importViewModel: ImportViewModel
    @EnvironmentObject var aiUsageStore: AIScanUsageStore

    @State private var isShowingFilePicker = false
    @State private var showAIConsent = false
    @State private var selectedFileURL: URL?
    @State private var currentImportTask: Task<Void, Never>?
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            // Full screen backdrop blur
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    if !importViewModel.isProcessing && !showPaywall {
                        dismiss()
                    }
                }

            if showPaywall {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                GeometryReader { geometry in
                    ScrollView {
                        paywallCard
                            .padding(.horizontal, Layout.Spacing.lg)
                            .padding(.vertical, Layout.Spacing.sm)
                            .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                }
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            } else {
                scanCard
            }
        }
        .animation(.easeInOut(duration: 0.3), value: importViewModel.isProcessing)
        .animation(.easeInOut(duration: 0.3), value: importViewModel.errorState?.id)
        .animation(.spring(response: 0.28, dampingFraction: 0.84), value: showPaywall)
        .alert(AIScanConsent.title, isPresented: $showAIConsent) {
            Button("Allow and choose PDF") { isShowingFilePicker = true }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(AIScanConsent.message)
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onChange(of: importViewModel.isProcessing) { _, isProcessing in
            // When processing completes successfully, navigate to review or reminders
            if !isProcessing && importViewModel.progress >= 1.0 {
                Task { await aiUsageStore.refresh() }
                dismiss()
                if importViewModel.needsReview {
                    navigationManager.showParseReview = true
                } else {
                    navigationManager.switchTab(to: .reminders)
                }
            }
        }
        .onChange(of: importViewModel.paywallUsage) { _, usage in
            if usage?.canScan == false { showPaywall = true }
        }
        .onChange(of: aiUsageStore.snapshot) { _, usage in
            if usage?.canScan == true, !showPaywall {
                importViewModel.paywallUsage = nil
            }
        }
        .task {
            await aiUsageStore.refresh(force: false)
            if aiUsageStore.snapshot?.canScan == true { importViewModel.paywallUsage = nil }
            if activeUsageSnapshot?.canScan == false { showPaywall = true }
        }
    }

    private var scanCard: some View {
        ZStack {
            if importViewModel.isProcessing {
                // Loading State
                AILoadingView(
                    progress: importViewModel.progress,
                    statusMessage: importViewModel.statusMessage,
                    onCancel: {
                        importViewModel.cancelImport()
                        currentImportTask?.cancel()
                        dismiss()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if let errorState = importViewModel.errorState {
                // Error State
                ScanErrorView(
                    errorState: errorState,
                    isCourseCodeMissing: importViewModel.isCourseCodeMissing,
                    onRetry: {
                        Task {
                            await importViewModel.retryLastImport()
                        }
                    },
                    onSubmitCourseCode: { courseCode in
                        Task {
                            await importViewModel.retryWithCourseCode(courseCode)
                        }
                    },
                    onDismiss: {
                        HapticFeedbackManager.shared.lightImpact()
                        importViewModel.errorState = nil
                        importViewModel.isCourseCodeMissing = false
                        dismiss()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                // Upload State
                uploadContentView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .frame(maxWidth: 360)
        .frame(height: 480)
        .background(Color(hex: "272010"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: AppColors.accent.opacity(0.15), radius: 24, x: 0, y: 12)
        .padding(.horizontal, 24)
    }

    private var paywallCard: some View {
        AIScanCommerceCard(
            usageOverride: importViewModel.paywallUsage,
            onCreditsAvailable: {
                importViewModel.paywallUsage = nil
                showPaywall = false
                if selectedFileURL != nil { startScan() }
            },
            onDismiss: {
                selectedFileURL = nil
                showPaywall = false
                dismiss()
            }
        )
        .frame(maxWidth: 420)
    }

    // MARK: - Premium UI Elements

    private var closeButton: some View {
        Button {
            HapticFeedbackManager.shared.lightImpact()
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color(hex: "3a3425")))
        }
    }

    private var aiAssistantGraphic: some View {
        ZStack {
            // Decorative background glow
            Circle()
                .fill(AppColors.accent.opacity(0.15))
                .frame(width: 100, height: 100)
                .blur(radius: 16)

            // Brain base psychology icon
            Image(systemName: "brain.head.profile")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .foregroundColor(Color(hex: "C19B4C"))

            // Syllabus/Document overlay (positioned on bottom-right)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(hex: "E5DCC5"))
                    .frame(width: 38, height: 46)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(hex: "272010"), lineWidth: 2)
                    )

                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "272010"))
            }
            .shadow(color: Color.black.opacity(0.3), radius: 4, x: 2, y: 2)
            .rotationEffect(.degrees(6))
            .offset(x: 24, y: 16)

            // Checkmark badge (bottom-right of document)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(Color(hex: "5B9F6A"))
                .background(Circle().fill(Color(hex: "272010")).frame(width: 14, height: 14))
                .offset(x: 36, y: 32)
        }
        .frame(width: 120, height: 120)
    }

    private var myFilesCardButton: some View {
        Button {
            HapticFeedbackManager.shared.mediumImpact()
            beginUploadFlow()
        } label: {
            HStack(spacing: Layout.Spacing.md) {
                // Folder icon container
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "eec150"))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Choose from My Files")
                        .font(.lexend(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Choose from My Files or choose your Files.")
                        .font(.lexend(size: 12, weight: .regular))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, Layout.Spacing.md)
            .padding(.vertical, Layout.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "3a3425"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.accent.opacity(0.2), lineWidth: 1)
                    )
            )
            .modifier(ShimmerSweepModifier())
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.accent.opacity(0.4), lineWidth: 1.5)
                    .blur(radius: 1)
                    .opacity(0.5)
            )
        }
        .buttonStyle(CardButtonStyle())
    }

    private var giftPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "gift.fill")
                .font(.system(size: 13))

            Text(freeScansText)
                .font(.lexend(size: 12, weight: .semibold))
        }
        .foregroundColor(AppColors.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(AppColors.accent.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(AppColors.accent.opacity(0.25), lineWidth: 1)
                )
        )
        .modifier(PremiumPulseShimmerModifier())
        .clipShape(Capsule())
    }

    private var freeScansText: String {
        guard let snapshot = activeUsageSnapshot else { return "Checking AI scan balance…" }
        if snapshot.freeRemaining > 0 { return snapshot.freeLine }
        return snapshot.heroLine
    }


    private var uploadContentView: some View {
        VStack(spacing: 0) {
            // Header / Close button row
            HStack {
                Spacer()
                closeButton
            }
            .padding(.top, 12)
            .padding(.horizontal, 16)

            Spacer(minLength: 0)

            // Graphic illustration
            aiAssistantGraphic
                .padding(.bottom, 12)

            // Title
            Text("Let's get your syllabus organized!")
                .font(.lexend(size: 20, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .padding(.bottom, 18)

            // File action card
            myFilesCardButton
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            // Gift Pill
            giftPill
                .padding(.bottom, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            selectedFileURL = url
            startScan()
        case .failure(let error):
            AppLog.debug("File import error: \(error)")
        }
    }

    private func startScan() {
        guard let url = selectedFileURL else { return }
        guard activeUsageSnapshot?.canScan != false else {
            showPaywall = true
            return
        }

        currentImportTask?.cancel()
        currentImportTask = Task {
            await importViewModel.importSyllabus(from: url)
            if !Task.isCancelled { currentImportTask = nil }
        }
    }

    private func beginUploadFlow() {
        guard activeUsageSnapshot?.canScan != false else {
            showPaywall = true
            return
        }
        showAIConsent = true
    }

    private var activeUsageSnapshot: AIScanUsageSnapshot? {
        importViewModel.paywallUsage ?? aiUsageStore.snapshot
    }
}

// MARK: - Premium Animation Modifiers

struct ShimmerSweepModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .white.opacity(0.12), .clear]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .offset(x: -geo.size.width + (phase * geo.size.width * 2))
                }
            )
            .onAppear {
                withAnimation(.linear(duration: 3.5).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

struct PremiumPulseShimmerModifier: ViewModifier {
    @State private var pulseScale: CGFloat = 1.0
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(pulseScale)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, AppColors.accent.opacity(0.2), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: -geo.size.width + (phase * geo.size.width * 2))
                }
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.03
                }
                withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

// MARK: - Scan Error View

private struct ScanErrorView: View {
    let errorState: ImportErrorState
    let isCourseCodeMissing: Bool
    let onRetry: () -> Void
    let onSubmitCourseCode: (String) -> Void
    let onDismiss: () -> Void

    @State private var courseCodeInput: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            // Icon
            Image(systemName: isCourseCodeMissing ? "text.magnifyingglass" : "exclamationmark.triangle")
                .font(.lexend(size: 32, weight: .bold))
                .foregroundColor(AppColors.accent)
                .padding(.bottom, Layout.Spacing.sm)

            // Title
            Text(isCourseCodeMissing ? "Course Code Needed" : "Something Went Wrong")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .padding(.bottom, 4)

            // Message
            Text(errorState.message)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, Layout.Spacing.lg)

            if isCourseCodeMissing {
                courseCodeSection
            } else {
                defaultButtons
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if isCourseCodeMissing {
                isTextFieldFocused = true
            }
        }
    }

    // MARK: - Course Code Input

    private var courseCodeSection: some View {
        VStack(spacing: Layout.Spacing.sm) {
            VStack(alignment: .leading, spacing: Layout.Spacing.xs) {
                Text("Course Code")
                    .font(.footnote.weight(.medium))
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.leading, 4)

                TextField("e.g. CS 101, MATH-152", text: $courseCodeInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.body)
                    .padding(.horizontal, Layout.Spacing.md)
                    .frame(height: 48)
                    .background(AppColors.background)
                    .cornerRadius(Layout.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
                    .focused($isTextFieldFocused)
                    .submitLabel(.go)
                    .onSubmit { submitCourseCode() }
            }
            .padding(.horizontal, 32)

            // Submit button
            Button(action: submitCourseCode) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Parse with Course Code")
                }
                .font(.body.weight(.semibold))
                .foregroundColor(AppColors.background)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(courseCodeInput.trimmingCharacters(in: .whitespaces).isEmpty
                            ? AppColors.accent.opacity(0.4)
                            : AppColors.accent)
                )
            }
            .disabled(courseCodeInput.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 32)

            // Cancel
            Button(action: onDismiss) {
                Text("Cancel")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 120, height: 44)
            }
            .padding(.top, Layout.Spacing.xs)
        }
    }

    // MARK: - Default Buttons

    private var defaultButtons: some View {
        HStack(spacing: 16) {
            Button(action: onDismiss) {
                Text("Cancel")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(width: 100, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            }

            Button(action: onRetry) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry")
                }
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.background)
                .frame(width: 120, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(AppColors.accent)
                )
            }
        }
        .padding(.bottom, 20)
    }

    private func submitCourseCode() {
        let trimmed = courseCodeInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        HapticFeedbackManager.shared.mediumImpact()
        onSubmitCourseCode(trimmed)
    }
}

// MARK: - AI Loading View

private struct AILoadingView: View {
    let progress: Double
    let statusMessage: String
    let onCancel: () -> Void

    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.3
    @State private var particleOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 10)

            // AI Spinner with effects (scaled down for 300pt sheet)
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppColors.accent.opacity(glowOpacity),
                                AppColors.accent.opacity(glowOpacity * 0.5),
                                AppColors.accent.opacity(glowOpacity)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 70, height: 70)
                    .scaleEffect(pulseScale)
                    .blur(radius: 3)

                // Main spinning ring
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            colors: [
                                AppColors.accent,
                                AppColors.accent.opacity(0.8),
                                AppColors.accent.opacity(0.4),
                                AppColors.accent.opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(rotation))

                // Inner progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AppColors.accent.opacity(0.3),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(-90))

                // Center AI icon
                Image(systemName: "sparkles")
                    .font(.lexend(size: 18, weight: .medium))
                    .foregroundColor(AppColors.accent)
                    .scaleEffect(pulseScale * 0.9)

                // Floating particles
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 3, height: 3)
                        .offset(
                            x: cos(Double(index) * 2.1 + particleOffset) * 35,
                            y: sin(Double(index) * 2.1 + particleOffset) * 35
                        )
                        .opacity(0.6)
                }
            }
            .frame(width: 80, height: 80)

            // Status text
            VStack(spacing: 4) {
                Text("Processing with AI")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)

                Text(statusMessage)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut(duration: 0.3), value: statusMessage)
            }

            // Progress percentage
            Text("\(Int(progress * 100))%")
                .font(.lexend(size: 24, weight: .bold))
                .foregroundColor(AppColors.accent)

            // Cancel button
            Button {
                HapticFeedbackManager.shared.lightImpact()
                onCancel()
            } label: {
                Text("Cancel")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(width: 120, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(AppColors.border, lineWidth: 1)
                    )
            }
            .padding(.top, 10)
            .padding(.bottom, 22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Continuous rotation
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            rotation = 360
        }

        // Pulse effect
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }

        // Glow effect
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowOpacity = 0.6
        }

        // Particle movement
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            particleOffset = .pi * 2
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    ZStack {
        Color.black.opacity(0.5)
            .ignoresSafeArea()

        VStack {
            Spacer()
            AISyllabusScanModal()
                .environmentObject(AppNavigationManager())
                .environmentObject(AIScanUsageStore(apiClient: UnavailableAPIClient()))
                .environmentObject(ImportViewModel(
                    extractor: PDFKitExtractor(),
                    parser: SyllabusParserRemote(apiClient: UnavailableAPIClient()),
                    eventStore: EventStore(),
                    courseRepository: CourseRepository(),
                    gradingRepository: GradingRepository()
                ))
        }
    }
}
