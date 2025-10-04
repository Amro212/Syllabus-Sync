import CoreData

@objc(UserPrefsEntity)
final class UserPrefsEntity: NSManagedObject {
    @nonobjc class func fetchRequest() -> NSFetchRequest<UserPrefsEntity> {
        NSFetchRequest<UserPrefsEntity>(entityName: "UserPrefsEntity")
    }

    @NSManaged var id: String
    @NSManaged var theme: String
    @NSManaged var hapticsOn: Bool
    @NSManaged var lastCalendarId: String?
    @NSManaged var lastImportHashByCourse: String?
}

extension UserPrefsEntity {
    /// Fetches or creates the singleton UserPrefs instance
    static func fetchOrCreate(in context: NSManagedObjectContext) -> UserPrefsEntity {
        let request = UserPrefsEntity.fetchRequest()
        request.fetchLimit = 1
        
        if let existing = try? context.fetch(request).first {
            return existing
        }
        
        let prefs = UserPrefsEntity(context: context)
        prefs.id = "singleton"
        prefs.theme = "system"
        prefs.hapticsOn = true
        return prefs
    }
}

