//
//  SupabaseEvent.swift
//  Syllabus Sync
//
//  Database model for Event table in Supabase
//

import Foundation

/// Supabase database model for an event
struct SupabaseEvent: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let courseId: UUID?
    let courseCode: String
    let type: String  // EventType as string
    let title: String
    let startDate: Date
    let endDate: Date?
    let allDay: Bool?
    let location: String?
    let notes: String?
    let recurrenceRule: String?
    let reminderMinutes: Int?
    let confidence: Double?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case courseId = "course_id"
        case courseCode = "course_code"
        case type
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case allDay = "all_day"
        case location
        case notes
        case recurrenceRule = "recurrence_rule"
        case reminderMinutes = "reminder_minutes"
        case confidence
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Convert to domain EventItem model
    func toDomain() -> EventItem {
        return EventItem(
            id: id.uuidString,
            courseCode: courseCode,
            type: EventItem.EventType(rawValue: type) ?? .other,
            title: title,
            start: startDate,
            end: endDate,
            allDay: allDay,
            location: location,
            notes: notes,
            recurrenceRule: recurrenceRule,
            reminderMinutes: reminderMinutes,
            confidence: confidence
        )
    }
    
    /// Create from domain EventItem model
    static func fromDomain(_ event: EventItem, userId: UUID, courseId: UUID?) -> SupabaseEvent {
        return SupabaseEvent(
            id: UUID(uuidString: event.id) ?? UUID(),
            userId: userId,
            courseId: courseId,
            courseCode: event.courseCode,
            type: event.type.rawValue,
            title: event.title,
            startDate: event.start,
            endDate: event.end,
            allDay: event.allDay,
            location: event.location,
            notes: event.notes,
            recurrenceRule: event.recurrenceRule,
            reminderMinutes: event.reminderMinutes,
            confidence: event.confidence,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

/// Insert/Update DTO (without generated fields)
struct SupabaseEventInsert: Encodable {
    let userId: UUID
    let courseId: UUID?
    let courseCode: String
    let type: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let allDay: Bool?
    let location: String?
    let notes: String?
    let recurrenceRule: String?
    let reminderMinutes: Int?
    let confidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case courseId = "course_id"
        case courseCode = "course_code"
        case type
        case title
        case startDate = "start_date"
        case endDate = "end_date"
        case allDay = "all_day"
        case location
        case notes
        case recurrenceRule = "recurrence_rule"
        case reminderMinutes = "reminder_minutes"
        case confidence
    }
    
    static func fromDomain(_ event: EventItem, userId: UUID, courseId: UUID?) -> SupabaseEventInsert {
        return SupabaseEventInsert(
            userId: userId,
            courseId: courseId,
            courseCode: event.courseCode,
            type: event.type.rawValue,
            title: event.title,
            startDate: event.start,
            endDate: event.end,
            allDay: event.allDay,
            location: event.location,
            notes: event.notes,
            recurrenceRule: event.recurrenceRule,
            reminderMinutes: event.reminderMinutes,
            confidence: event.confidence
        )
    }
}
