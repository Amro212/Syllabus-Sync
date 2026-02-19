//
//  SupabaseDataService.swift
//  Syllabus Sync
//
//  Supabase implementation of DataService
//

import Foundation
import Supabase

/// Supabase data service implementation
class SupabaseDataService: DataService {
    
    // MARK: - Properties
    
    static let shared = SupabaseDataService()
    
    /// Uses the same SupabaseClient as SupabaseAuthService to ensure
    /// auth session state (JWT) is always in sync with data queries.
    /// Having separate clients causes stale-session bugs where user A's
    /// data leaks into user B's view after sign-out/sign-in.
    private var supabase: SupabaseClient {
        authService.supabase
    }
    private let authService: SupabaseAuthService
    
    // MARK: - Initialization
    
    private init() {
        self.authService = SupabaseAuthService.shared
    }
    
    // MARK: - Helper Methods
    
    private var currentUserId: UUID? {
        guard let userIdString = authService.currentUser?.id,
              let uuid = UUID(uuidString: userIdString) else {
            return nil
        }
        return uuid
    }
    
    // MARK: - Course Operations
    
    func fetchCourses() async -> DataResult<[Course]> {
        guard let userId = currentUserId else {
            return .failure(error: .notAuthenticated)
        }
        
        do {
            let courses: [SupabaseCourse] = try await supabase
                .from("courses")
                .select()
                .eq("user_id", value: userId)
                .order("code", ascending: true)
                .execute()
                .value
            
            let domainCourses = courses.map { $0.toDomain() }
            return .success(data: domainCourses)
            
        } catch {
            return .failure(error: .databaseError(error.localizedDescription))
        }
    }
    
    func fetchCourse(byCode code: String) async -> DataResult<Course?> {
        guard let userId = currentUserId else {
            return .failure(error: .notAuthenticated)
        }
        
        do {
            let courses: [SupabaseCourse] = try await supabase
                .from("courses")
                .select()
                .eq("user_id", value: userId)
                .eq("code", value: code)
                .limit(1)
                .execute()
                .value
            
            let domainCourse = courses.first?.toDomain()
            return .success(data: domainCourse)
            
        } catch {
            return .failure(error: .databaseError(error.localizedDescription))
        }
    }
    
    func saveCourse(_ course: Course) async -> DataResult<Course> {
        guard let userId = currentUserId else {
            return .failure(error: .notAuthenticated)
        }
        
        do {
            // Check if course already exists
            let existingResult = await fetchCourse(byCode: course.code)
            
            if case .success(let existingCourse) = existingResult, existingCourse != nil {
                // Update existing course
                let updateData = SupabaseCourseInsert.fromDomain(course, userId: userId)
                
                let updated: [SupabaseCourse] = try await supabase
                    .from("courses")
                    .update(updateData)
                    .eq("code", value: course.code)
                    .select()
                    .execute()
                    .value
                
                if let updatedCourse = updated.first {
                    return .success(data: updatedCourse.toDomain())
                }
            } else {
                // Insert new course
                let insertData = SupabaseCourseInsert.fromDomain(course, userId: userId)
                
                let inserted: [SupabaseCourse] = try await supabase
                    .from("courses")
                    .insert(insertData)
                    .select()
                    .execute()
                    .value
                
                if let insertedCourse = inserted.first {
                    return .success(data: insertedCourse.toDomain())
                }
            }
            
            return .failure(error: .databaseError("Failed to save course"))
            
        } catch {
            return .failure(error: .databaseError(error.localizedDescription))
        }
    }
    
    func saveCourses(_ courses: [Course]) async -> DataResult<[Course]> {
        var savedCourses: [Course] = []
        var errors: [String] = []
        
        for course in courses {
            let result = await saveCourse(course)
            switch result {
            case .success(let savedCourse):
                savedCourses.append(savedCourse)
            case .failure(let error):
                errors.append("\(course.code): \(error.localizedDescription)")
            }
        }
        
        if !errors.isEmpty {
            return .failure(error: .databaseError("Some courses failed to save: \(errors.joined(separator: ", "))"))
        }
        
        return .success(data: savedCourses)
    }
    
    func deleteCourse(id: String) async -> DataResult<Void> {
        guard let courseUUID = UUID(uuidString: id) else {
            return .failure(error: .invalidData("Invalid course ID"))
        }
        
        guard let userId = currentUserId else {
            return .failure(error: .notAuthenticated)
        }
        
        do {
            try await supabase
                .from("courses")
                .delete()
                .eq("id", value: courseUUID)
                .eq("user_id", value: userId)
                .execute()
            
            return .success(data: ())
            
        } catch {
            return .failure(error: .databaseError(error.localizedDescription))
        }
    }
    
    // MARK: - Event Operations
    
    func fetchEvents() async -> DataResult<[EventItem]> {
        guard let userId = currentUserId else {
            return .failure(error: .notAuthenticated)
        }
        
        do {
            let events: [SupabaseEvent] = try await supabase
                .from("events")
                .select()
                .eq("user_id", value: userId)
                .order("start_date", ascending: true)
                .execute()
                .value
            
            let domainEvents = events.map { $0.toDomain() }
            return .success(data: domainEvents)
            
        } catch {
            return .failure(error: .databaseError(error.localizedDescription))
        }
    }
    
