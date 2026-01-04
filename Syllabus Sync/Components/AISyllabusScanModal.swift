//
//  AISyllabusScanModal.swift
//  Syllabus Sync
//
//  Created by Assistant on 2024-01-03.
//

import SwiftUI
import UniformTypeIdentifiers

struct AISyllabusScanModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var navigationManager: AppNavigationManager
    @EnvironmentObject var importViewModel: ImportViewModel
    
    @State private var isShowingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var currentImportTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // Background
            AppColors.surface.ignoresSafeArea()
            
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
            } else {
                // Upload State
                uploadContentView
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: importViewModel.isProcessing)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .onChange(of: importViewModel.isProcessing) { isProcessing in
            // When processing completes successfully, navigate to preview
            if !isProcessing && importViewModel.progress >= 1.0 {
                dismiss()
                navigationManager.switchTab(to: .preview)
            }
        }
    }
    
    private var uploadContentView: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.gray.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Title
            Text("AI Syllabus Scanner")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppColors.accent)
                .padding(.bottom, 6)
            
            // Description
            Text("Upload your syllabus PDF to extract dates and events")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
            
            // Upload button
            Button {
                HapticFeedbackManager.shared.mediumImpact()
                isShowingFilePicker = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 18, weight: .medium))
                    
                    Text("Upload Syllabus PDF")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .foregroundColor(AppColors.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(AppColors.accent, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 26)
                                .fill(AppColors.accent.opacity(0.15))
                        )
                )
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 12)
            
            // Secondary description
            Text("AI will identify deadlines, exams, and assignments")
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
            
            // Bottom buttons
            HStack(spacing: 16) {
                // Cancel button
                Button {
                    HapticFeedbackManager.shared.lightImpact()
                    dismiss()
                } label: {
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
                
                // Scan button
                Button {
                    HapticFeedbackManager.shared.mediumImpact()
                    if selectedFileURL != nil {
                        startScan()
                    } else {
                        isShowingFilePicker = true
                    }
                } label: {
                    Text("Scan")
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.background)
                        .frame(width: 100, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 22)
                                .fill(AppColors.accent)
                        )
                }
            }
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
            print("File import error: \(error)")
        }
    }
    
    private func startScan() {
        guard let url = selectedFileURL else { return }
        
        currentImportTask?.cancel()
        currentImportTask = Task {
            let success = await importViewModel.importSyllabus(from: url)
            if success && !Task.isCancelled {
                await MainActor.run {
                    dismiss()
                    navigationManager.switchTab(to: .preview)
                }
            }
            await MainActor.run { currentImportTask = nil }
        }
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
        VStack(spacing: 24) {
            Spacer()
            
            // AI Spinner with effects
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
                        lineWidth: 3
                    )
                    .frame(width: 100, height: 100)
                    .scaleEffect(pulseScale)
                    .blur(radius: 4)
                
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
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(rotation))
                
                // Inner progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AppColors.accent.opacity(0.3),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                // Center AI icon
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(AppColors.accent)
                    .scaleEffect(pulseScale * 0.9)
                
                // Floating particles
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 4, height: 4)
                        .offset(
                            x: cos(Double(index) * 2.1 + particleOffset) * 50,
                            y: sin(Double(index) * 2.1 + particleOffset) * 50
                        )
                        .opacity(0.6)
                }
            }
            .frame(width: 120, height: 120)
            
            // Status text
            VStack(spacing: 8) {
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
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.accent)
            
            Spacer()
            
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
            .padding(.bottom, 24)
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
        }
    }
}
