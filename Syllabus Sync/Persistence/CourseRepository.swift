import CoreData
import Foundation

/// Repository for managing Course entities in Core Data
@MainActor
final class CourseRepository: ObservableObject {
    @Published private(set) var courses: [Course] = []
    
    private let stack: CoreDataStack
    private let viewContext: NSManagedObjectContext
    
    init(stack: CoreDataStack = .shared) {
        self.stack = stack
        self.viewContext = stack.container.viewContext
        Task { await refresh() }
    }
    
    // MARK: - Fetch
    
    func refresh() async {
        let request: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: #keyPath(CourseEntity.code), ascending: true)]
        
        do {
            let fetched = try viewContext.fetch(request)
            courses = fetched.map { $0.toDomain() }
        } catch {
            print("[CourseRepository] Fetch failed: \(error)")
        }
    }
    
    func fetchCourse(byId id: String) async -> Course? {
        let request: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        do {
            let fetched = try viewContext.fetch(request)
            return fetched.first?.toDomain()
        } catch {
            print("[CourseRepository] Fetch by ID failed: \(error)")
            return nil
        }
    }
    
    func fetchCourse(byCode code: String) async -> Course? {
        let request: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
        request.predicate = NSPredicate(format: "code == %@", code)
        request.fetchLimit = 1
        
        do {
            let fetched = try viewContext.fetch(request)
            return fetched.first?.toDomain()
        } catch {
            print("[CourseRepository] Fetch by code failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Create/Update
    
    func save(course: Course) async {
        let container = stack.container
        let background = container.newBackgroundContext()
        background.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        do {
            try await background.perform {
                let fetch: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
                fetch.predicate = NSPredicate(format: "id == %@", course.id)
                fetch.fetchLimit = 1
                
                let entity: CourseEntity
                if let existing = try background.fetch(fetch).first {
                    entity = existing
                } else {
                    entity = CourseEntity(context: background)
                }
                
                entity.apply(from: course)
                
                if background.hasChanges {
                    try background.save()
                }
            }
            
            await refresh()
        } catch {
            print("[CourseRepository] Save failed: \(error)")
        }
    }
    
    func saveBatch(courses: [Course]) async {
        let container = stack.container
        let background = container.newBackgroundContext()
        background.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        do {
            try await background.perform {
                for course in courses {
                    let fetch: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
                    fetch.predicate = NSPredicate(format: "id == %@", course.id)
                    fetch.fetchLimit = 1
                    
                    let entity: CourseEntity
                    if let existing = try background.fetch(fetch).first {
                        entity = existing
                    } else {
                        entity = CourseEntity(context: background)
                    }
                    
                    entity.apply(from: course)
                }
                
                if background.hasChanges {
                    try background.save()
                }
            }
            
            await refresh()
        } catch {
            print("[CourseRepository] Batch save failed: \(error)")
        }
    }
    
    // MARK: - Delete
    
    func delete(courseId: String) async {
        let container = stack.container
        let background = container.newBackgroundContext()
        background.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        do {
            try await background.perform {
                let fetch: NSFetchRequest<CourseEntity> = CourseEntity.fetchRequest()
                fetch.predicate = NSPredicate(format: "id == %@", courseId)
                
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
            print("[CourseRepository] Delete failed: \(error)")
        }
    }
    
    func deleteAll() async {
        let container = stack.container
        let background = container.newBackgroundContext()
        background.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        do {
            try await background.perform {
                let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: "CourseEntity")
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
            print("[CourseRepository] Delete all failed: \(error)")
        }
    }
}

