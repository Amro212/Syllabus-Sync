import Foundation
import Testing
@testable import Syllabus_Sync

@MainActor
struct Syllabus_SyncTests {
    @Test func updatingEventPersistsChanges() async throws {
        let service = MockDataService()
        let store = EventStore(dataService: service)

        let original = EventItem(
            id: "evt-1",
            courseCode: "CS101",
            type: .lecture,
            title: "Lecture 1",
            start: Date(timeIntervalSince1970: 100)
        )

        service.savedEvents = [original]
        await store.addEvents([original])

        var edited = original
        edited.title = "Lecture 1 - Updated"
        edited.location = "Hall B"
        service.savedEvents = [edited]

        await store.update(event: edited)

        #expect(store.events.count == 1)
        #expect(store.events.first?.title == "Lecture 1 - Updated")
        #expect(store.events.first?.location == "Hall B")
    }

    @Test func autoApproveReconcilesCourseEvents() async throws {
        let service = MockDataService()
        let store = EventStore(dataService: service)

        let existingCourseEvent = EventItem(
            id: "evt-1",
            courseCode: "CS101",
            type: .lecture,
            title: "Lecture 1",
            start: Date(timeIntervalSince1970: 100)
        )

        let existingOtherCourseEvent = EventItem(
            id: "evt-2",
            courseCode: "MATH101",
            type: .quiz,
            title: "Quiz",
            start: Date(timeIntervalSince1970: 200)
        )

        service.savedEvents = [existingCourseEvent, existingOtherCourseEvent]
        await store.addEvents(service.savedEvents)

        let updatedEvent = EventItem(
            id: "evt-1",
            courseCode: "CS101",
            type: .lecture,
            title: "Lecture 1 Updated",
            start: Date(timeIntervalSince1970: 150),
            location: "Room 101"
        )

        let newCourseEvent = EventItem(
            id: "evt-3",
            courseCode: "CS101",
            type: .assignment,
            title: "Homework 1",
            start: Date(timeIntervalSince1970: 250)
        )

        service.savedEvents = [updatedEvent, newCourseEvent]
        await store.autoApprove(events: [updatedEvent, newCourseEvent])

        #expect(service.deletedEventIDs.isEmpty)
        #expect(store.events.count == 3)
        #expect(store.events.contains(where: { $0.id == "evt-2" }))
        #expect(store.events.contains(where: { $0.id == "evt-3" }))
        #expect(store.events.first(where: { $0.id == "evt-1" })?.title == "Lecture 1 Updated")
        #expect(store.debugMessage?.contains("Auto-approved 2 events") == true)
    }
}

private final class MockDataService: DataService {
    var savedEvents: [EventItem] = []
    var deletedEventIDs: [String] = []

    func fetchCourses() async -> DataResult<[Course]> { .success(data: []) }
    func saveCourse(_ course: Course) async -> DataResult<Course> { .success(data: course) }
    func saveCourses(_ courses: [Course]) async -> DataResult<[Course]> { .success(data: courses) }
    func deleteCourse(id: String) async -> DataResult<Void> { .success(data: ()) }
    func fetchCourse(byCode code: String) async -> DataResult<Course?> { .success(data: nil) }

    func fetchEvents() async -> DataResult<[EventItem]> { .success(data: savedEvents) }
    func fetchEvents(forCourseCode courseCode: String) async -> DataResult<[EventItem]> {
        .success(data: savedEvents.filter { $0.courseCode == courseCode })
    }
    func fetchEvents(from startDate: Date, to endDate: Date) async -> DataResult<[EventItem]> {
        .success(data: savedEvents.filter { $0.start >= startDate && $0.start <= endDate })
    }
    func saveEvent(_ event: EventItem) async -> DataResult<EventItem> {
        if let index = savedEvents.firstIndex(where: { $0.id == event.id }) {
            savedEvents[index] = event
        } else {
            savedEvents.append(event)
        }
        return .success(data: event)
    }
    func saveEvents(_ events: [EventItem]) async -> DataResult<[EventItem]> {
        for event in events {
            if let index = savedEvents.firstIndex(where: { $0.id == event.id }) {
                savedEvents[index] = event
            } else {
                savedEvents.append(event)
            }
        }
        return .success(data: events)
    }
    func deleteEvent(id: String) async -> DataResult<Void> {
        deletedEventIDs.append(id)
        savedEvents.removeAll { $0.id == id }
        return .success(data: ())
    }
    func deleteEvents(forCourseCode courseCode: String) async -> DataResult<Void> { .success(data: ()) }

    func fetchAllGradingEntries() async -> DataResult<[GradingSchemeEntry]> { .success(data: []) }
    func fetchGradingEntries(forCourseId courseId: String) async -> DataResult<[GradingSchemeEntry]> { .success(data: []) }
    func saveGradingEntries(_ entries: [GradingSchemeEntry], forCourseId courseId: String) async -> DataResult<[GradingSchemeEntry]> {
        .success(data: entries)
    }
    func deleteGradingEntry(id: String) async -> DataResult<Void> { .success(data: ()) }
    func deleteGradingEntries(forCourseId courseId: String) async -> DataResult<Void> { .success(data: ()) }
    func deleteAllData() async -> DataResult<Void> { .success(data: ()) }
}
