//
//  SyllabusParser.swift
//  Syllabus Sync
//

import Foundation

/// Abstraction for any component capable of parsing raw syllabus text into events.
protocol SyllabusParser {
    @MainActor
    var latestDiagnostics: ParseDiagnostics? { get }

    @MainActor
    func parse(text: String) async throws -> [EventItem]
}

/// Lightweight errors surfaced to the UI when parsing fails.
enum SyllabusParserError: LocalizedError {
    case emptyPayload
    case network(description: String)
    case server(description: String)
    case decoding
    case unauthorized
    case rateLimited(retryAfter: Int?)

    var errorDescription: String? {
        switch self {
        case .emptyPayload:
            return "The extracted syllabus text was empty."
        case .network(let message):
            return message
        case .server(let message):
            return message
        case .decoding:
            return "The server returned data in an unexpected format."
        case .unauthorized:
            return "We couldn't authenticate with the server. Please try again later."
        case .rateLimited(let retryAfter):
            if let retryAfter {
                return "We've hit the parsing limit. Please retry in \(retryAfter) seconds."
            }
            return "We've hit the parsing limit. Please try again shortly."
        }
    }
}
