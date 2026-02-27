import CoreData
import Foundation

extension Notification.Name {
    static let romLibraryDidChange = Notification.Name("romLibraryDidChange")
}

struct ROMLaunchIssue: Equatable {
    let title: String
    let message: String
    let iconName: String
}

struct ROMLaunchCompatibility: Equatable {
    let canLaunch: Bool
    let issue: ROMLaunchIssue?

    static let compatible = ROMLaunchCompatibility(canLaunch: true, issue: nil)
}

enum GameDeletionMode {
    case removeROMOnly
    case removeAll

    var displayName: String {
        switch self {
        case .removeROMOnly: return "Remove ROM Only"
        case .removeAll: return "Remove"
        }
    }

    var firstConfirmation: String {
        switch self {
        case .removeROMOnly:
            return "This removes only the ROM file. Game metadata and save states stay in your library."
        case .removeAll:
            return "This removes the ROM, metadata, and all save data for this game."
        }
    }

    var secondConfirmation: String {
        switch self {
        case .removeROMOnly:
            return "This action cannot be undone. Continue removing ROM only?"
        case .removeAll:
            return "This action cannot be undone. Continue removing everything?"
        }
    }
}

@MainActor
final class ROMCompatibilityService {
    static let shared = ROMCompatibilityService()

    private var cache: [String: ROMLaunchCompatibility] = [:]
    private let unsupportedGBCartridgeTypes: [UInt8: String] = [
        0x22: "MBC7"
    ]

    private init() {}

    func compatibility(for entry: ROMLibraryEntry) -> ROMLaunchCompatibility {
        guard let key = cacheKey(for: entry) else {
            return .compatible
        }
        if let cached = cache[key] {
            return cached
        }
        let value = computeCompatibility(for: entry)
        cache[key] = value
        return value
    }

    func compatibility(for game: Game) -> ROMLaunchCompatibility {
        guard let platform = game.gamePlatform,
              platform == .GB || platform == .GBC,
              let romPath = game.romPath else {
            return .compatible
        }
        let cacheKey = "game:\(game.id.uuidString):\(romPath)"
        if let cached = cache[cacheKey] {
            return cached
        }
        let value = computeCompatibility(romPath: romPath, platform: platform)
        cache[cacheKey] = value
        return value
    }

    func invalidateCache() {
        cache.removeAll()
    }

    private func computeCompatibility(for entry: ROMLibraryEntry) -> ROMLaunchCompatibility {
        guard let game = entry.toGame(),
              let platform = game.gamePlatform,
              platform == .GB || platform == .GBC,
              let romPath = game.romPath else {
            return .compatible
        }
        return computeCompatibility(romPath: romPath, platform: platform)
    }

    private func computeCompatibility(romPath: String, platform: Platform) -> ROMLaunchCompatibility {
        let url = URL(fileURLWithPath: romPath)
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return .compatible
        }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 0x150), data.count > 0x147 else {
            return .compatible
        }
        let cartType = data[data.startIndex + 0x147]
        if let mapper = unsupportedGBCartridgeTypes[cartType] {
            let issue = ROMLaunchIssue(
                title: "Unsupported Mapper",
                message: "\(mapper) cartridges are not supported yet for GB/GBC in this build. Please use a different ROM dump or mapper type.",
                iconName: "exclamationmark.triangle.fill"
            )
            return ROMLaunchCompatibility(canLaunch: false, issue: issue)
        }

        return .compatible
    }

    private func cacheKey(for entry: ROMLibraryEntry) -> String? {
        guard let checksum = entry.checksum else { return nil }
        return "entry:\(checksum):\(entry.fileName ?? ""):\(entry.system ?? "")"
    }
}

@MainActor
final class GameDeletionService {
    static let shared = GameDeletionService()

    private init() {}

    func delete(entry: ROMLibraryEntry, mode: GameDeletionMode, in context: NSManagedObjectContext) throws {
        if let checksum = entry.checksum {
            let fileExtension = (entry.fileName as NSString?)?.pathExtension.lowercased() ?? ""
            _ = ROMStorage.shared.deleteROMByChecksum(checksum: checksum, preferredExtension: fileExtension)
            if mode == .removeAll {
                try SaveStateStorage.shared.deleteAll(forROMHash: checksum)
            }
        }

        if mode == .removeAll {
            deleteRelationshipObjects(named: "saveStates", for: entry, in: context)
            deleteRelationshipObjects(named: "nativeSaveFiles", for: entry, in: context)
            deleteRelationshipObjects(named: "gameSettings", for: entry, in: context)
            context.delete(entry)
        }

        if context.hasChanges {
            try context.save()
        }

        ROMCompatibilityService.shared.invalidateCache()
        NotificationCenter.default.post(name: .romLibraryDidChange, object: nil)
    }

    private func deleteRelationshipObjects(named relationship: String, for entry: ROMLibraryEntry, in context: NSManagedObjectContext) {
        guard entry.entity.relationshipsByName[relationship] != nil else {
            return
        }
        guard let objects = entry.value(forKey: relationship) as? NSSet else {
            return
        }
        for case let object as NSManagedObject in objects {
            context.delete(object)
        }
    }
}