    func fetchEvents(forCourseCode courseCode: String) async -> DataResult<[EventItem]> {
        guard let userId = currentUserId else {
            return .failure(error: .notAuthenticated)
        }
        
        do {
            let events: [SupabaseEvent] = try await supabase
                .from("events")
                .select()
                .eq("user_id", value: userId)
                .eq("course_code", value: courseCode)
                .order("start_date", ascending: true)
                .execute()
                .value
            
            let domainEvents = events.map { $0.toDomain() }
            return .success(data: domainEvents)
            
        } catch {
            return .failure(error: .databaseError(error.localizedDescription))
        }
    }
    
    func fetchEvents(from startDate: Date, to endDate: Date) async -> DataResult<[EventItem]> {
        guard let userId = currentUserId else {
            return .failure(error: .notAuthenticated)
        }
        
        do {
            let events: [SupabaseEvent] = try await supabase
                .from("events")
                .select()
                .eq("user_id", value: userId)
                .gte("start_date", value: startDate.ISO8601Format())
                .lte("start_date", value: endDate.ISO8601Format())
                .order("start_date", ascending: true)
                .execute()
                .value
            
            let domainEvents = events.map { $0.toDomain() }
            return .success(data: domainEvents)
            
        } catch {
            return .failure(error: .databaseError(error.localizedDescription))
        }
    }
    
    func saveEvent(_ event: EventItem) async -> DataResult<EventItem> {
        guard let userId = currentUserId else {
            return .failure(error: .notAuthenticated)
        }
        
        do {
            // Get course ID for this event's course code
            let courseResult = await fetchCourse(byCode: event.courseCode)
            var courseId: UUID? = nil
            
            if case .success(let course) = courseResult, let course = course {
                courseId = UUID(uuidString: course.id)
            }
            
            // Check if event already exists
            if let eventUUID = UUID(uuidString: event.id) {
                // Try to update existing event
                let updateData = SupabaseEventInsert.fromDomain(event, userId: userId, courseId: courseId)
                
                let updated: [SupabaseEvent] = try await supabase
                    .from("events")
                    .update(updateData)
                    .eq("id", value: eventUUID)
                    .select()
                    .execute()
                    .value
                
                if let updatedEvent = updated.first {
                    return .success(data: updatedEvent.toDomain())
                }
            }
            
            // Insert new event
            let insertData = SupabaseEventInsert.fromDomain(event, userId: userId, courseId: courseId)
            
            let inserted: [SupabaseEvent] = try await supabase
                .from("events")
                .insert(insertData)
                .select()
                .execute()
                .value
            
            if let insertedEvent = inserted.first {
                return .success(data: insertedEvent.toDomain())
            }
            
            return .failure(error: .databaseError("Failed to save event"))
            
        } catch {
            return .failure(error: .databaseError(error.localizedDescription))
        }
    }
    
    func saveEvents(_ events: [EventItem]) async -> DataResult<[EventItem]> {
        guard let userId = currentUserId else {
            return .failure(error: .notAuthenticated)
        }
        
        do {
            // Build course code to ID mapping
            var courseIdMap: [String: UUID] = [:]
            let uniqueCourseCodes = Set(events.map { $0.courseCode })
            
            for courseCode in uniqueCourseCodes {
                let result = await fetchCourse(byCode: courseCode)
                if case .success(let course) = result,
                   let course = course,
                   let courseId = UUID(uuidString: course.id) {
                    courseIdMap[courseCode] = courseId
                }
            }
            
            // Convert events to insert DTOs
            let insertData = events.map { event in
                SupabaseEventInsert.fromDomain(
                    event,
                    userId: userId,
                    courseId: courseIdMap[event.courseCode]
                )
            }
            
            // Bulk insert
            let inserted: [SupabaseEvent] = try await supabase
                .from("events")
                .insert(insertData)
                .select()
                .execute()
                .value
            
            let domainEvents = inserted.map { $0.toDomain() }
            return .success(data: domainEvents)
            
        } catch {
            return .failure(error: .databaseError(error.localizedDescription))
        }
    }
    
    func deleteEvent(id: String) async -> DataResult<Void> {
        guard let eventUUID = UUID(uuidString: id) else {
            return .failure(error: .invalidData("Invalid event ID"))
        }
        
        guard let userId = currentUserId else {
            return .failure(error: .notAuthenticated)
        }
        
        do {
            try await supabase
                .from("events")
                .delete()
                .eq("id", value: eventUUID)
                .eq("user_id", value: userId)
                .execute()
            
            return .success(data: ())
            
        } catch {
            return .failure(error: .databaseError(error.localizedDescription))
        }
    }
    
    func deleteEvents(forCourseCode courseCode: String) async -> DataResult<Void> {
        guard let userId = currentUserId else {
            return .failure(error: .notAuthenticated)
        }
        
        do {
            try await supabase
                .from("events")
                .delete()
                .eq("user_id", value: userId)
                .eq("course_code", value: courseCode)
                .execute()
            
            return .success(data: ())
            
        } catch {
            return .failure(error: .databaseError(error.localizedDescription))
        }
    }
    
    // MARK: - Batch Operations
    
    func deleteAllData() async -> DataResult<Void> {
        guard let userId = currentUserId else {
            return .failure(error: .notAuthenticated)
        }
        
        do {
            // Delete all events first (due to foreign key constraint)
            try await supabase
                .from("events")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            
            // Then delete all courses
            try await supabase
                .from("courses")
                .delete()
                .eq("user_id", value: userId)
                .execute()
            
            return .success(data: ())
            
        } catch {
            return .failure(error: .databaseError(error.localizedDescription))
        }
    }
}
