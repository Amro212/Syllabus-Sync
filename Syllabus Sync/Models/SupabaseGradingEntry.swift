//
//  SupabaseGradingEntry.swift
//  Syllabus Sync
//
//  Database model for grading_entries table in Supabase.
//

import Foundation

/// Supabase database model for a grading entry
struct SupabaseGradingEntry: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let courseId: UUID
    let name: String
    let weight: Double?
    let type: String
    let sortOrder: Int
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case courseId = "course_id"
        case name
        case weight
        case type
        case sortOrder = "sort_order"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    /// Convert to domain model
    func toDomain() -> GradingSchemeEntry {
        GradingSchemeEntry(
            id: id.uuidString,
            name: name,
            weight: weight,
            type: type,
            courseId: courseId.uuidString,
            sortOrder: sortOrder
        )
    }

    /// Create from domain model
    static func fromDomain(_ entry: GradingSchemeEntry, courseId: UUID, userId: UUID) -> SupabaseGradingEntry {
        SupabaseGradingEntry(
            id: UUID(uuidString: entry.id) ?? UUID(),
            userId: userId,
            courseId: courseId,
            name: entry.name,
            weight: entry.weight,
            type: entry.type,
            sortOrder: entry.sortOrder ?? 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

/// Insert/Update DTO (without server-generated fields)
struct SupabaseGradingEntryInsert: Encodable {
    let id: UUID
    let userId: UUID
    let courseId: UUID
    let name: String
    let weight: Double?
    let type: String
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case courseId = "course_id"
        case name
        case weight
        case type
        case sortOrder = "sort_order"
    }

    static func fromDomain(_ entry: GradingSchemeEntry, courseId: UUID, userId: UUID) -> SupabaseGradingEntryInsert {
        SupabaseGradingEntryInsert(
            id: UUID(uuidString: entry.id) ?? UUID(),
            userId: userId,
            courseId: courseId,
            name: entry.name,
            weight: entry.weight,
            type: entry.type,
            sortOrder: entry.sortOrder ?? 0
        )
    }
}
