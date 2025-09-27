//
//  SyllabusParserRemote.swift
//  Syllabus Sync
//

import Foundation

@MainActor
final class SyllabusParserRemote: ObservableObject, SyllabusParser {
    private let apiClient: APIClient
    private let encoder: JSONEncoder

    @Published private(set) var diagnostics: ParseDiagnostics?
    @Published private(set) var latestRawResponse: String?
    @Published private(set) var preprocessedText: String?

    var latestDiagnostics: ParseDiagnostics? { diagnostics }
    var rawResponse: String? { latestRawResponse }
    var latestPreprocessedText: String? { preprocessedText }

    init(apiClient: APIClient) {
        self.apiClient = apiClient

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func parse(text: String) async throws -> [EventItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            diagnostics = nil
            throw SyllabusParserError.emptyPayload
        }

        let timezoneIdentifier = TimeZone.current.identifier
        preprocessedText = nil
        let payload = ParseRequestPayload(text: trimmed, timezone: timezoneIdentifier)
        let body = try encoder.encode(payload)
        var request = APIRequest(path: "/parse", method: .post, headers: [:], body: body, timeout: 90)
        request.headers["Content-Type"] = "application/json"

        do {
            let (response, rawResponse): (ParseResult, String) = try await apiClient.sendWithRawResponse(request, as: ParseResult.self)
            diagnostics = mapDiagnostics(from: response)
            latestRawResponse = rawResponse
            preprocessedText = response.preprocessedText
            return response.events
        } catch {
            latestRawResponse = nil
            preprocessedText = nil
            throw mapToParserError(error)
        }
    }

    private func mapDiagnostics(from response: ParseResult) -> ParseDiagnostics {
        let envelope = response.diagnostics
        return ParseDiagnostics(
            source: response.source,
            confidence: response.confidence,
            processingTimeMs: envelope?.processingTimeMs,
            textLength: envelope?.textLength,
            warnings: envelope?.warnings,
            validation: envelope?.validation,
            openAIModel: envelope?.openai?.usedModel,
            openAIProcessingTimeMs: envelope?.openai?.processingTimeMs,
            openAIDeniedReason: envelope?.openai?.denied
        )
    }

    private func mapToParserError(_ error: Error) -> SyllabusParserError {
        if let apiError = error as? APIClientError {
            switch apiError {
            case .invalidURL:
                return .server(description: "The parser endpoint is misconfigured.")
            case .requestFailed(let underlying):
                return .network(description: friendlyMessage(for: underlying))
            case .timeout:
                return .network(description: "The parser took too long to respond. Please try again.")
            case .decoding:
                return .decoding
            case .server(let status, let message, let retryAfter):
                switch status {
                case 401:
                    return .unauthorized
                case 429:
                    return .rateLimited(retryAfter: retryAfter)
                default:
                    return .server(description: message ?? "The parser returned an error (status \(status)).")
                }
            }
        }

        if let urlError = error as? URLError {
            return .network(description: friendlyMessage(for: urlError))
        }

        return .server(description: error.localizedDescription)
    }

    private func friendlyMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            return friendlyMessage(for: urlError)
        }
        return "Unable to reach the server. Please check your connection and try again."
    }

    private func friendlyMessage(for error: URLError) -> String {
        switch error.code {
        case .notConnectedToInternet:
            return "You're offline. Please check your internet connection."
        case .timedOut:
            return "The request timed out. Please try again."
        case .networkConnectionLost:
            return "The network connection was interrupted."
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            return "We couldn't reach the parsing service."
        default:
            return error.localizedDescription
        }
    }
}

private struct ParseRequestPayload: Encodable {
    let text: String
    let timezone: String
}
