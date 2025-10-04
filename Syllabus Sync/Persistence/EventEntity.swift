import CoreData

@objc(EventEntity)
final class EventEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<EventEntity> {
        NSFetchRequest<EventEntity>(entityName: "EventEntity")
    }

    @NSManaged var id: String
    @NSManaged var courseId: String?
    @NSManaged var courseCode: String
    @NSManaged var typeRaw: String
    @NSManaged var title: String
    @NSManaged var start: Date?
    @NSManaged var end: Date?
    @NSManaged var allDay: NSNumber?
    @NSManaged var location: String?
    @NSManaged var notes: String?
    @NSManaged var recurrenceRule: String?
    @NSManaged var reminderMinutes: NSNumber?
    @NSManaged var confidence: NSNumber?
    @NSManaged var approvedAt: Date?
    @NSManaged var createdAt: Date?
}

extension EventEntity {
    func toDomain() -> EventItem? {
        guard let type = EventItem.EventType(rawValue: typeRaw),
              let startDate = start else { return nil }
        return EventItem(
            id: id,
            courseCode: courseCode,
            type: type,
            title: title,
            start: startDate,
            end: end,
            allDay: allDay?.boolValue,
            location: location,
            notes: notes,
            recurrenceRule: recurrenceRule,
            reminderMinutes: reminderMinutes?.intValue,
            confidence: confidence?.doubleValue
        )
    }

    func apply(from item: EventItem, approvedAt date: Date) {
        id = item.id
        courseCode = item.courseCode
        typeRaw = item.type.rawValue
        title = item.title
        start = item.start
        end = item.end
        allDay = item.allDay as NSNumber?
        location = item.location
        notes = item.notes
        recurrenceRule = item.recurrenceRule
        reminderMinutes = item.reminderMinutes as NSNumber?
        confidence = item.confidence as NSNumber?
        approvedAt = date
        if createdAt == nil || createdAt!.timeIntervalSinceReferenceDate <= 0 {
            createdAt = date
        }
    }
}
