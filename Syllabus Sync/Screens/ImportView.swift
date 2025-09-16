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
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingFilePicker = false
    @State private var isProcessing = false
    @State private var processingProgress: Double = 0.0
    @State private var processingStep = "Preparing..."
    @State private var extractedSnippet: String? = nil
    @State private var extractedTSV: String? = nil
    @State private var firstPageImage: UIImage? = nil
    @State private var showPreview: Bool = false
    
    private let processingSteps = [
        "Preparing...",
        "Reading PDF...",
        "Extracting text...",
        "Analyzing content...",
        "Finding dates...",
        "Creating events...",
        "Finalizing..."
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if isProcessing {
                    ProcessingView(
                        progress: processingProgress,
                        step: processingStep
                    )
                    .transition(.opacity)
                } else {
                    ImportContentView(
                        onFilePicker: { isShowingFilePicker = true },
                        onImport: { startImporting() }
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
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showPreview) {
            ExtractionPreviewView(image: firstPageImage, text: extractedSnippet ?? "", tsv: extractedTSV ?? "")
        }
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }
    
    private func startImporting() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isProcessing = true
        }
        HapticFeedbackManager.shared.mediumImpact()
    }
    
    private func simulateProcessing() {
        let stepDuration = 0.8
        let totalSteps = processingSteps.count
        
        for (index, step) in processingSteps.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * stepDuration) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    processingStep = step
                    processingProgress = Double(index + 1) / Double(totalSteps)
                }
                
                // Add haptic feedback for progress milestones
                if index == 2 || index == 5 {
                    HapticFeedbackManager.shared.lightImpact()
                }
            }
        }
        
        // Complete the import
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(totalSteps) * stepDuration + 0.5) {
            completeImport()
        }
    }
    
    private func completeImport() {
        HapticFeedbackManager.shared.success()
        
        // Dismiss modal and navigate to Calendar tab
        dismiss()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            navigationManager.switchTab(to: .preview) // Calendar tab
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            startImporting()
            Task {
                processingStep = "Reading PDF..."
                let extractor = PDFKitExtractor()
                let preview = await extractor.firstPagePreview(from: url, maxDimension: 600)
                await MainActor.run { self.firstPageImage = preview }
                processingStep = "Extracting text..."
                do {
                    let structured = try await extractor.extractStructured(from: url)
                    let snippet = structured.plain // show full text in preview
                    await MainActor.run {
                        self.extractedSnippet = snippet
                        self.extractedTSV = structured.tsv
                        self.processingStep = "Completed"
                        self.processingProgress = 1.0
                        self.isProcessing = false
                        self.showPreview = true
                    }
                    HapticFeedbackManager.shared.success()
                } catch {
                    await MainActor.run {
                        self.extractedSnippet = "Extraction failed: \(error.localizedDescription)"
                        self.isProcessing = false
                        self.showPreview = true
                    }
                    HapticFeedbackManager.shared.warning()
                }
            }
        case .failure(let error):
            print("File import error: \(error)")
        }
    }
}

// MARK: - Import Content View

struct ImportContentView: View {
    let onFilePicker: () -> Void
    let onImport: () -> Void
    
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
                
                // Secondary demo button
                Button {
                    HapticFeedbackManager.shared.lightImpact()
                    onImport() // Trigger demo import
                } label: {
                    HStack(spacing: Layout.Spacing.sm) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 18, weight: .medium))
                        
                        Text("Try Sample Import")
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(AppColors.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AppColors.surface)
                    .cornerRadius(Layout.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.CornerRadius.md)
                            .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                    )
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
    
    var body: some View {
        VStack(spacing: Layout.Spacing.xxxl) {
            Spacer()
            
            // Processing animation
            VStack(spacing: Layout.Spacing.xl) {
                // Animated processing icon
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.1))
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .fill(AppColors.accent.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    // Spinning icon
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(AppColors.accent)
                        .rotationEffect(.degrees(progress * 360))
                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: progress)
                }
                .shadow(color: AppColors.accent.opacity(0.2), radius: 20, x: 0, y: 10)
                
                // Progress content
                VStack(spacing: Layout.Spacing.lg) {
                    Text("Processing Your Syllabus")
                        .font(.titleL)
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("We're analyzing your document and extracting important information.")
                        .font(.body)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Layout.Spacing.lg)
                }
            }
            
            Spacer()
            
            // Progress indicator
            VStack(spacing: Layout.Spacing.lg) {
                // Progress bar
                VStack(spacing: Layout.Spacing.sm) {
                    HStack {
                        Text(step)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary)
                        
                        Spacer()
                        
                        Text("\(Int(progress * 100))%")
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.accent)
                    }
                    
                    // Progress bar track
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.xs)
                                .fill(AppColors.separator)
                                .frame(height: 8)
                            
                            RoundedRectangle(cornerRadius: Layout.CornerRadius.xs)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.purple,
                                            Color.blue
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * progress, height: 8)
                                .animation(.easeInOut(duration: 0.3), value: progress)
                        }
                    }
                    .frame(height: 8)
                }
                
                Text("This usually takes a few seconds...")
                    .font(.caption)
                    .foregroundColor(AppColors.textTertiary)
            }
            .padding(.horizontal, Layout.Spacing.lg)
            .padding(.bottom, Layout.Spacing.xl)
        }
        .padding(.horizontal, Layout.Spacing.lg)
    }
}

// MARK: - Preview

#Preview {
    ImportView()
        .environmentObject(AppNavigationManager())
}
