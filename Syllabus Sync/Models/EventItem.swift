//
//  EventItem.swift
//  Syllabus Sync
//
//  Created for Milestone 8.2 — shared DTO decoded from the parsing service.
//

import Foundation

/// Represents a course-related event returned by the parsing service.
struct EventItem: Identifiable, Codable, Equatable {
    enum EventType: String, Codable {
        case assignment = "ASSIGNMENT"
        case quiz = "QUIZ"
        case midterm = "MIDTERM"
        case final = "FINAL"
        case lab = "LAB"
        case lecture = "LECTURE"
        case other = "OTHER"
    }

    let id: String
    let courseCode: String
    let type: EventType
    let title: String
    let start: Date
    let end: Date?
    let allDay: Bool?
    let location: String?
    let notes: String?
    let recurrenceRule: String?
    let reminderMinutes: Int?
    let confidence: Double?
}

/// Diagnostics metadata surfaced by the parsing service.
struct ParseDiagnostics: Equatable {
    enum Source: String, Codable {
        case openai
    }

    let source: Source
    let confidence: Double
    let processingTimeMs: Int?
    let textLength: Int?
    let warnings: [String]?
    let validation: ParseResult.DiagnosticsPayload.Validation?
    let openAIModel: String?
    let openAIProcessingTimeMs: Int?
    let openAIDeniedReason: String?
}

/// Complete response returned by the `/parse` endpoint.
struct ParseResult: Decodable {
    let events: [EventItem]
    let source: ParseDiagnostics.Source
    let confidence: Double
    let preprocessedText: String?
    let diagnostics: DiagnosticsPayload?

    struct DiagnosticsPayload: Decodable {
        let source: ParseDiagnostics.Source
        let processingTimeMs: Int?
        let textLength: Int?
        let warnings: [String]?
        let validation: Validation?
        let openai: OpenAI?

        struct Validation: Decodable, Equatable {
            let totalEvents: Int?
            let validEvents: Int?
            let invalidEvents: Int?
            let clampedEvents: Int?
            let defaultsApplied: Int?
        }

        struct OpenAI: Decodable {
            let processingTimeMs: Int?
            let usedModel: String?
            let denied: String?
        }
    }
}
