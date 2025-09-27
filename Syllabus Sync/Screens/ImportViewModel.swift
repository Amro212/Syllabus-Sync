//
//  ImportViewModel.swift
//  Syllabus Sync
//

import Foundation
import SwiftUI
import UIKit

@MainActor
final class ImportViewModel: ObservableObject {
    @Published var isProcessing: Bool = false
    @Published var progress: Double = 0
    @Published var statusMessage: String = "Ready"
    @Published var events: [EventItem] = []
    @Published var diagnosticsString: String? = nil
    @Published var previewImage: UIImage? = nil
    @Published var extractedPlainText: String? = nil
    @Published var extractedTSV: String? = nil
    @Published var parserInputText: String? = nil
    @Published var preprocessedParserInputText: String? = nil
    @Published var errorMessage: String? = nil
    @Published var rawAIResponse: String? = nil  // Raw JSON response from AI for debugging

    private let extractor: PDFTextExtractor
    private let parser: SyllabusParser
    private var progressTask: Task<Void, Never>?

    init(extractor: PDFTextExtractor, parser: SyllabusParser) {
        self.extractor = extractor
        self.parser = parser
    }

    /// Runs the full import pipeline for the provided PDF URL.
    /// - Returns: `true` when parsing succeeded.
    @discardableResult
    func importSyllabus(from url: URL) async -> Bool {
        guard !isProcessing else { return false }

        resetStateForNewImport()

        isProcessing = true
        HapticFeedbackManager.shared.mediumImpact()

        // Start the dynamic progress bar
        startDynamicProgress()

        let preview = await extractor.firstPagePreview(from: url, maxDimension: 600)
        previewImage = preview

        do {
            // Stage 1: PDF Upload (0-20%)
            await progressToRange(0, 0.2, "Preparing document...")

            // Stage 2: OCR extraction (20-50%)
            let structured = try await extractor.extractStructured(from: url)
            extractedPlainText = structured.plain
            extractedTSV = structured.tsv
            await progressToRange(0.2, 0.5, "Processing document...")

            guard let tsv = extractedTSV, !tsv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SyllabusParserError.emptyPayload
            }

            // Stage 3: Preprocessing (50-70%)
            await progressToRange(0.5, 0.7, "Analyzing content...")

            // Stage 4: AI parsing (70-95%)
            parserInputText = tsv
            preprocessedParserInputText = nil
            let events = try await parser.parse(text: tsv)

            // Stage 5: Final merge (95-100%)
            self.events = events
            preprocessedParserInputText = parser.latestPreprocessedText
            diagnosticsString = buildDiagnosticsString(from: parser.latestDiagnostics)
            rawAIResponse = parser.rawResponse

            // Complete the progress bar
            await completeProgress("Import complete!")
            HapticFeedbackManager.shared.success()
            return true
        } catch {
            handleImportError(error)
            return false
        }
    }

    func clearResults() {
        events = []
        diagnosticsString = nil
        extractedPlainText = nil
        extractedTSV = nil
        parserInputText = nil
        preprocessedParserInputText = nil
        previewImage = nil
        rawAIResponse = nil
    }

    private func resetStateForNewImport() {
        errorMessage = nil
        clearResults()
        progress = 0
        statusMessage = "Ready"
        progressTask?.cancel()
        progressTask = nil
    }

    private func updateProgress(to value: Double, message: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            progress = min(max(value, 0), 1)
            statusMessage = message
        }
    }

    // MARK: - Dynamic Progress System

    private func startDynamicProgress() {
        progressTask = Task {
            // Start with immediate progress to show activity
            await updateProgress(to: 0.02, message: "Starting import...")
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
    }

    private func progressToRange(_ startRange: Double, _ endRange: Double, _ finalMessage: String) async {
        let range = endRange - startRange
        let steps = Int.random(in: 8...15) // 8-15 steps per stage
        let stepSize = range / Double(steps)

        for step in 0...steps {
            guard !Task.isCancelled else { return }
            let progress = startRange + (stepSize * Double(step))

            if step == steps {
                // Final step - use the provided message
                await updateProgress(to: progress, message: finalMessage)
            } else {
                // Intermediate steps - use generic messages
                let messages = ["Processing...", "Analyzing...", "Working..."]
                let message = messages[step % messages.count]
                await updateProgress(to: progress, message: message)
            }

            // Random delay between steps (0.1-0.3 seconds)
            let delay = Double.random(in: 0.1...0.3)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    private func completeProgress(_ message: String) async {
        progressTask?.cancel()

        // If progress is already at 100%, just update the message
        if progress >= 1.0 {
            await updateProgress(to: 1.0, message: message)
            return
        }

        // Smooth completion to 100%
        let remaining = 1.0 - progress
        let steps = Int(remaining * 20) // 20 steps to complete
        let stepSize = remaining / Double(steps)

        for step in 0...steps {
            guard !Task.isCancelled else { return }
            let progress = min(1.0, self.progress + (stepSize * Double(step)))

            if step == steps {
                await updateProgress(to: 1.0, message: message)
            } else {
                await updateProgress(to: progress, message: message)
            }

            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s for smooth finish
        }
    }

    private func handleImportError(_ error: Error) {
        let message: String

        if let parserError = error as? SyllabusParserError {
            message = parserError.errorDescription ?? "Failed to parse syllabus."
        } else if let apiError = error as? APIClientError {
            message = apiError.errorDescription ?? "Server error encountered."
        } else if let urlError = error as? URLError {
            message = urlError.localizedDescription
        } else {
            message = error.localizedDescription
        }

        errorMessage = message
        isProcessing = false
        progressTask?.cancel()
        progressTask = nil
        HapticFeedbackManager.shared.warning()
        withAnimation(.easeInOut(duration: 0.3)) {
            progress = 0
            statusMessage = "Failed"
        }
    }

    private func buildDiagnosticsString(from diagnostics: ParseDiagnostics?) -> String? {
        guard let diagnostics else { return nil }
        let source = "OpenAI"
        var components: [String] = [source]

        if let formatted = NumberFormatter.percentageFormatter.string(from: NSNumber(value: diagnostics.confidence)) {
            components.append("Confidence \(formatted)")
        }

        if let model = diagnostics.openAIModel {
            components.append(model)
        }

        if let denied = diagnostics.openAIDeniedReason {
            components.append("Denied: \(denied)")
        }

        return components.joined(separator: " • ")
    }
}

private extension NumberFormatter {
    static let percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
