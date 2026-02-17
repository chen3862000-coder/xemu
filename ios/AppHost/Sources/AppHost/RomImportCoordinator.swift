import Foundation
import CoreData
import Combine
import CryptoKit

@objc(ROMLibraryEntry)
public class ROMLibraryEntry: NSManagedObject {
    @NSManaged public var entryId: UUID?
    @NSManaged public var romHash: String
    @NSManaged public var title: String
    @NSManaged public var platform: String
    @NSManaged public var tier: String
    @NSManaged public var artworkUri: URL?
    @NSManaged public var playtimeTotal: Int
    @NSManaged public var completionState: String
    @NSManaged public var lastPlayedAt: Date?
    @NSManaged public var eligibleForLeaderboard: Bool
}

public extension ROMLibraryEntry {
    @nonobjc class func fetchRequest() -> NSFetchRequest<ROMLibraryEntry> {
        return NSFetchRequest<ROMLibraryEntry>(entityName: "ROMLibraryEntry")
    }
}

public class PersistenceController: @unchecked Sendable {
    @MainActor
    public static let shared = PersistenceController()
    
    public let container: NSPersistentContainer
    
    public init(inMemory: Bool = false) {
        let model = PersistenceController.createInMemoryModel()
        container = NSPersistentContainer(name: "Model", managedObjectModel: model)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, _ in }
    }
    
    fileprivate static func createInMemoryModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        let entity = NSEntityDescription()
        entity.name = "ROMLibraryEntry"
        entity.managedObjectClassName = "ROMLibraryEntry"
        
        let entryIdAttr = NSAttributeDescription()
        entryIdAttr.name = "entryId"
        entryIdAttr.attributeType = .UUIDAttributeType
        entryIdAttr.isOptional = true
        
        let romHashAttr = NSAttributeDescription()
        romHashAttr.name = "romHash"
        romHashAttr.attributeType = .stringAttributeType
        romHashAttr.isOptional = false
        romHashAttr.defaultValue = ""
        
        let titleAttr = NSAttributeDescription()
        titleAttr.name = "title"
        titleAttr.attributeType = .stringAttributeType
        titleAttr.isOptional = false
        titleAttr.defaultValue = ""
        
        let platformAttr = NSAttributeDescription()
        platformAttr.name = "platform"
        platformAttr.attributeType = .stringAttributeType
        platformAttr.isOptional = false
        platformAttr.defaultValue = ""
        
        let tierAttr = NSAttributeDescription()
        tierAttr.name = "tier"
        tierAttr.attributeType = .stringAttributeType
        tierAttr.isOptional = false
        tierAttr.defaultValue = ""
        
        let artworkUriAttr = NSAttributeDescription()
        artworkUriAttr.name = "artworkUri"
        artworkUriAttr.attributeType = .URIAttributeType
        artworkUriAttr.isOptional = true
        
        let playtimeTotalAttr = NSAttributeDescription()
        playtimeTotalAttr.name = "playtimeTotal"
        playtimeTotalAttr.attributeType = .integer64AttributeType
        playtimeTotalAttr.isOptional = false
        playtimeTotalAttr.defaultValue = 0
        
        let completionStateAttr = NSAttributeDescription()
        completionStateAttr.name = "completionState"
        completionStateAttr.attributeType = .stringAttributeType
        completionStateAttr.isOptional = false
        completionStateAttr.defaultValue = ""
        
        let lastPlayedAtAttr = NSAttributeDescription()
        lastPlayedAtAttr.name = "lastPlayedAt"
        lastPlayedAtAttr.attributeType = .dateAttributeType
        lastPlayedAtAttr.isOptional = true
        
        let eligibleForLeaderboardAttr = NSAttributeDescription()
        eligibleForLeaderboardAttr.name = "eligibleForLeaderboard"
        eligibleForLeaderboardAttr.attributeType = .booleanAttributeType
        eligibleForLeaderboardAttr.isOptional = false
        eligibleForLeaderboardAttr.defaultValue = false
        
        entity.properties = [
            entryIdAttr,
            romHashAttr,
            titleAttr,
            platformAttr,
            tierAttr,
            artworkUriAttr,
            playtimeTotalAttr,
            completionStateAttr,
            lastPlayedAtAttr,
            eligibleForLeaderboardAttr
        ]
        
        model.entities = [entity]
        
        return model
    }
}

