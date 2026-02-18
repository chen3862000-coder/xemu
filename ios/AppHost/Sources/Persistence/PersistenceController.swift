import CoreData
import Foundation

@MainActor
final class PersistenceController: @unchecked Sendable {
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    let romDirectory: URL
    let saveStateDirectory: URL

    init(inMemory: Bool = false) {
        let model = createManagedObjectModel()
        container = NSPersistentContainer(name: "AppHost", managedObjectModel: model)

        if inMemory {
            let description = NSPersistentStoreDescription()
            description.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [description]
        }

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }

        if let error = loadError {
            print("Core Data load error: \(error)")
        }

        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        container.viewContext.automaticallyMergesChangesFromParent = true

        let romPath = PersistenceController.getOrCreateDir(name: "roms")
        let savePath = PersistenceController.getOrCreateDir(name: "savestates")
        romDirectory = romPath
        saveStateDirectory = savePath
    }

    nonisolated var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    nonisolated func saveContext() {
        let context = container.viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            context.rollback()
            assertionFailure("Failed to save context: \(error)")
        }
    }

    private static func getOrCreateDir(name: String) -> URL {
        do {
            return try createDirectory(named: name)
        } catch {
            return FileManager.default.temporaryDirectory.appendingPathComponent(name)
        }
    }

    private static func createDirectory(named name: String) throws -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        var directory = baseURL.appendingPathComponent("AppHost", isDirectory: true).appendingPathComponent(name, isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try directory.setResourceValues(resourceValues)
        }

        return directory
    }
}

