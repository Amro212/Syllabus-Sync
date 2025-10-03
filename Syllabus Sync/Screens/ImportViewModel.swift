//
//  ImportViewModel.swift
//  Syllabus Sync
//

import Combine
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
    @Published var errorState: ImportErrorState? = nil
    @Published var rawAIResponse: String? = nil  // Raw JSON response from AI for debugging

    private let extractor: PDFTextExtractor
    private let parser: SyllabusParser
    private let eventStore: EventStore
    private var progressTask: Task<Void, Never>?
    private var lastImportedURL: URL?
    private var currentRequestID: String?
    private var cancellationRequested = false
    private var eventStoreCancellable: AnyCancellable?

    init(extractor: PDFTextExtractor, parser: SyllabusParser, eventStore: EventStore) {
        self.extractor = extractor
        self.parser = parser
        self.eventStore = eventStore
        eventStoreCancellable = eventStore.$events
            .receive(on: DispatchQueue.main)
            .sink { [weak self] items in
                guard let self else { return }
                if self.events.isEmpty {
                    self.events = items
                }
            }
    }

    /// Runs the full import pipeline for the provided PDF URL.
    /// - Returns: `true` when parsing succeeded.
    @discardableResult
    func importSyllabus(from url: URL) async -> Bool {
        guard !isProcessing else { return false }

        lastImportedURL = url
        currentRequestID = UUID().uuidString
        cancellationRequested = false
        resetStateForNewImport()

        withAnimation(.easeInOut(duration: 0.3)) {
            isProcessing = true
        }
        HapticFeedbackManager.shared.mediumImpact()

        // Start the dynamic progress bar
        startDynamicProgress()

        let preview = await extractor.firstPagePreview(from: url, maxDimension: 600)
        previewImage = preview

        do {
            // Stage 1: PDF Upload (0-20%)
            await progressToRange(0, 0.2, "Preparing document...")
            if shouldCancelEarly() { return false }

            // Stage 2: OCR extraction (20-50%)
            let structured = try await extractor.extractStructured(from: url)
            extractedPlainText = structured.plain
            extractedTSV = structured.tsv
            await progressToRange(0.2, 0.5, "Processing document...")
            if shouldCancelEarly() { return false }

            guard let tsv = extractedTSV, !tsv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SyllabusParserError.emptyPayload
            }

            // Stage 3: Preprocessing (50-70%)
            await progressToRange(0.5, 0.7, "Analyzing content...")
            if shouldCancelEarly() { return false }

            // Stage 4: AI parsing (70-95%)
            parserInputText = tsv
            preprocessedParserInputText = nil
            let events = try await parser.parse(text: tsv)
            if shouldCancelEarly() { return false }

            // Stage 5: Final merge (95-100%)
            self.events = events
            await eventStore.autoApprove(events: events)
            preprocessedParserInputText = parser.latestPreprocessedText
            diagnosticsString = buildDiagnosticsString(from: parser.latestDiagnostics)
            rawAIResponse = parser.rawResponse

            // Complete the progress bar
            await completeProgress("Import complete!")
            HapticFeedbackManager.shared.success()
            withAnimation(.easeInOut(duration: 0.3)) {
                isProcessing = false
            }
            progressTask = nil
            cancellationRequested = false
            currentRequestID = nil
            return true
        } catch is CancellationError {
            handleImportCancellation()
            return false
        } catch {
            handleImportError(error)
            return false
        }
    }

    func retryLastImport() async {
        guard !isProcessing else { return }
        guard let url = lastImportedURL else { return }

        await MainActor.run {
            errorState = nil
        }

        _ = await importSyllabus(from: url)
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
        errorState = nil
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
                updateProgress(to: progress, message: finalMessage)
            } else {
                // Intermediate steps - use generic messages
                let messages = ["Processing...", "Analyzing...", "Working..."]
                let message = messages[step % messages.count]
                updateProgress(to: progress, message: message)
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
            updateProgress(to: 1.0, message: message)
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
                updateProgress(to: 1.0, message: message)
            } else {
                updateProgress(to: progress, message: message)
            }

            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s for smooth finish
        }
    }

    private func handleImportError(_ error: Error) {
        let requestID = currentRequestID ?? UUID().uuidString
        let resolved = resolveError(from: error)

        let state = ImportErrorState(
            requestID: requestID,
            type: resolved.type,
            message: resolved.message,
            timestamp: Date()
        )
        errorState = state

        logImportError(state: state, underlying: error)

        withAnimation(.easeInOut(duration: 0.3)) {
            isProcessing = false
        }
        progressTask?.cancel()
        progressTask = nil
        HapticFeedbackManager.shared.warning()
        withAnimation(.easeInOut(duration: 0.3)) {
            progress = 0
            statusMessage = "Failed"
        }
        currentRequestID = nil
    }

    func cancelImport() {
        guard isProcessing else { return }
        cancellationRequested = true
        progressTask?.cancel()
    }

    private func handleImportCancellation() {
        cancellationRequested = false
        withAnimation(.easeInOut(duration: 0.3)) {
            isProcessing = false
        }
        progressTask?.cancel()
        progressTask = nil
        errorState = nil
        HapticFeedbackManager.shared.lightImpact()
        withAnimation(.easeInOut(duration: 0.3)) {
            statusMessage = "Cancelled"
            progress = 0
        }
        currentRequestID = nil
    }

    private func shouldCancelEarly() -> Bool {
        if cancellationRequested || Task.isCancelled {
            handleImportCancellation()
            return true
        }
        return false
    }

    func applyEditedEvent(_ updated: EventItem) async {
        if let index = events.firstIndex(where: { $0.id == updated.id }) {
            events[index] = updated
        }
        await eventStore.update(event: updated)
    }

    private func resolveError(from error: Error) -> (message: String, type: ImportErrorType) {
        if let parserError = error as? SyllabusParserError {
            switch parserError {
            case .emptyPayload:
                return (parserError.errorDescription ?? "The extracted syllabus text was empty.", .validation)
            case .network(let description):
                return (description, .network)
            case .server(let description):
                return (description, .server)
            case .decoding:
                return (parserError.errorDescription ?? "Received invalid data from the parser.", .invalidResponse)
            case .unauthorized:
                return (parserError.errorDescription ?? "We couldn't authenticate with the parser service.", .server)
            case .rateLimited(let retryAfter):
                if let retryAfter {
                    return ("We're hitting parsing limits. Try again in \(retryAfter) seconds.", .server)
                }
                return (parserError.errorDescription ?? "We're hitting parsing limits. Please try again shortly.", .server)
            }
        }

        if let apiError = error as? APIClientError {
            switch apiError {
            case .invalidURL:
                return ("The parser endpoint is misconfigured.", .server)
            case .requestFailed(let underlying):
                return (underlying.localizedDescription, .network)
            case .timeout:
                return ("The parser took too long to respond. Please try again.", .network)
            case .decoding:
                return ("We received an unexpected response from the parser service.", .invalidResponse)
            case .server(_, let message, _):
                return (message ?? "The parser service returned an error.", .server)
            }
        }

        if let urlError = error as? URLError {
            return (urlError.localizedDescription, .network)
        }

        return (error.localizedDescription, .unknown)
    }

    private func logImportError(state: ImportErrorState, underlying: Error) {
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: state.timestamp)
        print("[ImportError][\(state.requestID)] [\(timestamp)] type=\(state.type.rawValue) message=\(state.message) underlying=\(underlying.localizedDescription)")
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

struct ImportErrorState: Identifiable {
    let id = UUID()
    let requestID: String
    let type: ImportErrorType
    let message: String
    let timestamp: Date
}

enum ImportErrorType: String {
    case network
    case server
    case invalidResponse
    case validation
    case unknown
}

private extension NumberFormatter {
    static let percentageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}
