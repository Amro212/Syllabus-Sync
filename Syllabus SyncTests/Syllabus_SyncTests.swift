import Foundation
import Testing
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
}

private func date(_ value: String) throws -> Date {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return try #require(formatter.date(from: value))
}
