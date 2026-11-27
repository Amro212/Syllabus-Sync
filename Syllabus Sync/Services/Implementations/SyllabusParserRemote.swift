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
    @Published private(set) var gradingScheme: [GradingSchemeEntry] = []
    @Published private(set) var usageSnapshot: AIScanUsageSnapshot?

    var latestDiagnostics: ParseDiagnostics? { diagnostics }
    var rawResponse: String? { latestRawResponse }
    var latestPreprocessedText: String? { preprocessedText }
    var latestGradingScheme: [GradingSchemeEntry] { gradingScheme }
    var latestUsageSnapshot: AIScanUsageSnapshot? { usageSnapshot }

    init(apiClient: APIClient) {
        self.apiClient = apiClient

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func parse(text: String, requestID: String?) async throws -> [EventItem] {
        try await performParse(text: text, courseCode: nil, requestID: requestID)
    }

    func parse(text: String, courseCode: String, requestID: String?) async throws -> [EventItem] {
        try await performParse(text: text, courseCode: courseCode, requestID: requestID)
    }

    private func performParse(text: String, courseCode: String?, requestID: String?) async throws -> [EventItem] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            diagnostics = nil
            throw SyllabusParserError.emptyPayload
        }

        let timezoneIdentifier = TimeZone.current.identifier
        preprocessedText = nil
        let payload = ParseRequestPayload(text: trimmed, timezone: timezoneIdentifier, courseCode: courseCode)
        let body = try encoder.encode(payload)
        var request = APIRequest(path: "/parse", method: .post, headers: [:], body: body, timeout: 90)
        request.headers["Content-Type"] = "application/json"
        request.headers["x-ai-provider"] = "openrouter"
        request.headers["x-idempotency-key"] = requestID ?? UUID().uuidString
        do {
            let token = try await SupabaseAuthService.shared.supabase.auth.session.accessToken
            request.headers["Authorization"] = "Bearer \(token)"
        } catch {
            throw SyllabusParserError.unauthorized
        }

        do {
            let (response, rawResponse): (ParseResult, String) = try await apiClient.sendWithRawResponse(request, as: ParseResult.self)
            diagnostics = mapDiagnostics(from: response)
            #if DEBUG
            latestRawResponse = rawResponse
            #else
            latestRawResponse = nil
            #endif
            preprocessedText = response.preprocessedText
            gradingScheme = response.gradingScheme ?? []
            usageSnapshot = response.usage
            return response.events
        } catch {
            latestRawResponse = nil
            preprocessedText = nil
            gradingScheme = []
            throw mapToParserError(error)
        }
    }

    private func mapDiagnostics(from response: ParseResult) -> ParseDiagnostics {
        let envelope = response.diagnostics
        let provider = envelope?.openrouter ?? envelope?.openai
        return ParseDiagnostics(
            source: response.source,
            confidence: response.confidence,
            processingTimeMs: envelope?.processingTimeMs,
            textLength: envelope?.textLength,
            warnings: envelope?.warnings,
            validation: envelope?.validation,
            aiModel: provider?.usedModel,
            aiProcessingTimeMs: provider?.processingTimeMs,
            aiDeniedReason: provider?.denied
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
            case .server(let status, let message, let retryAfter, let rawBody):
                switch status {
                case 401:
                    return .unauthorized
                case 422 where message?.contains("course code") == true:
                    return .courseCodeMissing
                case 429:
                    return .rateLimited(retryAfter: retryAfter)
                case 402:
                    return .paymentRequired(usage: decodeUsageSnapshot(from: rawBody))
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

    private func decodeUsageSnapshot(from rawBody: String?) -> AIScanUsageSnapshot? {
        guard let rawBody, let data = rawBody.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AIScanUsageEnvelope.self, from: data).usage
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
    let courseCode: String?
}
