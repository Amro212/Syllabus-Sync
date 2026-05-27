import Foundation
import Testing
import UserNotifications
@testable import Syllabus_Sync

struct Syllabus_SyncTests {
    @Test func plannerSchedulesTwoNotificationsForAssessmentEvents() throws {
        let calendar = Calendar(identifier: .gregorian)
        let now = try date("2026-01-01T12:00:00Z")
        let event = EventItem(
            id: "assignment-1",
            courseCode: "CS101",
            type: .assignment,
            title: "Problem Set 1",
            start: try date("2026-01-10T23:59:00Z"),
            allDay: false
        )

        let planner = AcademicNotificationPlanner(calendar: calendar, now: now, preferredHour: nil)
        let notifications = planner.plan(for: [event])

        #expect(notifications.map(\.stage) == [.early, .final])
        #expect(notifications.map(\.deliveryDate) == [
            try date("2026-01-08T23:59:00Z"),
            try date("2026-01-09T23:59:00Z")
        ])
    }

    @Test func plannerUsesExamOffsets() throws {
        let now = try date("2026-01-01T12:00:00Z")
        let event = EventItem(
            id: "final-1",
            courseCode: "MATH101",
            type: .final,
            title: "Final Exam",
            start: try date("2026-01-20T15:00:00Z"),
            allDay: false
        )

        let planner = AcademicNotificationPlanner(calendar: Calendar(identifier: .gregorian), now: now, preferredHour: nil)
        let notifications = planner.plan(for: [event])

        #expect(notifications.map(\.deliveryDate) == [
            try date("2026-01-13T15:00:00Z"),
            try date("2026-01-19T15:00:00Z")
        ])
    }

    @Test func plannerAnchorsAllDayEventsAtEightPMByDefault() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = try date("2026-01-01T12:00:00Z")
        let event = EventItem(
            id: "quiz-1",
            courseCode: "BIO101",
            type: .quiz,
            title: "Quiz 1",
            start: try date("2026-01-10T00:00:00Z"),
            allDay: true
        )

        let planner = AcademicNotificationPlanner(calendar: calendar, now: now, preferredHour: nil)
        let notifications = planner.plan(for: [event])

        #expect(notifications.map(\.deliveryDate) == [
            try date("2026-01-08T20:00:00Z"),
            try date("2026-01-09T20:00:00Z")
        ])
    }

    @Test func plannerSkipsNonAssessmentNeedsDateAndPastEvents() throws {
        let now = try date("2026-01-10T12:00:00Z")
        let events = [
            EventItem(id: "lecture-1", courseCode: "CS101", type: .lecture, title: "Lecture", start: try date("2026-01-20T12:00:00Z")),
            EventItem(id: "missing-date", courseCode: "CS101", type: .assignment, title: "TBD", start: .distantFuture, needsDate: true),
            EventItem(id: "past", courseCode: "CS101", type: .assignment, title: "Past", start: try date("2026-01-01T12:00:00Z"))
        ]

        let planner = AcademicNotificationPlanner(calendar: Calendar(identifier: .gregorian), now: now, preferredHour: nil)

        #expect(planner.plan(for: events).isEmpty)
    }

    @Test func behaviorStoreLearnsPreferredHourAfterSevenOpens() throws {
        let suiteName = "NotificationBehaviorStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let store = NotificationBehaviorStore(defaults: defaults, calendar: calendar)
        let userId = "user-1"

        for day in 1...3 {
            store.recordAppOpen(for: userId, at: try date("2026-01-0\(day)T09:00:00Z"))
        }
        #expect(store.preferredDeliveryHour(for: userId) == nil)

        for day in 4...10 {
            store.recordAppOpen(for: userId, at: try date("2026-01-\(String(format: "%02d", day))T20:00:00Z"))
        }

        #expect(store.preferredDeliveryHour(for: userId) == 20)
    }

    @Test func schedulerReplacesPendingRequestWhenEventChanges() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let center = FakeNotificationCenter(status: .authorized)
        let scheduler = AcademicNotificationScheduler(center: center, calendar: calendar)
        let identifier = AcademicNotificationPlanner.identifier(eventId: "assignment-1", stage: .early)
        center.pending = [
            request(
                identifier: identifier,
                title: "CS101: upcoming assignment",
                body: "Old title is in 2 days.",
                deliveryDate: try date("2030-01-08T23:59:00Z"),
                calendar: calendar
            )
        ]

        let event = EventItem(
            id: "assignment-1",
            courseCode: "CS101",
            type: .assignment,
            title: "Updated Problem Set",
            start: try date("2030-01-20T23:59:00Z"),
            allDay: false
        )

        await scheduler.reconcile(events: [event], userId: "user-1", preferredHour: nil)

        #expect(center.removedIdentifiers.contains(identifier))
        let updated = try #require(center.pending.first { $0.identifier == identifier })
        #expect(updated.content.body == "Updated Problem Set is in 2 days.")
        let updatedComponents = try triggerDateComponents(updated)
        #expect(updatedComponents.day == 18)
    }

    @Test func schedulerCancelsOwnedRequestsWhenAuthorizationDenied() async throws {
        let center = FakeNotificationCenter(status: .denied)
        let scheduler = AcademicNotificationScheduler(center: center)
        let ownedIdentifier = AcademicNotificationPlanner.identifier(eventId: "assignment-1", stage: .early)
        center.pending = [
            request(identifier: ownedIdentifier),
            request(identifier: "other-app.notification")
        ]

        await scheduler.reconcile(events: [], userId: "user-1", preferredHour: nil)

        #expect(center.pending.map(\.identifier) == ["other-app.notification"])
        #expect(center.removedIdentifiers == [ownedIdentifier])
    }

    @Test func cancelAllRemovesOwnedRequestsBeforeReturning() async throws {
        let center = FakeNotificationCenter(status: .authorized)
        let scheduler = AcademicNotificationScheduler(center: center)
        let ownedIdentifier = AcademicNotificationPlanner.identifier(eventId: "quiz-1", stage: .final)
        center.pending = [
            request(identifier: ownedIdentifier),
            request(identifier: "external")
        ]

        await scheduler.cancelAll()

        #expect(center.pending.map(\.identifier) == ["external"])
        #expect(center.removedIdentifiers == [ownedIdentifier])
    }
}

private func date(_ value: String) throws -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return try #require(formatter.date(from: value))
}

private func request(
    identifier: String,
    title: String = "",
    body: String = "",
    deliveryDate: Date = Date(timeIntervalSince1970: 0),
    calendar: Calendar = .current
) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: deliveryDate)
    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
}

private func triggerDateComponents(_ request: UNNotificationRequest) throws -> DateComponents {
    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    return trigger.dateComponents
}

private final class FakeNotificationCenter: UserNotificationCenterProviding {
    let status: UNAuthorizationStatus
    var pending: [UNNotificationRequest]
    private(set) var removedIdentifiers: [String] = []

    init(status: UNAuthorizationStatus, pending: [UNNotificationRequest] = []) {
        self.status = status
        self.pending = pending
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        status
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        pending
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        let removed = Set(identifiers)
        pending.removeAll { removed.contains($0.identifier) }
    }

    func add(_ request: UNNotificationRequest) async throws {
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
    }
}
