import CoreData
import Foundation

@MainActor
final class PersistenceController: Sendable {
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

        runCoverDataMigrationIfNeeded(skipPersistenceFlag: inMemory)
    }

    // Thread-safe access to view context
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // Thread-safe context saving
    func saveContext() {
        let context = container.viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            context.rollback()
            print("Failed to save context: \(error)")
            // Consider implementing retry logic or user notification
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
        guard let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            let error = NSError(domain: "com.xemu.persistence", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unable to access application support directory"
            ])
            throw error
        }

        var directory = baseURL.appendingPathComponent("AppHost", isDirectory: true).appendingPathComponent(name, isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try directory.setResourceValues(resourceValues)
        }

        return directory
    }

    private func runCoverDataMigrationIfNeeded(skipPersistenceFlag: Bool) {
        let defaultsKey = "cover-data-migration-v1"
        if !skipPersistenceFlag, UserDefaults.standard.bool(forKey: defaultsKey) {
            return
        }

        container.performBackgroundTask { context in
            let request = NSFetchRequest<ROMLibraryEntry>(entityName: "ROMLibraryEntry")
            var didMutate = false

            do {
                let entries = try context.fetch(request)
                for entry in entries {
                    if (entry.customCoverURL ?? "").isEmpty, CoverArtService.shared.customCoverExists(for: entry.id) {
                        entry.customCoverURL = CoverArtService.shared.customCoverURL(for: entry.id).path
                        didMutate = true
                    }

                    let hasEmbedded = !(entry.coverImageData?.isEmpty ?? true)
                    let hasCustom = !((entry.customCoverURL ?? "").isEmpty) || CoverArtService.shared.customCoverExists(for: entry.id)
                    if !hasEmbedded, !hasCustom {
                        CoverArtService.shared.assignDeterministicPlaceholderIfNeeded(to: entry)
                        didMutate = true
                    }
                }

                if context.hasChanges {
                    try context.save()
                }

                if didMutate || !skipPersistenceFlag {
                    UserDefaults.standard.set(true, forKey: defaultsKey)
                }
            } catch {
                print("Cover migration failed: \\(error)")
            }
        }
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

    let gameRomSha1Attr = NSAttributeDescription()
    gameRomSha1Attr.name = "romSha1"
    gameRomSha1Attr.attributeType = .stringAttributeType
    gameRomSha1Attr.isOptional = true

    let defaultCoverKeyAttr = NSAttributeDescription()
    defaultCoverKeyAttr.name = "defaultCoverKey"
    defaultCoverKeyAttr.attributeType = .stringAttributeType
    defaultCoverKeyAttr.isOptional = true

    let canonicalTitleIDAttr = NSAttributeDescription()
    canonicalTitleIDAttr.name = "canonicalTitleID"
    canonicalTitleIDAttr.attributeType = .stringAttributeType
    canonicalTitleIDAttr.isOptional = true

    let customCoverURLAttr = NSAttributeDescription()
    customCoverURLAttr.name = "customCoverURL"
    customCoverURLAttr.attributeType = .stringAttributeType
    customCoverURLAttr.isOptional = true

    gameEntity.properties = [
        idAttr, titleAttr, fileNameAttr, fileSizeAttr, coverImageDataAttr,
        systemAttr, lastPlayedAttr, playTimeAttr, isFavoriteAttr, dateAddedAttr, checksumAttr,
        gameRomSha1Attr, defaultCoverKeyAttr, canonicalTitleIDAttr, customCoverURLAttr
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

    let romPlatformRawAttr = NSAttributeDescription()
    romPlatformRawAttr.name = "platformRaw"
    romPlatformRawAttr.attributeType = .stringAttributeType
    romPlatformRawAttr.isOptional = true

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

    let romSha1Attr = NSAttributeDescription()
    romSha1Attr.name = "romSha1"
    romSha1Attr.attributeType = .stringAttributeType
    romSha1Attr.isOptional = true

    let romDefaultCoverKeyAttr = NSAttributeDescription()
    romDefaultCoverKeyAttr.name = "defaultCoverKey"
    romDefaultCoverKeyAttr.attributeType = .stringAttributeType
    romDefaultCoverKeyAttr.isOptional = true

    let romCanonicalTitleIDAttr = NSAttributeDescription()
    romCanonicalTitleIDAttr.name = "canonicalTitleID"
    romCanonicalTitleIDAttr.attributeType = .stringAttributeType
    romCanonicalTitleIDAttr.isOptional = true

    let romCustomCoverURLAttr = NSAttributeDescription()
    romCustomCoverURLAttr.name = "customCoverURL"
    romCustomCoverURLAttr.attributeType = .stringAttributeType
    romCustomCoverURLAttr.isOptional = true

    romEntryEntity.properties = [
        romIdAttr, romTitleAttr, romFileNameAttr, romFileSizeAttr, romCoverImageDataAttr,
        romSystemAttr, romPlatformRawAttr, romLastPlayedAtAttr, romPlaytimeTotalAttr, romIsFavoriteAttr, romDateAddedAttr, romChecksumAttr,
        romSha1Attr, romDefaultCoverKeyAttr, romCanonicalTitleIDAttr, romCustomCoverURLAttr
    ]

    let saveStateEntity = NSEntityDescription()
    saveStateEntity.name = "SaveState"
    saveStateEntity.managedObjectClassName = "Xemu.SaveState"

    let saveStateIdAttr = NSAttributeDescription()
    saveStateIdAttr.name = "id"
    saveStateIdAttr.attributeType = .UUIDAttributeType
    saveStateIdAttr.isOptional = false

    let saveStateSlotIndexAttr = NSAttributeDescription()
    saveStateSlotIndexAttr.name = "slotIndex"
    saveStateSlotIndexAttr.attributeType = .integer16AttributeType
    saveStateSlotIndexAttr.isOptional = false
    saveStateSlotIndexAttr.defaultValue = 0

    let saveStateCreatedAtAttr = NSAttributeDescription()
    saveStateCreatedAtAttr.name = "createdAt"
    saveStateCreatedAtAttr.attributeType = .dateAttributeType
    saveStateCreatedAtAttr.isOptional = false

    let saveStateTimestampAttr = NSAttributeDescription()
    saveStateTimestampAttr.name = "timestamp"
    saveStateTimestampAttr.attributeType = .dateAttributeType
    saveStateTimestampAttr.isOptional = false

    let saveStateTitleAttr = NSAttributeDescription()
    saveStateTitleAttr.name = "title"
    saveStateTitleAttr.attributeType = .stringAttributeType
    saveStateTitleAttr.isOptional = true

    let saveStateDataAttr = NSAttributeDescription()
    saveStateDataAttr.name = "data"
    saveStateDataAttr.attributeType = .binaryDataAttributeType
    saveStateDataAttr.isOptional = true
    saveStateDataAttr.allowsExternalBinaryDataStorage = true

    let saveStateScreenshotDataAttr = NSAttributeDescription()
    saveStateScreenshotDataAttr.name = "screenshotData"
    saveStateScreenshotDataAttr.attributeType = .binaryDataAttributeType
    saveStateScreenshotDataAttr.isOptional = true
    saveStateScreenshotDataAttr.allowsExternalBinaryDataStorage = true

    let romRelationAttr = NSRelationshipDescription()
    romRelationAttr.name = "rom"
    romRelationAttr.destinationEntity = romEntryEntity
    romRelationAttr.minCount = 0
    romRelationAttr.maxCount = 1
    romRelationAttr.deleteRule = .nullifyDeleteRule

    saveStateEntity.properties = [
        saveStateIdAttr, saveStateSlotIndexAttr, saveStateCreatedAtAttr, saveStateTimestampAttr,
        saveStateTitleAttr, saveStateDataAttr, saveStateScreenshotDataAttr, romRelationAttr
    ]

    let saveStatesRelationAttr = NSRelationshipDescription()
    saveStatesRelationAttr.name = "saveStates"
    saveStatesRelationAttr.destinationEntity = saveStateEntity
    saveStatesRelationAttr.minCount = 0
    saveStatesRelationAttr.maxCount = 10
    saveStatesRelationAttr.deleteRule = .cascadeDeleteRule
    saveStatesRelationAttr.inverseRelationship = romRelationAttr
    romRelationAttr.inverseRelationship = saveStatesRelationAttr

    var romProperties = romEntryEntity.properties ?? []
    romProperties.append(saveStatesRelationAttr)
    romEntryEntity.properties = romProperties

    let controllerMappingEntity = NSEntityDescription()
    controllerMappingEntity.name = "ControllerMapping"
    controllerMappingEntity.managedObjectClassName = "Xemu.ControllerMapping"

    let cmControllerTypeAttr = NSAttributeDescription()
    cmControllerTypeAttr.name = "controllerType"
    cmControllerTypeAttr.attributeType = .stringAttributeType
    cmControllerTypeAttr.isOptional = false

    let cmMappingDataAttr = NSAttributeDescription()
    cmMappingDataAttr.name = "mappingData"
    cmMappingDataAttr.attributeType = .stringAttributeType
    cmMappingDataAttr.isOptional = false

    let cmPlatformRawAttr = NSAttributeDescription()
    cmPlatformRawAttr.name = "platformRaw"
    cmPlatformRawAttr.attributeType = .stringAttributeType
    cmPlatformRawAttr.isOptional = false

    let cmUpdatedAtAttr = NSAttributeDescription()
    cmUpdatedAtAttr.name = "updatedAt"
    cmUpdatedAtAttr.attributeType = .dateAttributeType
    cmUpdatedAtAttr.isOptional = false

    controllerMappingEntity.properties = [
        cmControllerTypeAttr, cmMappingDataAttr, cmPlatformRawAttr, cmUpdatedAtAttr
    ]

    model.entities = [gameEntity, entitlementEntity, romEntryEntity, saveStateEntity, controllerMappingEntity]

    return model
}
