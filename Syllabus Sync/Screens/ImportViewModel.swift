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
    private let courseRepository = CourseRepository()
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

        // Kick off with an immediate tiny tick so the bar is visibly alive
        updateProgress(to: 0.02, message: "Preparing document...")

        let preview = await extractor.firstPagePreview(from: url, maxDimension: 600)
        previewImage = preview

        do {
            // Stage 1: OCR extraction — crawl concurrently toward 0.47 while work runs
            let crawl1 = startProgressCrawl(toward: 0.47, message: "Reading document...")
            if shouldCancelEarly() { crawl1.cancel(); return false }
            let structured = try await extractor.extractStructured(from: url)
            crawl1.cancel()
            extractedPlainText = structured.plain
            extractedTSV = structured.tsv
            await snapProgress(to: 0.5, message: "Document ready")
            if shouldCancelEarly() { return false }

            guard let tsv = extractedTSV, !tsv.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SyllabusParserError.emptyPayload
            }

            // Stage 2: AI parsing — crawl concurrently toward 0.92 while work runs
            parserInputText = tsv
            preprocessedParserInputText = nil
            let crawl2 = startProgressCrawl(toward: 0.92, message: "Analyzing content...")
            if shouldCancelEarly() { crawl2.cancel(); return false }
            let events = try await parser.parse(text: tsv)
            crawl2.cancel()
            if shouldCancelEarly() { return false }

            // Stage 3: Final merge & persist (95-100%)
            self.events = events
            await snapProgress(to: 0.95, message: "Saving events...")

            // Save events to Supabase
            await eventStore.autoApprove(events: events)

            // Extract and save courses from events
            let uniqueCourseCodes = Set(events.map { $0.courseCode })
            for courseCode in uniqueCourseCodes {
                // Check if course already exists
                if await courseRepository.fetchCourse(byCode: courseCode) == nil {
                    let course = Course(id: UUID().uuidString, code: courseCode)
                    _ = await courseRepository.saveCourse(course)
                }
            }

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

    /// Starts a background Task that crawls progress from its current value toward
    /// `ceiling` using exponential decay — large steps first, tiny steps near the top.
    /// This produces organic-feeling, variable-speed motion that naturally decelerates
    /// without ever touching the ceiling.
    /// The caller **must** cancel the returned Task once the real work completes.
    @discardableResult
    private func startProgressCrawl(toward ceiling: Double, message: String) -> Task<Void, Never> {
        Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let gap = ceiling - self.progress
                guard gap > 0.005 else {
                    // Hovering just below the ceiling — hold position
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    continue
                }
                // Each step consumes a random fraction of the remaining gap.
                // Result: fast at the start, exponentially slower near the ceiling.
                let step = gap * Double.random(in: 0.07...0.17)
                self.updateProgress(to: min(self.progress + step, ceiling - 0.004), message: message)
                // Randomise delay too so consecutive ticks never feel rhythmic.
                let delay = Double.random(in: 0.22...0.52)
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    /// Snaps progress to an exact value with a quick animation, then settles briefly.
    private func snapProgress(to value: Double, message: String) async {
        updateProgress(to: value, message: message)
        try? await Task.sleep(nanoseconds: 120_000_000) // ~0.12 s settle
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
    
    // MARK: - Course & UserPrefs Persistence
    
    /// Extract unique courses from imported events
    private func extractCoursesFromEvents(_ events: [EventItem]) -> [Course] {
        let uniqueCourseCodes = Set(events.map { $0.courseCode })
        return uniqueCourseCodes.map { courseCode in
            Course(code: courseCode, title: courseCode)
        }
    }
    
    // UserPrefs functionality removed - no longer needed with Supabase
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
