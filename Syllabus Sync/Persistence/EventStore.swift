import Foundation

@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var events: [EventItem] = []
    @Published private(set) var debugMessage: String?

    private let dataService = SupabaseDataService.shared

    init() {
        // Events will be loaded when authenticated
    }

    func refresh() async {
        await fetchEvents()
    }
    
    func fetchEvents() async {
        let result = await dataService.fetchEvents()
        switch result {
        case .success(let fetchedEvents):
            await MainActor.run {
                self.events = EventStore.sorted(fetchedEvents)
            }
        case .failure(let error):
            print("Failed to fetch events: \(error)")
        }
    }

    func autoApprove(events newEvents: [EventItem]) async {
        guard !newEvents.isEmpty else { return }
        
        // Delete existing events for the same course codes
        let courseCodes = Set(newEvents.map { $0.courseCode })
        for courseCode in courseCodes {
            let existingEvents = events.filter { $0.courseCode == courseCode }
            let newEventIds = Set(newEvents.filter { $0.courseCode == courseCode }.map { $0.id })
            
            // Delete events that are not in the new set
            for event in existingEvents {
                if !newEventIds.contains(event.id) {
                    await deleteEvent(event)
                }
            }
        }
        
        // Save new events
        await addEvents(newEvents)
        
        let now = Date()
        debugMessage = EventStore.makeDebugMessage(importedCount: newEvents.count, timestamp: now)
    }
    
    func addEvent(_ event: EventItem) async {
        let result = await dataService.saveEvent(event)
        switch result {
        case .success(let savedEvent):
            await MainActor.run {
                self.events.append(savedEvent)
                self.events = EventStore.sorted(self.events)
            }
        case .failure(let error):
            print("Failed to save event: \(error)")
        }
    }
    
    func addEvents(_ newEvents: [EventItem]) async {
        let result = await dataService.saveEvents(newEvents)
        switch result {
        case .success(let savedEvents):
            await MainActor.run {
                // Remove duplicates and merge
                var updatedEvents = self.events
                for savedEvent in savedEvents {
                    if let index = updatedEvents.firstIndex(where: { $0.id == savedEvent.id }) {
                        updatedEvents[index] = savedEvent
                    } else {
                        updatedEvents.append(savedEvent)
                    }
                }
                self.events = EventStore.sorted(updatedEvents)
            }
        case .failure(let error):
            print("Failed to save events: \(error)")
        }
    }

    func deleteAllEvents() async {
        let result = await dataService.deleteAllData()
        switch result {
        case .success:
            await MainActor.run {
                self.events = []
                self.debugMessage = nil
            }
        case .failure(let error):
            print("Failed to delete all events: \(error)")
        }
    }
    
    func deleteEvent(_ event: EventItem) async {
        let result = await dataService.deleteEvent(id: event.id)
        switch result {
        case .success:
            await MainActor.run {
                self.events.removeAll { $0.id == event.id }
            }
        case .failure(let error):
            print("Failed to delete event: \(error)")
        }
    }

    func update(event: EventItem) async {
        await updateEvent(event)
    }
    
    func updateEvent(_ event: EventItem) async {
        let result = await dataService.saveEvent(event)
        switch result {
        case .success(let updatedEvent):
            await MainActor.run {
                if let index = events.firstIndex(where: { $0.id == event.id }) {
                    events[index] = updatedEvent
                } else {
                    events.append(updatedEvent)
                }
                self.events = EventStore.sorted(self.events)
            }
        case .failure(let error):
            print("Failed to update event: \(error)")
        }
    }
    
    func clearEvents() {
        events = []
        debugMessage = nil
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

    static func makeDebugMessage(importedCount: Int, timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        return "Auto-approved \(importedCount) events at \(formatter.string(from: timestamp))"
    }
}
