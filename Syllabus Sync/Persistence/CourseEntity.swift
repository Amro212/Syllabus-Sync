import CoreData

@objc(CourseEntity)
final class CourseEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<CourseEntity> {
        NSFetchRequest<CourseEntity>(entityName: "CourseEntity")
    }

    @NSManaged var id: String
    @NSManaged var code: String
    @NSManaged var title: String?
    @NSManaged var colorHex: String?
    @NSManaged var instructor: String?
}
