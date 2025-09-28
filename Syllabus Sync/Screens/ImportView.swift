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
                        onFilePicker: { isShowingFilePicker = true },
                        onImport: { isShowingFilePicker = true }
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
                    .foregroundColor(AppColors.textSecondary)
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
                defer { Task { await MainActor.run { currentImportTask = nil } } }
                await MainActor.run { isShowingFilePicker = false }
                let success = await importViewModel.importSyllabus(from: url)
                if success && !Task.isCancelled {
                    await MainActor.run {
                        dismiss()
                        navigationManager.switchTab(to: .preview)
                    }
                }
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