private func createManagedObjectModel() -> NSManagedObjectModel {
    let model = NSManagedObjectModel()

    let gameEntity = NSEntityDescription()
    gameEntity.name = "Game"
    gameEntity.managedObjectClassName = "Game"

    let idAttr = NSAttributeDescription()
    idAttr.name = "id"
    idAttr.attributeType = .UUIDAttributeType
    idAttr.isOptional = false

    let titleAttr = NSAttributeDescription()
    titleAttr.name = "title"
    titleAttr.attributeType = .stringAttributeType
    titleAttr.isOptional = true

    let fileNameAttr = NSAttributeDescription()
    fileNameAttr.name = "fileName"
    fileNameAttr.attributeType = .stringAttributeType
    fileNameAttr.isOptional = true

    let fileSizeAttr = NSAttributeDescription()
    fileSizeAttr.name = "fileSize"
    fileSizeAttr.attributeType = .integer64AttributeType
    fileSizeAttr.isOptional = true
    fileSizeAttr.defaultValue = 0

    let coverImageDataAttr = NSAttributeDescription()
    coverImageDataAttr.name = "coverImageData"
    coverImageDataAttr.attributeType = .binaryDataAttributeType
    coverImageDataAttr.isOptional = true
    coverImageDataAttr.allowsExternalBinaryDataStorage = true

    let systemAttr = NSAttributeDescription()
    systemAttr.name = "system"
    systemAttr.attributeType = .stringAttributeType
    systemAttr.isOptional = true

    let lastPlayedAttr = NSAttributeDescription()
    lastPlayedAttr.name = "lastPlayed"
    lastPlayedAttr.attributeType = .dateAttributeType
    lastPlayedAttr.isOptional = true

    let playTimeAttr = NSAttributeDescription()
    playTimeAttr.name = "playTime"
    playTimeAttr.attributeType = .integer64AttributeType
    playTimeAttr.isOptional = true
    playTimeAttr.defaultValue = 0

    let isFavoriteAttr = NSAttributeDescription()
    isFavoriteAttr.name = "isFavorite"
    isFavoriteAttr.attributeType = .booleanAttributeType
    isFavoriteAttr.isOptional = true
    isFavoriteAttr.defaultValue = false

    let dateAddedAttr = NSAttributeDescription()
    dateAddedAttr.name = "dateAdded"
    dateAddedAttr.attributeType = .dateAttributeType
    dateAddedAttr.isOptional = true

    let checksumAttr = NSAttributeDescription()
    checksumAttr.name = "checksum"
    checksumAttr.attributeType = .stringAttributeType
    checksumAttr.isOptional = true

    gameEntity.properties = [
        idAttr, titleAttr, fileNameAttr, fileSizeAttr, coverImageDataAttr,
        systemAttr, lastPlayedAttr, playTimeAttr, isFavoriteAttr, dateAddedAttr, checksumAttr
    ]

    let entitlementEntity = NSEntityDescription()
    entitlementEntity.name = "UserEntitlement"
    entitlementEntity.managedObjectClassName = "UserEntitlement"

    let entIdAttr = NSAttributeDescription()
    entIdAttr.name = "id"
    entIdAttr.attributeType = .UUIDAttributeType
    entIdAttr.isOptional = false

    let deviceIdAttr = NSAttributeDescription()
    deviceIdAttr.name = "deviceIdentifier"
    deviceIdAttr.attributeType = .stringAttributeType
    deviceIdAttr.isOptional = true

    let productCodeAttr = NSAttributeDescription()
    productCodeAttr.name = "productCode"
    productCodeAttr.attributeType = .stringAttributeType
    productCodeAttr.isOptional = true

    let purchaseDateAttr = NSAttributeDescription()
    purchaseDateAttr.name = "purchaseDate"
    purchaseDateAttr.attributeType = .dateAttributeType
    purchaseDateAttr.isOptional = true

    let expirationDateAttr = NSAttributeDescription()
    expirationDateAttr.name = "expirationDate"
    expirationDateAttr.attributeType = .dateAttributeType
    expirationDateAttr.isOptional = true

    let isActiveAttr = NSAttributeDescription()
    isActiveAttr.name = "isActive"
    isActiveAttr.attributeType = .booleanAttributeType
    isActiveAttr.isOptional = true
    isActiveAttr.defaultValue = true

    entitlementEntity.properties = [
        entIdAttr, deviceIdAttr, productCodeAttr, purchaseDateAttr, expirationDateAttr, isActiveAttr
    ]

    let romEntryEntity = NSEntityDescription()
    romEntryEntity.name = "ROMLibraryEntry"
    romEntryEntity.managedObjectClassName = "ROMLibraryEntry"

    let romIdAttr = NSAttributeDescription()
    romIdAttr.name = "id"
    romIdAttr.attributeType = .UUIDAttributeType
    romIdAttr.isOptional = false

    let romTitleAttr = NSAttributeDescription()
    romTitleAttr.name = "title"
    romTitleAttr.attributeType = .stringAttributeType
    romTitleAttr.isOptional = true

    let romFileNameAttr = NSAttributeDescription()
    romFileNameAttr.name = "fileName"
    romFileNameAttr.attributeType = .stringAttributeType
    romFileNameAttr.isOptional = true

    let romFileSizeAttr = NSAttributeDescription()
    romFileSizeAttr.name = "fileSize"
    romFileSizeAttr.attributeType = .integer64AttributeType
    romFileSizeAttr.isOptional = true
    romFileSizeAttr.defaultValue = 0

    let romCoverImageDataAttr = NSAttributeDescription()
    romCoverImageDataAttr.name = "coverImageData"
    romCoverImageDataAttr.attributeType = .binaryDataAttributeType
    romCoverImageDataAttr.isOptional = true
    romCoverImageDataAttr.allowsExternalBinaryDataStorage = true

    let romSystemAttr = NSAttributeDescription()
    romSystemAttr.name = "system"
    romSystemAttr.attributeType = .stringAttributeType
    romSystemAttr.isOptional = true

    let romLastPlayedAtAttr = NSAttributeDescription()
    romLastPlayedAtAttr.name = "lastPlayedAt"
    romLastPlayedAtAttr.attributeType = .dateAttributeType
    romLastPlayedAtAttr.isOptional = true

    let romPlaytimeTotalAttr = NSAttributeDescription()
    romPlaytimeTotalAttr.name = "playtimeTotal"
    romPlaytimeTotalAttr.attributeType = .integer64AttributeType
    romPlaytimeTotalAttr.isOptional = true
    romPlaytimeTotalAttr.defaultValue = 0

    let romIsFavoriteAttr = NSAttributeDescription()
    romIsFavoriteAttr.name = "isFavorite"
    romIsFavoriteAttr.attributeType = .booleanAttributeType
    romIsFavoriteAttr.isOptional = true
    romIsFavoriteAttr.defaultValue = false

    let romDateAddedAttr = NSAttributeDescription()
    romDateAddedAttr.name = "dateAdded"
    romDateAddedAttr.attributeType = .dateAttributeType
    romDateAddedAttr.isOptional = true

    let romChecksumAttr = NSAttributeDescription()
    romChecksumAttr.name = "checksum"
    romChecksumAttr.attributeType = .stringAttributeType
    romChecksumAttr.isOptional = true

    romEntryEntity.properties = [
        romIdAttr, romTitleAttr, romFileNameAttr, romFileSizeAttr, romCoverImageDataAttr,
        romSystemAttr, romLastPlayedAtAttr, romPlaytimeTotalAttr, romIsFavoriteAttr, romDateAddedAttr, romChecksumAttr
    ]

    model.entities = [gameEntity, entitlementEntity, romEntryEntity]

    return model
}