public class ImportProgress: Equatable {
    public let total: Int
    public let completed: Int
    public let currentFileName: String?

    public var completedCount: Int {
        completed
    }

    public init(total: Int, completed: Int, currentFileName: String?) {
        self.total = total
        self.completed = completed
        self.currentFileName = currentFileName
    }

    public static func == (lhs: ImportProgress, rhs: ImportProgress) -> Bool {
        return lhs.total == rhs.total &&
               lhs.completed == rhs.completed &&
               lhs.currentFileName == rhs.currentFileName
    }
}

public final class RomImportCoordinator: @unchecked Sendable {
    private let persistenceController: PersistenceController
    private let romsDirectory: URL
    
    public let importProgress = PassthroughSubject<ImportProgress, Never>()
    
    public init(persistenceController: PersistenceController, romsDirectory: URL) {
        self.persistenceController = persistenceController
        self.romsDirectory = romsDirectory
    }
    
    public func deriveTitle(from fileName: String) -> String {
        let title = fileName.replacingOccurrences(of: ".zip", with: "")
            .replacingOccurrences(of: ".nes", with: "")
            .replacingOccurrences(of: ".gba", with: "")
            .replacingOccurrences(of: ".gb", with: "")
        return title.replacingOccurrences(of: "_", with: " ")
    }
    
    public func detectPlatform(from fileName: String) -> Platform? {
        let lowercased = fileName.lowercased()
        if lowercased.hasSuffix(".nes") {
            return .NES
        } else if lowercased.hasSuffix(".gba") {
            return .GBA
        } else if lowercased.hasSuffix(".gb") {
            return .GB
        } else if lowercased.hasSuffix(".nds") {
            return .NDS
        } else if lowercased.hasSuffix(".zip") {
            return detectPlatformFromZipName(lowercased)
        }
        return nil
    }
    
    private func detectPlatformFromZipName(_ fileName: String) -> Platform? {
        if fileName.contains("nes") || fileName.contains("nintendo") {
            return .NES
        } else if fileName.contains("gba") || fileName.contains("gameboy advance") {
            return .GBA
        } else if fileName.contains("gb") || fileName.contains("gameboy") {
            return .GB
        } else if fileName.contains("nds") || fileName.contains("ds") {
            return .NDS
        }
        return nil
    }
    
    public func computeSHA256Hash(for data: Data) throws -> String {
        guard let digest = data.sha256() else {
            throw NSError(domain: "RomImportError", code: -1, userInfo: nil)
        }
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    public func importROM(from url: URL) throws -> ROMLibraryEntry {
        let data = try Data(contentsOf: url)
        let hash = try computeSHA256Hash(for: data)
        let title = deriveTitle(from: url.lastPathComponent)
        let platform = detectPlatform(from: url.lastPathComponent) ?? .NES
        
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "romHash == %@", hash)
        fetchRequest.fetchLimit = 1
        
        let existingEntries = try context.fetch(fetchRequest)
        if let existing = existingEntries.first {
            return existing
        }
        
        let entry = ROMLibraryEntry(context: context)
        entry.entryId = UUID()
        entry.romHash = hash
        entry.title = title
        entry.platform = platform.rawValue
        entry.tier = Tier.unknown.rawValue
        entry.playtimeTotal = 0
        entry.completionState = CompletionState.NotStarted.rawValue
        entry.eligibleForLeaderboard = true
        
        try context.save()
        return entry
    }
    
    public func batchImport(urls: [URL]) {
        let total = urls.count
        for (index, url) in urls.enumerated() {
            importProgress.send(ImportProgress(total: total, completed: index, currentFileName: url.lastPathComponent))
            
            do {
                _ = try importROM(from: url)
            } catch {
                continue
            }
            
            importProgress.send(ImportProgress(total: total, completed: index + 1, currentFileName: url.lastPathComponent))
        }
    }
}

extension Data {
    func sha256() -> [UInt8]? {
        let hash = SHA256.hash(data: self)
        return Array(hash)
    }
    
    func md5() -> String {
        let hash = Insecure.MD5.hash(data: self)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
