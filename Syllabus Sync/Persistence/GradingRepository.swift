//
//  GradingRepository.swift
//  Syllabus Sync
//
//  In-memory cache + Supabase CRUD for grading scheme data.
//

import Foundation

@MainActor
final class GradingRepository: ObservableObject {
    /// Grading entries keyed by course ID for fast lookup.
    @Published private(set) var gradingByCourse: [String: [GradingSchemeEntry]] = [:]

    private let dataService = SupabaseDataService.shared

    // MARK: - Fetch

    /// Fetch all grading entries across every course and populate the cache.
    func fetchAll() async {
        let result = await dataService.fetchAllGradingEntries()
        switch result {
        case .success(let entries):
            var grouped: [String: [GradingSchemeEntry]] = [:]
            for entry in entries {
                guard let cid = entry.courseId else { continue }
                grouped[cid, default: []].append(entry)
            }
            self.gradingByCourse = grouped
        case .failure(let error):
            print("GradingRepository: failed to fetch all – \(error)")
        }
    }

    /// Fetch grading entries for a single course.
    func fetch(forCourseId courseId: String) async -> [GradingSchemeEntry] {
        let result = await dataService.fetchGradingEntries(forCourseId: courseId)
        switch result {
        case .success(let entries):
            gradingByCourse[courseId] = entries
            return entries
        case .failure(let error):
            print("GradingRepository: failed to fetch for course \(courseId) – \(error)")
            return gradingByCourse[courseId] ?? []
        }
    }

    // MARK: - Save

    /// Replace all grading entries for a course (delete + insert).
    @discardableResult
    func save(entries: [GradingSchemeEntry], forCourseId courseId: String) async -> [GradingSchemeEntry] {
        let result = await dataService.saveGradingEntries(entries, forCourseId: courseId)
        switch result {
        case .success(let saved):
            gradingByCourse[courseId] = saved
            return saved
        case .failure(let error):
            print("GradingRepository: failed to save for course \(courseId) – \(error)")
            return gradingByCourse[courseId] ?? []
        }
    }

    // MARK: - Delete

    /// Delete all grading entries for a course.
    func delete(forCourseId courseId: String) async {
        let result = await dataService.deleteGradingEntries(forCourseId: courseId)
        if case .success = result {
            gradingByCourse.removeValue(forKey: courseId)
        }
    }

    /// Clear the local cache (e.g. on sign-out).
    func clearCache() {
        gradingByCourse = [:]
    }
}
