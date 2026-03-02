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
    var type: EventType
    var title: String
    var start: Date
    var end: Date?
    var allDay: Bool?
    var location: String?
    var notes: String?
    var recurrenceRule: String?
    var reminderMinutes: Int?
    var confidence: Double?
    /// When `true`, the syllabus did not contain a date for this event
    /// and the user must supply one. `start` is set to `.distantFuture`
    /// as a sentinel so existing sorting/filtering code continues to work.
    var needsDate: Bool
    /// The exact syllabus text the AI used to determine the date.
    /// Nil when no evidence was found.
    var dateSource: String?

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, courseCode, type, title, start, end, allDay, location
        case notes, recurrenceRule, reminderMinutes, confidence, needsDate, dateSource
    }

    init(
        id: String,
        courseCode: String,
        type: EventType,
        title: String,
        start: Date,
        end: Date? = nil,
        allDay: Bool? = nil,
        location: String? = nil,
        notes: String? = nil,
        recurrenceRule: String? = nil,
        reminderMinutes: Int? = nil,
        confidence: Double? = nil,
        needsDate: Bool = false,
        dateSource: String? = nil
    ) {
        self.id = id
        self.courseCode = courseCode
        self.type = type
        self.title = title
        self.start = start
        self.end = end
        self.allDay = allDay
        self.location = location
        self.notes = notes
        self.recurrenceRule = recurrenceRule
        self.reminderMinutes = reminderMinutes
        self.confidence = confidence
        self.needsDate = needsDate
        self.dateSource = dateSource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        courseCode = try container.decode(String.self, forKey: .courseCode)
        type = try container.decode(EventType.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        // `start` may be null when the syllabus contained no date for this event.
        // Use `.distantFuture` as a sentinel so sorting always works.
        let decodedStart = try container.decodeIfPresent(Date.self, forKey: .start)
        start = decodedStart ?? .distantFuture
        end = try container.decodeIfPresent(Date.self, forKey: .end)
        allDay = try container.decodeIfPresent(Bool.self, forKey: .allDay)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        recurrenceRule = try container.decodeIfPresent(String.self, forKey: .recurrenceRule)
        reminderMinutes = try container.decodeIfPresent(Int.self, forKey: .reminderMinutes)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        let decodedNeedsDate = try container.decodeIfPresent(Bool.self, forKey: .needsDate)
        needsDate = decodedNeedsDate ?? (decodedStart == nil)
        dateSource = try container.decodeIfPresent(String.self, forKey: .dateSource)
    }
}

extension EventItem.EventType: CaseIterable {}

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
