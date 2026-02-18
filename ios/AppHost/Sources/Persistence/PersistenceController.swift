import CoreData
import Foundation

enum PersistenceError: Error {
    case directoryCreationFailed(URL)
}

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    let romDirectory: URL
    let saveStateDirectory: URL

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "AppHostModel")

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Unresolved Core Data error: \(error)")
            }
        }

        #if os(iOS)
        container.viewContext.mergePolicy = NSMergePolicy(mergeByPropertyObjectTrump: true)
        container.viewContext.automaticallyMergesChangesFromParent = true
        #endif

        romDirectory = try! PersistenceController.createDirectory(named: "roms")
        saveStateDirectory = try! PersistenceController.createDirectory(named: "savestates")
    }

    #if os(iOS)
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    #else
    var viewContext: NSManagedObjectContext {
        container.newBackgroundContext()
    }
    #endif

    func saveContext() {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            context.rollback()
            assertionFailure("Failed to save context: \(error)")
        }
    }

    private static func createDirectory(named name: String) throws -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var directory = baseURL.appendingPathComponent("AppHost", isDirectory: true).appendingPathComponent(name, isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try directory.setResourceValues(resourceValues)
            } catch {
                throw PersistenceError.directoryCreationFailed(directory)
            }
        }

        return directory
    }
}
