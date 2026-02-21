import CoreData
import Foundation

@objc(ControllerMapping)
class ControllerMapping: NSManagedObject {
    @NSManaged var controllerType: String
    @NSManaged var mappingData: String
    @NSManaged var platformRaw: String
    @NSManaged var updatedAt: Date

    convenience init(context: NSManagedObjectContext, controllerType: String, platformRaw: String, mappingData: String) {
        self.init(context: context)
        self.controllerType = controllerType
        self.platformRaw = platformRaw
        self.mappingData = mappingData
        self.updatedAt = Date()
    }
}

extension ControllerMapping: Identifiable {}