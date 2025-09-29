import CoreData
import SwiftUI

@MainActor
final class EventStore: ObservableObject {
    @Published private(set) var events: [EventItem] = []
    @Published private(set) var debugMessage: String?

    private let stack: CoreDataStack
    private let viewContext: NSManagedObjectContext

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
        self.viewContext = stack.container.viewContext
        Task { await refresh() }
    }

    func refresh() async {
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(EventEntity.start), ascending: true)]

        do {
            let fetched = try viewContext.fetch(request)
            events = fetched.compactMap { $0.toDomain() }
        } catch {
            print("[EventStore] Fetch failed: \(error)")
        }
    }

    func autoApprove(events newEvents: [EventItem]) async {
        guard !newEvents.isEmpty else { return }
        let now = Date()
        let container = stack.container
        let background = container.newBackgroundContext()
        background.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        let eventIds = newEvents.map { $0.id }
        let courseCodes = Set(newEvents.map { $0.courseCode })

        do {
            try await background.perform {
                // Delete events for these course codes not in latest import
                if !courseCodes.isEmpty {
                    let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "EventEntity")
                    deleteFetch.predicate = NSPredicate(
                        format: "courseCode IN %@ AND NOT (id IN %@)",
                        Array(courseCodes),
                        eventIds
                    )
                    let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)
                    deleteRequest.resultType = .resultTypeObjectIDs
                    if let result = try background.execute(deleteRequest) as? NSBatchDeleteResult,
                       let deletedObjectIDs = result.result as? [NSManagedObjectID] {
                        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: deletedObjectIDs], into: [container.viewContext])
                    }
                }

                for item in newEvents {
                    let fetch: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                    fetch.predicate = NSPredicate(format: "id == %@", item.id)
                    fetch.fetchLimit = 1
                    let entity: EventEntity
                    if let existing = try background.fetch(fetch).first {
                        entity = existing
                    } else {
                        entity = EventEntity(context: background)
                        entity.createdAt = Date(timeIntervalSinceReferenceDate: 0)
                    }
                    entity.apply(from: item, approvedAt: now)
                    entity.courseId = item.courseCode // placeholder until Course entity used
                }

                if background.hasChanges {
                    try background.save()
                }
            }

            await refresh()
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .medium
            let timestamp = formatter.string(from: now)
            debugMessage = "Auto-approved \(newEvents.count) events at \(timestamp)"
        } catch {
            print("[EventStore] autoApprove failed: \(error)")
        }
    }

    func deleteAllEvents() async {
        let container = stack.container
        let background = container.newBackgroundContext()
        background.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        do {
            try await background.perform {
                let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "EventEntity")
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetch)
                deleteRequest.resultType = .resultTypeObjectIDs
                if let result = try background.execute(deleteRequest) as? NSBatchDeleteResult,
                   let deletedObjectIDs = result.result as? [NSManagedObjectID] {
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: [NSDeletedObjectsKey: deletedObjectIDs], into: [container.viewContext])
                }
            }

            await refresh()
        } catch {
            print("[EventStore] deleteAllEvents failed: \(error)")
        }
    }

    func update(event: EventItem) async {
        let container = stack.container
        let background = container.newBackgroundContext()
        background.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        do {
            try await background.perform {
                let fetch: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                fetch.predicate = NSPredicate(format: "id == %@", event.id)
                fetch.fetchLimit = 1

                let entity: EventEntity
                if let existing = try background.fetch(fetch).first {
                    entity = existing
                } else {
                    entity = EventEntity(context: background)
                    entity.createdAt = Date()
                    entity.approvedAt = Date()
                }

                entity.id = event.id
                entity.courseCode = event.courseCode
                entity.typeRaw = event.type.rawValue
                entity.title = event.title
                entity.start = event.start
                entity.end = event.end
                entity.allDay = event.allDay.map { NSNumber(value: $0) }
                entity.location = event.location
                entity.notes = event.notes
                entity.recurrenceRule = event.recurrenceRule
                entity.reminderMinutes = event.reminderMinutes.map { NSNumber(value: $0) }
                entity.confidence = event.confidence.map { NSNumber(value: $0) }
                if entity.approvedAt == nil {
                    entity.approvedAt = Date()
                }
                entity.courseId = entity.courseId ?? event.courseCode

                if background.hasChanges {
                    try background.save()
                }
            }

            await refresh()
        } catch {
            print("[EventStore] update failed: \(error)")
        }
    }
}
