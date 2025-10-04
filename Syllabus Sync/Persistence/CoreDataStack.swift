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
        let model = Self.makeModel()
        storeType = configuration.storeType

        if configuration.storeType == .persistent,
           let identifier = configuration.cloudKitContainerIdentifier,
           !identifier.isEmpty {
            let cloudContainer = NSPersistentCloudKitContainer(name: "SyllabusSync", managedObjectModel: model)
            let description = cloudContainer.persistentStoreDescriptions.first ?? NSPersistentStoreDescription()
            description.type = NSSQLiteStoreType
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: identifier)
            cloudContainer.persistentStoreDescriptions = [description]
            container = cloudContainer
        } else {
            container = NSPersistentContainer(name: "SyllabusSync", managedObjectModel: model)
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

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Failed to load persistent stores: \(error)")
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.undoManager = nil
    }

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // Course Entity
        let courseEntity = NSEntityDescription()
        courseEntity.name = "CourseEntity"
        courseEntity.managedObjectClassName = NSStringFromClass(CourseEntity.self)

        let courseId = NSAttributeDescription()
        courseId.name = "id"
        courseId.attributeType = .stringAttributeType
        courseId.isOptional = false

        let courseCode = NSAttributeDescription()
        courseCode.name = "code"
        courseCode.attributeType = .stringAttributeType
        courseCode.isOptional = false

        let courseTitle = NSAttributeDescription()
        courseTitle.name = "title"
        courseTitle.attributeType = .stringAttributeType
        courseTitle.isOptional = true

        let courseColor = NSAttributeDescription()
        courseColor.name = "colorHex"
        courseColor.attributeType = .stringAttributeType
        courseColor.isOptional = true

        let courseInstructor = NSAttributeDescription()
        courseInstructor.name = "instructor"
        courseInstructor.attributeType = .stringAttributeType
        courseInstructor.isOptional = true

        courseEntity.properties = [courseId, courseCode, courseTitle, courseColor, courseInstructor]

        // Event Entity
        let eventEntity = NSEntityDescription()
        eventEntity.name = "EventEntity"
        eventEntity.managedObjectClassName = NSStringFromClass(EventEntity.self)

        let eventId = NSAttributeDescription()
        eventId.name = "id"
        eventId.attributeType = .stringAttributeType
        eventId.isOptional = false

        let eventCourseCode = NSAttributeDescription()
        eventCourseCode.name = "courseCode"
        eventCourseCode.attributeType = .stringAttributeType
        eventCourseCode.isOptional = false

        let eventType = NSAttributeDescription()
        eventType.name = "typeRaw"
        eventType.attributeType = .stringAttributeType
        eventType.isOptional = false

        let eventTitle = NSAttributeDescription()
        eventTitle.name = "title"
        eventTitle.attributeType = .stringAttributeType
        eventTitle.isOptional = false

        let eventStart = NSAttributeDescription()
        eventStart.name = "start"
        eventStart.attributeType = .dateAttributeType
        eventStart.isOptional = false

        let eventEnd = NSAttributeDescription()
        eventEnd.name = "end"
        eventEnd.attributeType = .dateAttributeType
        eventEnd.isOptional = true

        let eventAllDay = NSAttributeDescription()
        eventAllDay.name = "allDay"
        eventAllDay.attributeType = .booleanAttributeType
        eventAllDay.isOptional = true

        let eventLocation = NSAttributeDescription()
        eventLocation.name = "location"
        eventLocation.attributeType = .stringAttributeType
        eventLocation.isOptional = true

        let eventNotes = NSAttributeDescription()
        eventNotes.name = "notes"
        eventNotes.attributeType = .stringAttributeType
        eventNotes.isOptional = true

        let eventRecurrence = NSAttributeDescription()
        eventRecurrence.name = "recurrenceRule"
        eventRecurrence.attributeType = .stringAttributeType
        eventRecurrence.isOptional = true

        let eventReminder = NSAttributeDescription()
        eventReminder.name = "reminderMinutes"
        eventReminder.attributeType = .integer32AttributeType
        eventReminder.isOptional = true

        let eventConfidence = NSAttributeDescription()
        eventConfidence.name = "confidence"
        eventConfidence.attributeType = .doubleAttributeType
        eventConfidence.isOptional = true

        let eventApproved = NSAttributeDescription()
        eventApproved.name = "approvedAt"
        eventApproved.attributeType = .dateAttributeType
        eventApproved.isOptional = true

        let eventCreated = NSAttributeDescription()
        eventCreated.name = "createdAt"
        eventCreated.attributeType = .dateAttributeType
        eventCreated.isOptional = false

        let eventCourseId = NSAttributeDescription()
        eventCourseId.name = "courseId"
        eventCourseId.attributeType = .stringAttributeType
        eventCourseId.isOptional = true

        eventEntity.properties = [
            eventId,
            eventCourseCode,
            eventType,
            eventTitle,
            eventStart,
            eventEnd,
            eventAllDay,
            eventLocation,
            eventNotes,
            eventRecurrence,
            eventReminder,
            eventConfidence,
            eventApproved,
            eventCreated,
            eventCourseId
        ]

        model.entities = [courseEntity, eventEntity]
        return model
    }
}
