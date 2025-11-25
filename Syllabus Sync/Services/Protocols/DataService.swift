//
//  DataService.swift
//  Syllabus Sync
//
//  Protocol for data persistence operations
//

import Foundation

/// Result type for data operations
enum DataResult<T> {
    case success(data: T)
    case failure(error: DataError)
}

/// Data operation errors
enum DataError: Error, LocalizedError {
    case notAuthenticated
    case networkError(String)
    case databaseError(String)
    case notFound
    case invalidData(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .networkError(let message):
            return "Network error: \(message)"
        case .databaseError(let message):
            return "Database error: \(message)"
        case .notFound:
            return "Resource not found"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
}

/// Protocol for data persistence service
protocol DataService {
    // MARK: - Course Operations
    
    /// Fetch all courses for the current user
    func fetchCourses() async -> DataResult<[Course]>
    
    /// Save a single course
    func saveCourse(_ course: Course) async -> DataResult<Course>
    
    /// Save multiple courses
    func saveCourses(_ courses: [Course]) async -> DataResult<[Course]>
    
    /// Delete a course by ID
    func deleteCourse(id: String) async -> DataResult<Void>
    
    /// Fetch a single course by code
    func fetchCourse(byCode code: String) async -> DataResult<Course?>
    
    // MARK: - Event Operations
    
    /// Fetch all events for the current user
    func fetchEvents() async -> DataResult<[EventItem]>
    
    /// Fetch events for a specific course
    func fetchEvents(forCourseCode courseCode: String) async -> DataResult<[EventItem]>
    
    /// Fetch events within a date range
    func fetchEvents(from startDate: Date, to endDate: Date) async -> DataResult<[EventItem]>
    
    /// Save a single event
    func saveEvent(_ event: EventItem) async -> DataResult<EventItem>
    
    /// Save multiple events
    func saveEvents(_ events: [EventItem]) async -> DataResult<[EventItem]>
    
    /// Delete an event by ID
    func deleteEvent(id: String) async -> DataResult<Void>
    
    /// Delete all events for a course
    func deleteEvents(forCourseCode courseCode: String) async -> DataResult<Void>
    
    // MARK: - Batch Operations
    
    /// Delete all user data
    func deleteAllData() async -> DataResult<Void>
}
