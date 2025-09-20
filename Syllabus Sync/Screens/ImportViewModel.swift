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
    @Published var errorMessage: String? = nil
    @Published var rawAIResponse: String? = nil  // Raw JSON response from AI for debugging

    private let extractor: PDFTextExtractor
    private let parser: SyllabusParser

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
        updateProgress(to: 0.05, message: "Preparing document...")

        let preview = await extractor.firstPagePreview(from: url, maxDimension: 600)
        previewImage = preview

        do {
            updateProgress(to: 0.15, message: "Extracting text...")
            let structured = try await extractor.extractStructured(from: url)
            extractedPlainText = structured.plain
            extractedTSV = structured.tsv
            updateProgress(to: 0.3, message: "Preparing request...")

            guard let plain = extractedPlainText, !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SyllabusParserError.emptyPayload
            }

            updateProgress(to: 0.45, message: "Sending to server...")
            updateProgress(to: 0.6, message: "Waiting for parser...")
            updateProgress(to: 0.75, message: "Waiting for parser...")

            let events = try await parser.parse(text: plain)

            updateProgress(to: 0.9, message: "Finalizing results...")
            self.events = events
            diagnosticsString = buildDiagnosticsString(from: parser.latestDiagnostics)
            rawAIResponse = parser.rawResponse

            updateProgress(to: 1.0, message: "Done!")
            isProcessing = false
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
        previewImage = nil
        rawAIResponse = nil
    }

    private func resetStateForNewImport() {
        errorMessage = nil
        clearResults()
        progress = 0
        statusMessage = "Ready"
    }

    private func updateProgress(to value: Double, message: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            progress = min(max(value, 0), 1)
            statusMessage = message
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
        HapticFeedbackManager.shared.warning()
        withAnimation(.easeInOut(duration: 0.3)) {
            progress = 0
            statusMessage = "Failed"
        }
    }

    private func buildDiagnosticsString(from diagnostics: ParseDiagnostics?) -> String? {
        guard let diagnostics else { return nil }
        let source = diagnostics.source == .heuristics ? "Heuristics" : "OpenAI"
        var components: [String] = [source]

        if let formatted = NumberFormatter.percentageFormatter.string(from: NSNumber(value: diagnostics.confidence)) {
            components.append("Confidence \(formatted)")
        }

        if diagnostics.source == .openai, let model = diagnostics.openAIModel {
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
