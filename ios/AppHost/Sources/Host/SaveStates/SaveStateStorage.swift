import Compression
import Foundation

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

    init(directory: URL = PersistenceController.shared.saveStateDirectory) {
        self.directory = directory
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func persist(data: Data, metadata: SaveStateMetadata, completion: @escaping (Result<URL, Error>) -> Void) {
        workQueue.async {
            do {
                let slotDirectory = self.directory.appendingPathComponent(metadata.slot, isDirectory: true)
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
        return try performCompression(data: data, operation: COMPRESSION_STREAM_ENCODE)
    }

    private func decompress(data: Data) throws -> Data {
        return try performCompression(data: data, operation: COMPRESSION_STREAM_DECODE)
    }

    private func performCompression(data: Data, operation: compression_stream_operation) throws -> Data {
        let algorithm = COMPRESSION_LZFSE
        let destinationBufferSize = 64 * 1024
        var stream = compression_stream()
        var status = compression_stream_init(&stream, operation, algorithm)

        guard status != COMPRESSION_STATUS_ERROR else {
            throw StorageError.decompressionFailed
        }

        defer { compression_stream_destroy(&stream) }

        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destinationBufferSize)
        defer { dstBuffer.deallocate() }

        return data.withUnsafeBytes { (sourcePointer: UnsafeRawBufferPointer) -> Data in
            var output = Data()

            stream.src_ptr = sourcePointer.bindMemory(to: UInt8.self).baseAddress!
            stream.src_size = sourcePointer.count
            stream.dst_ptr = dstBuffer
            stream.dst_size = destinationBufferSize

            repeat {
                status = compression_stream_process(&stream, Int32(COMPRESSION_STREAM_FINALIZE.rawValue))

                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let count = destinationBufferSize - stream.dst_size
                    if count > 0 {
                        output.append(dstBuffer, count: count)
                    }
                    stream.dst_ptr = dstBuffer
                    stream.dst_size = destinationBufferSize
                case COMPRESSION_STATUS_ERROR:
                    return Data()
                default:
                    break
                }
            } while status == COMPRESSION_STATUS_OK

            if status == COMPRESSION_STATUS_ERROR {
                return Data()
            }

            return output
        }
    }
}
