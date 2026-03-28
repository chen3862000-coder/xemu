import Combine
import Compression
import CoreData
import Foundation

struct SaveStateMetadata: Codable {
    let slot: Int
    let romHash: String
    let platform: String
    let createdAt: Date
    let gameTitle: String
    let emulatorVersion: String
    let screenshotData: Data?
}

struct SaveStateSlotSummary: Identifiable {
    let slot: Int
    let metadata: SaveStateMetadata?
    let screenshotData: Data?

    var id: Int { slot }
    var isEmpty: Bool { metadata == nil }
    var isQuickSlot: Bool { slot == 0 }
    var displayName: String { isQuickSlot ? "Quick" : "\(slot)" }
}

@MainActor
final class SaveStateStorage {
    enum StorageError: Error {
        case metadataEncodingFailed
        case metadataDecodingFailed
        case dataNotFound
        case decompressionFailed
        case screenshotCaptureFailed
        case coreDataError(Error)
        case invalidSlot
    }

    private static func normalize(_ error: Error) -> StorageError {
        if let storageError = error as? StorageError {
            return storageError
        }
        return .coreDataError(error)
    }

    static let shared = SaveStateStorage()
    static let maxSlots = 11

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let viewContext: NSManagedObjectContext
    
    init(directory: URL? = nil, viewContext: NSManagedObjectContext? = nil) {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.directory = directory ?? documentsDirectory.appendingPathComponent("SaveStates")
        self.viewContext = viewContext ?? PersistenceController.shared.viewContext
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func persist(data: Data, metadata: SaveStateMetadata, screenshotData: Data? = nil) async throws {
        try persistImmediately(data: data, metadata: metadata, screenshotData: screenshotData)
    }

    func persistImmediately(data: Data, metadata: SaveStateMetadata, screenshotData: Data? = nil) throws {
        guard metadata.slot >= 0 && metadata.slot < Self.maxSlots else {
            throw StorageError.invalidSlot
        }

        let compressed = try compress(data: data)
        let context = viewContext

        let saveState = try fetchOrCreateSaveState(slot: metadata.slot, romHash: metadata.romHash, context: context)
        saveState.slotIndex = Int16(metadata.slot)
        saveState.createdAt = metadata.createdAt
        saveState.timestamp = metadata.createdAt
        saveState.data = compressed
        saveState.screenshotData = screenshotData
        saveState.title = metadata.gameTitle
        saveState.rom = try fetchROM(checksum: metadata.romHash, context: context)
        
        do {
            try context.save()
        } catch {
            throw Self.normalize(error)
        }

        let slotDirectory = slotDirectoryURL(slot: metadata.slot, romHash: metadata.romHash)
        try FileManager.default.createDirectory(at: slotDirectory, withIntermediateDirectories: true)

        let payloadURL = slotDirectory.appendingPathComponent("payload.bin")
        let metadataURL = slotDirectory.appendingPathComponent("metadata.json")
        let metadataData = try encoder.encode(metadata)
        try compressed.write(to: payloadURL, options: .atomic)
        try metadataData.write(to: metadataURL, options: .atomic)

        let screenshotURL = slotDirectory.appendingPathComponent("screenshot.jpg")
        if let screenshotData {
            try screenshotData.write(to: screenshotURL, options: .atomic)
        } else if FileManager.default.fileExists(atPath: screenshotURL.path) {
            try FileManager.default.removeItem(at: screenshotURL)
        }
    }

    func load(slot: Int, romHash: String? = nil) throws -> (Data, SaveStateMetadata, Data?) {
        guard slot >= 0 && slot < Self.maxSlots else {
            throw StorageError.invalidSlot
        }

        if let romHash {
            let slotDirectory = slotDirectoryURL(slot: slot, romHash: romHash)
            if let result = try loadFromDisk(slotDirectory: slotDirectory) {
                return result
            }
        }

        let legacyDirectory = directory.appendingPathComponent(String(slot), isDirectory: true)
        if let result = try loadFromDisk(slotDirectory: legacyDirectory) {
            return result
        }

        if let saveState = try fetchSaveState(slot: slot, romHash: romHash, context: viewContext),
           let compressedData = saveState.data {
            let decompressed = try decompress(data: compressedData)
            let inferredHash = romHash
                ?? saveState.rom?.checksum
                ?? inferROMHashFromDisk(slot: slot)
                ?? ""
            let metadata = SaveStateMetadata(
                slot: slot,
                romHash: inferredHash,
                platform: saveState.rom?.system ?? "",
                createdAt: saveState.timestamp,
                gameTitle: saveState.title ?? saveState.rom?.title ?? "Unknown Game",
                emulatorVersion: "1.0.0",
                screenshotData: saveState.screenshotData
            )
            return (decompressed, metadata, saveState.screenshotData)
        }

        throw StorageError.dataNotFound
    }

    func debugSummary(romHash: String) -> String {
        let quickDir = slotDirectoryURL(slot: 0, romHash: romHash)
        let gameDir = slotDirectoryURL(slot: 9, romHash: romHash)
        let quickExists = FileManager.default.fileExists(atPath: quickDir.appendingPathComponent("payload.bin").path)
        let gameExists = FileManager.default.fileExists(atPath: gameDir.appendingPathComponent("payload.bin").path)

        let quickTime = (try? Data(contentsOf: quickDir.appendingPathComponent("metadata.json"))).flatMap {
            try? decoder.decode(SaveStateMetadata.self, from: $0).createdAt
        }
        let gameTime = (try? Data(contentsOf: gameDir.appendingPathComponent("metadata.json"))).flatMap {
            try? decoder.decode(SaveStateMetadata.self, from: $0).createdAt
        }

        let formatter = ISO8601DateFormatter()
        let quickText = quickTime.map { formatter.string(from: $0) } ?? "-"
        let gameText = gameTime.map { formatter.string(from: $0) } ?? "-"
        return "Quick[\(quickExists ? "OK" : "-")]@\(quickText)  Game[\(gameExists ? "OK" : "-")]@\(gameText)"
    }

    private func loadFromDisk(slotDirectory: URL) throws -> (Data, SaveStateMetadata, Data?)? {
        let binaryURL = slotDirectory.appendingPathComponent("payload.bin")
        let metadataURL = slotDirectory.appendingPathComponent("metadata.json")
        let screenshotURL = slotDirectory.appendingPathComponent("screenshot.jpg")

        guard FileManager.default.fileExists(atPath: binaryURL.path) else {
            return nil
        }

        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try decoder.decode(SaveStateMetadata.self, from: metadataData)
        let compressedData = try Data(contentsOf: binaryURL)
        let decompressed = try decompress(data: compressedData)
        
        var screenshotData: Data? = nil
        if FileManager.default.fileExists(atPath: screenshotURL.path) {
            screenshotData = try Data(contentsOf: screenshotURL)
        }

        return (decompressed, metadata, screenshotData)
    }

    func list() throws -> [SaveState] {
        let fetchRequest: NSFetchRequest<SaveState> = SaveState.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \SaveState.slotIndex, ascending: true)]
        return try viewContext.fetch(fetchRequest)
    }

    func list(for romChecksum: String) async throws -> [SaveState] {
        let request: NSFetchRequest<SaveState> = SaveState.fetchRequest()
        request.predicate = NSPredicate(format: "rom.checksum == %@", romChecksum)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SaveState.timestamp, ascending: false)]
        return try viewContext.fetch(request)
    }

    func listSlotSummaries(for romHash: String) -> [SaveStateSlotSummary] {
        (0..<Self.maxSlots).map { slot in
            if let loaded = try? load(slot: slot, romHash: romHash) {
                return SaveStateSlotSummary(slot: slot, metadata: loaded.1, screenshotData: loaded.2)
            }
            return SaveStateSlotSummary(slot: slot, metadata: nil, screenshotData: nil)
        }
    }

    func hasAnySaveState(for romHash: String) -> Bool {
        (0..<Self.maxSlots).contains { slot in
            (try? load(slot: slot, romHash: romHash)) != nil
        }
    }

    func latestScreenshot(for romHash: String) -> Data? {
        let request: NSFetchRequest<SaveState> = SaveState.fetchRequest()
        request.predicate = NSPredicate(format: "rom.checksum == %@ AND screenshotData != nil", romHash)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SaveState.timestamp, ascending: false)]
        request.fetchLimit = 1
        if let state = try? viewContext.fetch(request).first, let data = state.screenshotData {
            return data
        }

        // Disk fallback (best-effort)
        var bestDate: Date?
        var bestData: Data?
        for slot in 0..<Self.maxSlots {
            if let (_, metadata, screenshot) = try? load(slot: slot, romHash: romHash),
               let screenshot {
                if bestDate == nil || metadata.createdAt > bestDate! {
                    bestDate = metadata.createdAt
                    bestData = screenshot
                }
            }
        }
        return bestData
    }

    func delete(saveState: SaveState) async throws {
        viewContext.delete(saveState)
        try viewContext.save()
        
        if let romHash = saveState.rom?.checksum {
            let slotDirectory = slotDirectoryURL(slot: Int(saveState.slotIndex), romHash: romHash)
            if FileManager.default.fileExists(atPath: slotDirectory.path) {
                try FileManager.default.removeItem(at: slotDirectory)
            }
        } else {
            let legacyDirectory = directory.appendingPathComponent(String(saveState.slotIndex), isDirectory: true)
            if FileManager.default.fileExists(atPath: legacyDirectory.path) {
                try FileManager.default.removeItem(at: legacyDirectory)
            }
        }
    }

    func deleteAll(forROMHash romHash: String) throws {
        guard !romHash.isEmpty else { return }

        let request: NSFetchRequest<SaveState> = SaveState.fetchRequest()
        request.predicate = NSPredicate(format: "rom.checksum == %@", romHash)
        let states = try viewContext.fetch(request)
        for state in states {
            viewContext.delete(state)
        }
        if viewContext.hasChanges {
            try viewContext.save()
        }

        let romDirectory = directory.appendingPathComponent(romHash, isDirectory: true)
        if FileManager.default.fileExists(atPath: romDirectory.path) {
            try FileManager.default.removeItem(at: romDirectory)
        }
    }

    func capture(for rom: ROMLibraryEntry, slot: Int, screenshotData: Data? = nil) async throws {
        throw StorageError.coreDataError(
            NSError(
                domain: "SaveStateStorage",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Direct capture requires active emulator session state payload"]
            )
        )
    }

    func load(saveState: SaveState) async throws {
        guard let data = saveState.data else {
            throw StorageError.dataNotFound
        }
        _ = try decompress(data: data)
    }

    func validate(saveState: SaveState) -> Bool {
        guard let data = saveState.data else { return false }
        do {
            _ = try decompress(data: data)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Compression helpers

    private func compress(data: Data) throws -> Data {
        return try (data as NSData).compressed(using: .lzfse) as Data
    }

    private func decompress(data: Data) throws -> Data {
        return try (data as NSData).decompressed(using: .lzfse) as Data
    }

    private func slotDirectoryURL(slot: Int, romHash: String) -> URL {
        directory
            .appendingPathComponent(romHash, isDirectory: true)
            .appendingPathComponent(String(slot), isDirectory: true)
    }

    private func fetchROM(checksum: String, context: NSManagedObjectContext) throws -> ROMLibraryEntry? {
        guard !checksum.isEmpty else { return nil }
        let request: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        request.predicate = NSPredicate(format: "checksum == %@", checksum)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func inferROMHashFromDisk(slot: Int) -> String? {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        for candidate in contents {
            let metadataURL = candidate
                .appendingPathComponent(String(slot), isDirectory: true)
                .appendingPathComponent("metadata.json")
            guard FileManager.default.fileExists(atPath: metadataURL.path),
                  let data = try? Data(contentsOf: metadataURL),
                  let metadata = try? decoder.decode(SaveStateMetadata.self, from: data),
                  !metadata.romHash.isEmpty else {
                continue
            }
            return metadata.romHash
        }

        return nil
    }

    private func fetchSaveState(slot: Int, romHash: String?, context: NSManagedObjectContext) throws -> SaveState? {
        let request: NSFetchRequest<SaveState> = SaveState.fetchRequest()
        if let romHash, !romHash.isEmpty {
            request.predicate = NSPredicate(format: "slotIndex == %d AND rom.checksum == %@", slot, romHash)
        } else {
            request.predicate = NSPredicate(format: "slotIndex == %d", slot)
        }
        request.sortDescriptors = [NSSortDescriptor(keyPath: \SaveState.timestamp, ascending: false)]
        request.fetchLimit = 1
        do {
            return try context.fetch(request).first
        } catch {
            throw Self.normalize(error)
        }
    }

    private func fetchOrCreateSaveState(slot: Int, romHash: String, context: NSManagedObjectContext) throws -> SaveState {
        if let existing = try fetchSaveState(slot: slot, romHash: romHash, context: context) {
            if existing.value(forKey: "id") == nil {
                existing.setValue(UUID(), forKey: "id")
            }
            return existing
        }
        guard let entity = NSEntityDescription.entity(forEntityName: "SaveState", in: context) else {
            throw StorageError.dataNotFound
        }
        let state = SaveState(entity: entity, insertInto: context)
        state.setValue(UUID(), forKey: "id")
        return state
    }
}
