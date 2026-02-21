import CoreData

@objc(SaveState)
class SaveState: NSManagedObject {
    @NSManaged var createdAt: Date
    @NSManaged var data: Data?
    @NSManaged var screenshotData: Data?
    @NSManaged var slotIndex: Int16
    @NSManaged var timestamp: Date
    @NSManaged var title: String?
    @NSManaged var rom: ROMLibraryEntry?

    convenience init(context: NSManagedObjectContext, slotIndex: Int16, rom: ROMLibraryEntry? = nil) {
        self.init(context: context)
        self.slotIndex = slotIndex
        self.createdAt = Date()
        self.timestamp = Date()
        self.rom = rom
    }
}

extension SaveState {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<SaveState> {
        return NSFetchRequest<SaveState>(entityName: "SaveState")
    }
}

extension SaveState: Identifiable {
    var id: NSManagedObjectID {
        objectID
    }
}
