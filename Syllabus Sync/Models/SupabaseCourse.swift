//
//  SupabaseCourse.swift
//  Syllabus Sync
//
//  Database model for Course table in Supabase
//

import Foundation

/// Supabase database model for a course
struct SupabaseCourse: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let code: String
    let title: String?
    let colorHex: String?
    let instructor: String?
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case code
        case title
        case colorHex = "color_hex"
        case instructor
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    /// Convert to domain Course model
    func toDomain() -> Course {
        return Course(
            id: id.uuidString,
            code: code,
            title: title,
            colorHex: colorHex,
            instructor: instructor
        )
    }
    
    /// Create from domain Course model
    static func fromDomain(_ course: Course, userId: UUID) -> SupabaseCourse {
        return SupabaseCourse(
            id: UUID(uuidString: course.id) ?? UUID(),
            userId: userId,
            code: course.code,
            title: course.title,
            colorHex: course.colorHex,
            instructor: course.instructor,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}

/// Insert/Update DTO (without generated fields)
struct SupabaseCourseInsert: Encodable {
    let userId: UUID
    let code: String
    let title: String?
    let colorHex: String?
    let instructor: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case code
        case title
        case colorHex = "color_hex"
        case instructor
    }
    
    static func fromDomain(_ course: Course, userId: UUID) -> SupabaseCourseInsert {
        return SupabaseCourseInsert(
            userId: userId,
            code: course.code,
            title: course.title,
            colorHex: course.colorHex,
            instructor: course.instructor
        )
    }
}
