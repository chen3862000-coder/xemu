import Compression
import Foundation

struct SaveStateMetadata: Codable {
    let slot: Int
    let romHash: String
    let platform: String
    let createdAt: Date
    let gameTitle: String
    let emulatorVersion: String
}

@MainActor
final class SaveStateStorage {
    enum StorageError: Error {
        case metadataEncodingFailed
        case metadataDecodingFailed
        case dataNotFound
        case decompressionFailed
    }

    private let directory: URL
    private let workQueue = DispatchQueue(label: "com.xemu.savestates", qos: .utility)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("SaveStates")
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func persist(data: Data, metadata: SaveStateMetadata, completion: @escaping (Result<URL, Error>) -> Void) {
        workQueue.async {
            do {
                let slotDirectory = self.directory.appendingPathComponent(String(metadata.slot), isDirectory: true)
                try FileManager.default.createDirectory(at: slotDirectory, withIntermediateDirectories: true)

                let binaryURL = slotDirectory.appendingPathComponent("payload.bin")
                let metadataURL = slotDirectory.appendingPathComponent("metadata.json")

                let compressed = try self.compress(data: data)
                try compressed.write(to: binaryURL, options: .atomic)

                let metadataData = try self.encoder.encode(metadata)
                try metadataData.write(to: metadataURL, options: .atomic)

                completion(.success(binaryURL))
            } catch {
                completion(.failure(error))
            }
        }
    }

    func load(slot: String) throws -> (Data, SaveStateMetadata) {
        let slotDirectory = directory.appendingPathComponent(slot, isDirectory: true)
        let binaryURL = slotDirectory.appendingPathComponent("payload.bin")
        let metadataURL = slotDirectory.appendingPathComponent("metadata.json")

        guard FileManager.default.fileExists(atPath: binaryURL.path) else {
            throw StorageError.dataNotFound
        }

        let metadataData = try Data(contentsOf: metadataURL)
        let metadata = try decoder.decode(SaveStateMetadata.self, from: metadataData)
        let compressedData = try Data(contentsOf: binaryURL)
        let decompressed = try decompress(data: compressedData)

        return (decompressed, metadata)
    }

    func list() throws -> [SaveStateMetadata] {
        let slotDirectories = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        return try slotDirectories.compactMap { url -> SaveStateMetadata? in
            let metadataURL = url.appendingPathComponent("metadata.json")
            guard FileManager.default.fileExists(atPath: metadataURL.path) else { return nil }
            let data = try Data(contentsOf: metadataURL)
            return try decoder.decode(SaveStateMetadata.self, from: data)
        }.sorted(by: { $0.createdAt > $1.createdAt })
    }

    // MARK: - Compression helpers

    private func compress(data: Data) throws -> Data {
        return try (data as NSData).compressed(using: .lzfse) as Data
    }

    private func decompress(data: Data) throws -> Data {
        return try (data as NSData).decompressed(using: .lzfse) as Data
    }
}