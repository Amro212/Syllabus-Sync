import CoreData
import Foundation

/// Repository for managing EventItem entities in Core Data
/// Note: EventStore already provides most of this functionality
/// This is a thin wrapper for consistency with CourseRepository
@MainActor
final class EventRepository: ObservableObject {
    @Published private(set) var events: [EventItem] = []
    
    private let stack: CoreDataStack
    private let viewContext: NSManagedObjectContext
    
    init(stack: CoreDataStack = .shared) {
        self.stack = stack
        self.viewContext = stack.container.viewContext
        Task { await refresh() }
    }
    
    // MARK: - Fetch
    
    func refresh() async {
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(EventEntity.start), ascending: true)]
        
        do {
            let fetched = try viewContext.fetch(request)
            events = fetched.compactMap { $0.toDomain() }
        } catch {
            print("[EventRepository] Fetch failed: \(error)")
        }
    }
    
    func fetchEvents(forCourseCode courseCode: String) async -> [EventItem] {
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        request.predicate = NSPredicate(format: "courseCode == %@", courseCode)
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(EventEntity.start), ascending: true)]
        
        do {
            let fetched = try viewContext.fetch(request)
            return fetched.compactMap { $0.toDomain() }
        } catch {
            print("[EventRepository] Fetch by course code failed: \(error)")
            return []
        }
    }
    
    func fetchEvent(byId id: String) async -> EventItem? {
        let request: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        do {
            let fetched = try viewContext.fetch(request)
            return fetched.first?.toDomain()
        } catch {
            print("[EventRepository] Fetch by ID failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Create/Update
    
    func save(event: EventItem) async {
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
                }
                
                entity.apply(from: event, approvedAt: Date())
                
                if background.hasChanges {
                    try background.save()
                }
            }
            
            await refresh()
        } catch {
            print("[EventRepository] Save failed: \(error)")
        }
    }
    
    func saveBatch(events: [EventItem]) async {
        let container = stack.container
        let background = container.newBackgroundContext()
        background.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        let now = Date()
        
        do {
            try await background.perform {
                for event in events {
                    let fetch: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                    fetch.predicate = NSPredicate(format: "id == %@", event.id)
                    fetch.fetchLimit = 1
                    
                    let entity: EventEntity
                    if let existing = try background.fetch(fetch).first {
                        entity = existing
                    } else {
                        entity = EventEntity(context: background)
                        entity.createdAt = now
                    }
                    
                    entity.apply(from: event, approvedAt: now)
                }
                
                if background.hasChanges {
                    try background.save()
                }
            }
            
            await refresh()
        } catch {
            print("[EventRepository] Batch save failed: \(error)")
        }
    }
    
    // MARK: - Delete
    
    func delete(eventId: String) async {
        let container = stack.container
        let background = container.newBackgroundContext()
        background.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        do {
            try await background.perform {
                let fetch: NSFetchRequest<EventEntity> = EventEntity.fetchRequest()
                fetch.predicate = NSPredicate(format: "id == %@", eventId)
                
                let entities = try background.fetch(fetch)
                for entity in entities {
                    background.delete(entity)
                }
                
                if background.hasChanges {
                    try background.save()
                }
            }
            
            await refresh()
        } catch {
            print("[EventRepository] Delete failed: \(error)")
        }
    }
    
    func deleteAll() async {
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
                    NSManagedObjectContext.mergeChanges(
                        fromRemoteContextSave: [NSDeletedObjectsKey: deletedObjectIDs],
                        into: [container.viewContext]
                    )
                }
            }
            
            await refresh()
        } catch {
            print("[EventRepository] Delete all failed: \(error)")
        }
    }
}

