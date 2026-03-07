import CryptoKit
import Foundation

struct CoverMetadataManifest: Decodable, Sendable {
    struct ManifestFile: Decodable, Sendable {
        let path: String
        let sha256: String
    }

    let schemaVersion: Int
    let datasetVersion: String
    let minAppVersion: String
    let files: [ManifestFile]
    let checksumListFile: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case datasetVersion = "dataset_version"
        case minAppVersion = "min_app_version"
        case files
        case checksumListFile = "checksum_list_file"
    }
}

enum CoverMetadataManifestValidationError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case missingFile(path: String)
    case checksumMismatch(path: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "Unsupported metadata schema version: \(version)"
        case .missingFile(let path):
            return "Missing metadata file: \(path)"
        case .checksumMismatch(let path):
            return "Checksum mismatch for metadata file: \(path)"
        }
    }
}

struct CoverMetadataManifestValidator {
    private let supportedSchemaVersions: Set<Int>
    private let fileManager: FileManager

    init(supportedSchemaVersions: Set<Int> = [1], fileManager: FileManager = .default) {
        self.supportedSchemaVersions = supportedSchemaVersions
        self.fileManager = fileManager
    }

    func validate(manifestURL: URL) throws -> CoverMetadataManifest {
        let manifestData = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        let manifest = try decoder.decode(CoverMetadataManifest.self, from: manifestData)

        guard supportedSchemaVersions.contains(manifest.schemaVersion) else {
            throw CoverMetadataManifestValidationError.unsupportedSchemaVersion(manifest.schemaVersion)
        }

        let baseURL = manifestURL.deletingLastPathComponent()
        for file in manifest.files {
            let fileURL = baseURL.appendingPathComponent(file.path)
            guard fileManager.fileExists(atPath: fileURL.path) else {
                throw CoverMetadataManifestValidationError.missingFile(path: file.path)
            }

            let digest = SHA256.hash(data: try Data(contentsOf: fileURL))
            let digestHex = digest.map { String(format: "%02x", $0) }.joined()
            if digestHex.lowercased() != file.sha256.lowercased() {
                throw CoverMetadataManifestValidationError.checksumMismatch(path: file.path)
            }
        }

        if let checksumListFile = manifest.checksumListFile {
            let checksumURL = baseURL.appendingPathComponent(checksumListFile)
            guard fileManager.fileExists(atPath: checksumURL.path) else {
                throw CoverMetadataManifestValidationError.missingFile(path: checksumListFile)
            }
        }

        return manifest
    }
}
