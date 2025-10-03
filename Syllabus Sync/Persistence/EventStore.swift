import Foundation

/// In-memory repository for event data during Milestone 9.4.
/// Persists edits within the app session and publishes changes to dependent views.
@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var events: [EventItem]
    @Published private(set) var debugMessage: String?

    init(initialEvents: [EventItem] = []) {
        events = Self.sorted(initialEvents)
    }

    /// Refreshes the published events. Placeholder for parity with the upcoming Core Data implementation.
    func refresh() async {
        events = Self.sorted(events)
    }

    /// Replaces existing events with the newly approved ones while keeping unrelated courses intact.
    func autoApprove(events newEvents: [EventItem]) async {
        guard !newEvents.isEmpty else { return }

        var snapshot = events
        let courseCodes = Set(newEvents.map { $0.courseCode })
        let ids = Set(newEvents.map { $0.id })

        snapshot.removeAll { event in
            courseCodes.contains(event.courseCode) && !ids.contains(event.id)
        }

        for event in newEvents {
            if let index = snapshot.firstIndex(where: { $0.id == event.id }) {
                snapshot[index] = event
            } else {
                snapshot.append(event)
            }
        }

        events = Self.sorted(snapshot)
        debugMessage = Self.makeDebugMessage(importedCount: newEvents.count)
    }

    func deleteAllEvents() async {
        events.removeAll()
        debugMessage = nil
    }

    /// Applies user edits to the in-memory store and republishes the sorted event list.
    func update(event: EventItem) async {
        var snapshot = events
        if let index = snapshot.firstIndex(where: { $0.id == event.id }) {
            snapshot[index] = event
        } else {
            snapshot.append(event)
        }

        events = Self.sorted(snapshot)
    }
}

// MARK: - Helpers

private extension EventStore {
    static func sorted(_ events: [EventItem]) -> [EventItem] {
        events.sorted { lhs, rhs in
            if lhs.start == rhs.start {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.start < rhs.start
        }
    }

    static func makeDebugMessage(importedCount: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        let timestamp = formatter.string(from: Date())
        return "Auto-approved \(importedCount) events at \(timestamp)"
    }
}
