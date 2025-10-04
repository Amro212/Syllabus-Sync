import CoreData

final class CoreDataStack {
    enum StoreType {
        case persistent
        case inMemory
    }

    struct Configuration {
        let storeType: StoreType
        let cloudKitContainerIdentifier: String?

        static let `default` = Configuration(storeType: .persistent, cloudKitContainerIdentifier: nil)
        static let inMemory = Configuration(storeType: .inMemory, cloudKitContainerIdentifier: nil)
    }

    static let shared = CoreDataStack()

    let container: NSPersistentContainer
    let storeType: StoreType

    init(configuration: Configuration = .default) {
        storeType = configuration.storeType

        // Load the Core Data model from the .xcdatamodeld file
        if configuration.storeType == .persistent,
           let identifier = configuration.cloudKitContainerIdentifier,
           !identifier.isEmpty {
            container = NSPersistentCloudKitContainer(name: "SyllabusSync")
            let description = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
            description.type = NSSQLiteStoreType
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: identifier)
            container.persistentStoreDescriptions = [description]
        } else {
            container = NSPersistentContainer(name: "SyllabusSync")
        }

        let description = container.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()

        switch configuration.storeType {
        case .persistent:
            description.type = NSSQLiteStoreType
        case .inMemory:
            description.type = NSInMemoryStoreType
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { storeDescription, error in
            if let error = error {
                print("⚠️ Core Data failed to load: \(error)")
                print("   Store: \(storeDescription.url?.lastPathComponent ?? "unknown")")
                fatalError("Failed to load persistent stores: \(error)")
            }
            print("✅ Core Data loaded successfully")
            if storeDescription.cloudKitContainerOptions != nil {
                print("   CloudKit sync: ENABLED")
            } else {
                print("   CloudKit sync: DISABLED (local-only)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.undoManager = nil
    }

}
