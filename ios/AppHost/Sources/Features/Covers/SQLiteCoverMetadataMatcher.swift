import Foundation
import SQLite3
import os.log

private let sqliteTransientDestructor = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct CoverMetadataMatch: Sendable, Equatable {
    enum Source: String, Sendable {
        case sha1
        case alias
    }

    let titleID: String
    let defaultCoverKey: String
    let confidence: Double
    let canonicalTitle: String?
    let source: Source
}

protocol CoverMetadataMatching: Sendable {
    func match(romSha1: String?, normalizedTitle: String, systemRaw: String) -> CoverMetadataMatch?
    func defaultCoverKey(for checksum: String, normalizedTitle: String, systemRaw: String) -> String?
}

extension CoverMetadataMatching {
    func defaultCoverKey(for checksum: String, normalizedTitle: String, systemRaw: String) -> String? {
        match(romSha1: checksum, normalizedTitle: normalizedTitle, systemRaw: systemRaw)?.defaultCoverKey
    }
}

struct NullCoverMetadataMatcher: CoverMetadataMatching {
    func match(romSha1: String?, normalizedTitle: String, systemRaw: String) -> CoverMetadataMatch? {
        nil
    }

    func defaultCoverKey(for checksum: String, normalizedTitle: String, systemRaw: String) -> String? {
        nil
    }
}

final class SQLiteCoverMetadataMatcher: @unchecked Sendable, CoverMetadataMatching {
    private let logger = Logger(subsystem: "com.xemu.app", category: "CoverMetadata")
    private let db: OpaquePointer
    private let aliasConfidenceThreshold: Double

    init(databaseURL: URL, aliasConfidenceThreshold: Double = 0.82) throws {
        self.aliasConfidenceThreshold = aliasConfidenceThreshold
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &handle, flags, nil) == SQLITE_OK,
              let handle else {
            let message = handle.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) } ?? "unknown"
            if let handle {
                sqlite3_close(handle)
            }
            throw NSError(
                domain: "SQLiteCoverMetadataMatcher",
                code: Int(SQLITE_CANTOPEN),
                userInfo: [NSLocalizedDescriptionKey: "Failed to open metadata DB: \(message)"]
            )
        }
        db = handle
    }

    deinit {
        sqlite3_close(db)
    }

    static func makeDefault() -> CoverMetadataMatching {
        do {
            guard let manifestURL = locateManifestURL() else {
                return NullCoverMetadataMatcher()
            }

            let validator = CoverMetadataManifestValidator()
            let manifest = try validator.validate(manifestURL: manifestURL)
            let baseURL = manifestURL.deletingLastPathComponent()

            let sqlitePath = manifest.files.first(where: { $0.path.lowercased().hasSuffix(".sqlite") })?.path ?? "cover_metadata.sqlite"
            let sqliteURL = baseURL.appendingPathComponent(sqlitePath)
            return try SQLiteCoverMetadataMatcher(databaseURL: sqliteURL)
        } catch {
            return NullCoverMetadataMatcher()
        }
    }

    func match(romSha1: String?, normalizedTitle: String, systemRaw: String) -> CoverMetadataMatch? {
        let consoles = consoleCandidates(for: systemRaw)

        if let sha1 = sanitizeSHA1(romSha1), !sha1.isEmpty {
            for console in consoles {
                if let titleID = queryHashMap(console: console, sha1: sha1) {
                    return CoverMetadataMatch(
                        titleID: titleID,
                        defaultCoverKey: titleID,
                        confidence: 1.0,
                        canonicalTitle: queryCanonicalTitle(titleID: titleID),
                        source: .sha1
                    )
                }
            }
        }

        guard !normalizedTitle.isEmpty else { return nil }
        for console in consoles {
            if let aliasMatch = queryAlias(console: console, normalizedTitle: normalizedTitle),
               aliasMatch.confidence >= aliasConfidenceThreshold {
                return CoverMetadataMatch(
                    titleID: aliasMatch.titleID,
                    defaultCoverKey: aliasMatch.titleID,
                    confidence: aliasMatch.confidence,
                    canonicalTitle: queryCanonicalTitle(titleID: aliasMatch.titleID),
                    source: .alias
                )
            }
        }

        return nil
    }

    private static func locateManifestURL() -> URL? {
        let candidates = [
            resourceBundle.url(forResource: "metadata_manifest", withExtension: "json", subdirectory: "Features/Covers/Resources"),
            resourceBundle.url(forResource: "metadata_manifest", withExtension: "json"),
            resourceBundle.url(forResource: "metadata_manifest", withExtension: "json", subdirectory: "Resources"),
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .appendingPathComponent("Resources/metadata_manifest.json")
        ]

        return candidates.first(where: { url in
            guard let url else { return false }
            return FileManager.default.fileExists(atPath: url.path)
        }) ?? nil
    }

    private static var resourceBundle: Bundle {
#if SWIFT_PACKAGE
        return .module
#else
        return .main
#endif
    }

    private func sanitizeSHA1(_ value: String?) -> String? {
        let lower = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let lower, lower.count == 40 else { return nil }
        return lower
    }

    private func queryHashMap(console: String, sha1: String) -> String? {
        let sql = "SELECT title_id FROM rom_hash_map WHERE console = ? AND sha1 = ? LIMIT 1;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            logger.error("metadata hash query prepare failed")
            return nil
        }

        sqlite3_bind_text(statement, 1, console, -1, sqliteTransientDestructor)
        sqlite3_bind_text(statement, 2, sha1, -1, sqliteTransientDestructor)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let cString = sqlite3_column_text(statement, 0) else {
            return nil
        }

        return String(cString: cString)
    }

    private func queryAlias(console: String, normalizedTitle: String) -> (titleID: String, confidence: Double)? {
        let sql = "SELECT title_id, confidence FROM aliases WHERE console = ? AND alias_norm = ? ORDER BY confidence DESC LIMIT 1;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            logger.error("metadata alias query prepare failed")
            return nil
        }

        sqlite3_bind_text(statement, 1, console, -1, sqliteTransientDestructor)
        sqlite3_bind_text(statement, 2, normalizedTitle, -1, sqliteTransientDestructor)

        guard sqlite3_step(statement) == SQLITE_ROW,
              let cString = sqlite3_column_text(statement, 0) else {
            return nil
        }

        let titleID = String(cString: cString)
        let confidence = sqlite3_column_double(statement, 1)
        return (titleID, confidence)
    }

    private func queryCanonicalTitle(titleID: String) -> String? {
        let sql = "SELECT canonical_title FROM titles WHERE title_id = ? LIMIT 1;"
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK,
              let statement else {
            return nil
        }

        sqlite3_bind_text(statement, 1, titleID, -1, sqliteTransientDestructor)
        guard sqlite3_step(statement) == SQLITE_ROW,
              let cString = sqlite3_column_text(statement, 0) else {
            return nil
        }

        return String(cString: cString)
    }

    private func consoleCandidates(for systemRaw: String) -> [String] {
        let value = systemRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.contains("gba") {
            return ["gba"]
        }
        if value.contains("nds") {
            return ["nds"]
        }
        if value.contains("gbc") || value.contains("color") {
            return ["gbc", "gb"]
        }
        if value == "gb" || value.contains("game boy") {
            return ["gb", "gbc"]
        }
        if value.isEmpty {
            return ["unknown"]
        }
        return [value]
    }
}
