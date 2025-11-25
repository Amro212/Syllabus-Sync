import Foundation

/// Repository for managing Course entities with Supabase
@MainActor
final class CourseRepository: ObservableObject {
    @Published private(set) var courses: [Course] = []
    
    private let dataService = SupabaseDataService.shared
    
    init() {
        // Courses will be loaded when needed
    }
    
    // MARK: - Fetch
    
    func refresh() async {
        _ = await fetchCourses()
    }
    
    func fetchCourses() async -> [Course] {
        let result = await dataService.fetchCourses()
        switch result {
        case .success(let fetchedCourses):
            await MainActor.run {
                self.courses = fetchedCourses
            }
            return fetchedCourses
        case .failure(let error):
            print("Failed to fetch courses: \(error)")
            return []
        }
    }
    
    func fetchCourse(byId id: String) async -> Course? {
        // SupabaseDataService doesn't have fetchCourse(byId), so we'll fetch all and filter
        let allCourses = await fetchCourses()
        return allCourses.first { $0.id == id }
    }
    
    func fetchCourse(byCode code: String) async -> Course? {
        let result = await dataService.fetchCourse(byCode: code)
        switch result {
        case .success(let course):
            return course
        case .failure(let error):
            print("Failed to fetch course by code: \(error)")
            return nil
        }
    }
    
    // MARK: - Create/Update
    
    func save(course: Course) async {
        _ = await saveCourse(course)
    }
    
    func saveCourse(_ course: Course) async -> Course? {
        let result = await dataService.saveCourse(course)
        switch result {
        case .success(let savedCourse):
            await refresh()
            return savedCourse
        case .failure(let error):
            print("Failed to save course: \(error)")
            return nil
        }
    }
    
    func saveBatch(courses: [Course]) async {
        _ = await saveCourses(courses)
    }
    
    func saveCourses(_ courses: [Course]) async -> [Course] {
        let result = await dataService.saveCourses(courses)
        switch result {
        case .success(let savedCourses):
            await refresh()
            return savedCourses
        case .failure(let error):
            print("Failed to save courses: \(error)")
            return []
        }
    }
    
    // MARK: - Delete
    
    func delete(courseId: String) async {
        _ = await deleteCourse(id: courseId)
    }
    
    func deleteCourse(id: String) async -> Bool {
        let result = await dataService.deleteCourse(id: id)
        switch result {
        case .success:
            await refresh()
            return true
        case .failure(let error):
            print("Failed to delete course: \(error)")
            return false
        }
    }
    
    func deleteAll() async {
        // Delete all courses one by one
        let coursesToDelete = courses
        for course in coursesToDelete {
            await delete(courseId: course.id)
        }
    }
}

