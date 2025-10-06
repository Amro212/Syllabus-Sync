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

extension CourseEntity {
    func toDomain() -> Course {
        Course(
            id: id,
            code: code,
            title: title,
            colorHex: colorHex,
            instructor: instructor
        )
    }
    
    func apply(from course: Course) {
        id = course.id
        code = course.code
        title = course.title
        colorHex = course.colorHex
        instructor = course.instructor
    }
}
