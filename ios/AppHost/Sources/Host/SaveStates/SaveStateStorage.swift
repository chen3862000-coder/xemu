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

    static let shared = SaveStateStorage()
    static let maxSlots = 10

    private let directory: URL
    private let workQueue = DispatchQueue(label: "com.xemu.savestates", qos: .utility)
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
        guard metadata.slot >= 0 && metadata.slot < Self.maxSlots else {
            throw StorageError.invalidSlot
        }
        
        let context = viewContext
        let saveState = SaveState(context: context)
        saveState.slotIndex = Int16(metadata.slot)
        saveState.createdAt = metadata.createdAt
        saveState.timestamp = metadata.createdAt
        saveState.data = try compress(data: data)
        saveState.screenshotData = screenshotData
        saveState.title = metadata.gameTitle
        
        try context.save()
        
        let slotDirectory = directory.appendingPathComponent(String(metadata.slot), isDirectory: true)
        try FileManager.default.createDirectory(at: slotDirectory, withIntermediateDirectories: true)
        
        let metadataURL = slotDirectory.appendingPathComponent("metadata.json")
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataURL, options: .atomic)
    }

    func load(slot: Int) throws -> (Data, SaveStateMetadata, Data?) {
        guard slot >= 0 && slot < Self.maxSlots else {
            throw StorageError.invalidSlot
        }
        
        let slotDirectory = directory.appendingPathComponent(String(slot), isDirectory: true)
        let binaryURL = slotDirectory.appendingPathComponent("payload.bin")
        let metadataURL = slotDirectory.appendingPathComponent("metadata.json")
        let screenshotURL = slotDirectory.appendingPathComponent("screenshot.jpg")

        guard FileManager.default.fileExists(atPath: binaryURL.path) else {
            throw StorageError.dataNotFound
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
        let allStates = try list()
        return allStates.filter { $0.rom?.checksum == romChecksum }
    }

    func delete(saveState: SaveState) async throws {
        viewContext.delete(saveState)
        try viewContext.save()
        
        let slotDirectory = directory.appendingPathComponent(String(saveState.slotIndex), isDirectory: true)
        if FileManager.default.fileExists(atPath: slotDirectory.path) {
            try FileManager.default.removeItem(at: slotDirectory)
        }
    }

    func capture(for rom: ROMLibraryEntry, slot: Int, screenshotData: Data? = nil) async throws {
        guard let romChecksum = rom.checksum else {
            throw StorageError.coreDataError(NSError(domain: "SaveStateStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "ROM checksum is required"]))
        }
        
        let metadata = SaveStateMetadata(
            slot: slot,
            romHash: romChecksum,
            platform: rom.system ?? "",
            createdAt: Date(),
            gameTitle: rom.title ?? "Unknown Game",
            emulatorVersion: "1.0.0",
            screenshotData: screenshotData
        )
        
        let emulatorState = Data()
        try await persist(data: emulatorState, metadata: metadata, screenshotData: screenshotData)
    }

    func load(saveState: SaveState) async throws {
        guard let data = saveState.data else {
            throw StorageError.dataNotFound
        }
        let decompressed = try decompress(data: data)
        print("Loading save state: \(saveState.slotIndex), size: \(decompressed.count) bytes")
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
}
