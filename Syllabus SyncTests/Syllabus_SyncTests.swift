//
//  Syllabus_SyncTests.swift
//  Syllabus SyncTests
//
//  Created by Amro Zabin on 2025-09-06.
//

import Combine
import Foundation
import Testing
@testable import Syllabus_Sync

@MainActor
struct Syllabus_SyncTests {
    @Test func updatingEventPublishesChanges() async throws {
        let original = EventItem(
            id: "evt-1",
            courseCode: "CS101",
            type: .lecture,
            title: "Lecture 1",
            start: Date(),
            end: nil,
            allDay: nil,
            location: "Hall A",
            notes: "Intro lecture",
            recurrenceRule: nil,
            reminderMinutes: nil,
            confidence: nil
        )

        let store = EventStore(initialEvents: [original])

        var receivedSnapshots: [[EventItem]] = []
        let cancellable = store.$events
            .dropFirst()
            .sink { snapshot in
                receivedSnapshots.append(snapshot)
            }
        defer { cancellable.cancel() }

        var edited = original
        edited.title = "Lecture 1 - Updated"
        edited.location = "Hall B"

        await store.update(event: edited)

        #expect(store.events.count == 1)
        #expect(store.events.first?.title == "Lecture 1 - Updated")
        #expect(store.events.first?.location == "Hall B")
        #expect(receivedSnapshots.last?.first?.title == "Lecture 1 - Updated")
    }

    @Test func autoApproveReconcilesCourseEvents() async throws {
        let existingCourseEvent = EventItem(
            id: "evt-1",
            courseCode: "CS101",
            type: .lecture,
            title: "Lecture 1",
            start: Date(timeIntervalSince1970: 100),
            end: nil,
            allDay: nil,
            location: nil,
            notes: nil,
            recurrenceRule: nil,
            reminderMinutes: nil,
            confidence: nil
        )

        let existingOtherCourseEvent = EventItem(
            id: "evt-2",
            courseCode: "MATH101",
            type: .quiz,
            title: "Quiz",
            start: Date(timeIntervalSince1970: 200),
            end: nil,
            allDay: nil,
            location: nil,
            notes: nil,
            recurrenceRule: nil,
            reminderMinutes: nil,
            confidence: nil
        )

        let store = EventStore(initialEvents: [existingCourseEvent, existingOtherCourseEvent])

        let updatedEvent = EventItem(
            id: "evt-1",
            courseCode: "CS101",
            type: .lecture,
            title: "Lecture 1 Updated",
            start: Date(timeIntervalSince1970: 150),
            end: nil,
            allDay: nil,
            location: "Room 101",
            notes: "Bring notebook",
            recurrenceRule: nil,
            reminderMinutes: nil,
            confidence: nil
        )

        let newCourseEvent = EventItem(
            id: "evt-3",
            courseCode: "CS101",
            type: .assignment,
            title: "Homework 1",
            start: Date(timeIntervalSince1970: 250),
            end: nil,
            allDay: nil,
            location: nil,
            notes: "Due tonight",
            recurrenceRule: nil,
            reminderMinutes: nil,
            confidence: nil
        )

        await store.autoApprove(events: [updatedEvent, newCourseEvent])

        #expect(store.events.count == 3)
        #expect(store.events.contains(where: { $0.id == "evt-2" }))
        #expect(store.events.contains(where: { $0.id == "evt-3" }))
        guard let first = store.events.first else {
            Issue.record("Events list should contain at least one item")
            return
        }

        #expect(first.id == "evt-1")
        #expect(first.title == "Lecture 1 Updated")
        #expect(first.start <= store.events[1].start)
        #expect(store.debugMessage?.contains("Auto-approved 2 events") == true)
    }
}
