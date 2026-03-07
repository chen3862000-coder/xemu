import CryptoKit
import Foundation
import SQLite3
import XCTest
@testable import Xemu

final class CoverMetadataTests: XCTestCase {
    func testManifestValidatorChecksFileHashes() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("cover_metadata.sqlite")
        try Data([0x00, 0x11, 0x22]).write(to: dbURL)

        let checksumsURL = tempDir.appendingPathComponent("sha1_checksums.txt")
        try Data().write(to: checksumsURL)

        let dbDigest = SHA256.hash(data: try Data(contentsOf: dbURL)).map { String(format: "%02x", $0) }.joined()
        let checksumsDigest = SHA256.hash(data: try Data(contentsOf: checksumsURL)).map { String(format: "%02x", $0) }.joined()

        let manifestURL = tempDir.appendingPathComponent("metadata_manifest.json")
        let manifest = """
        {
          "schema_version": 1,
          "dataset_version": "test",
          "min_app_version": "1.0.0",
          "files": [
            { "path": "cover_metadata.sqlite", "sha256": "\(dbDigest)" },
            { "path": "sha1_checksums.txt", "sha256": "\(checksumsDigest)" }
          ],
          "checksum_list_file": "sha1_checksums.txt"
        }
        """
        try manifest.data(using: .utf8)?.write(to: manifestURL)

        let validator = CoverMetadataManifestValidator()
        let result = try validator.validate(manifestURL: manifestURL)
        XCTAssertEqual(result.schemaVersion, 1)
        XCTAssertEqual(result.files.count, 2)
    }

    func testSQLiteMatcherPrefersSHA1ThenAliasFallback() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let dbURL = tempDir.appendingPathComponent("cover_metadata.sqlite")
        try makeTestDatabase(at: dbURL)

        let matcher = try SQLiteCoverMetadataMatcher(databaseURL: dbURL, aliasConfidenceThreshold: 0.80)

        let sha1 = String(repeating: "a", count: 40)
        let hashMatch = matcher.match(romSha1: sha1, normalizedTitle: "pokemon emerald", systemRaw: "gba")
        XCTAssertEqual(hashMatch?.source, .sha1)
        XCTAssertEqual(hashMatch?.titleID, "title.pokemon.emerald")

        let aliasMatch = matcher.match(romSha1: nil, normalizedTitle: "metroid ii", systemRaw: "gb")
        XCTAssertEqual(aliasMatch?.source, .alias)
        XCTAssertEqual(aliasMatch?.titleID, "title.metroid.2")

        let missing = matcher.match(romSha1: nil, normalizedTitle: "unknown game", systemRaw: "gba")
        XCTAssertNil(missing)
    }

    private func makeTestDatabase(at url: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open(url.path, &db) == SQLITE_OK, let db else {
            throw NSError(domain: "CoverMetadataTests", code: 1)
        }
        defer { sqlite3_close(db) }

        let statements = [
            "CREATE TABLE rom_hash_map (console TEXT NOT NULL, sha1 TEXT NOT NULL, crc32 TEXT, title_id TEXT NOT NULL, region TEXT, revision TEXT, PRIMARY KEY (console, sha1));",
            "CREATE TABLE titles (title_id TEXT PRIMARY KEY, canonical_title TEXT NOT NULL, sort_title TEXT, release_year INTEGER, developer TEXT, publisher TEXT, genre TEXT, languages TEXT, series TEXT, tags TEXT);",
            "CREATE TABLE aliases (console TEXT NOT NULL, alias_norm TEXT NOT NULL, title_id TEXT NOT NULL, confidence REAL NOT NULL, PRIMARY KEY (console, alias_norm, title_id));",
            "INSERT INTO titles(title_id, canonical_title) VALUES ('title.pokemon.emerald', 'Pokemon Emerald');",
            "INSERT INTO titles(title_id, canonical_title) VALUES ('title.metroid.2', 'Metroid II');",
            "INSERT INTO rom_hash_map(console, sha1, title_id) VALUES ('gba', '\(String(repeating: "a", count: 40))', 'title.pokemon.emerald');",
            "INSERT INTO aliases(console, alias_norm, title_id, confidence) VALUES ('gb', 'metroid ii', 'title.metroid.2', 0.92);"
        ]

        for sql in statements {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw NSError(domain: "CoverMetadataTests", code: 2, userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(db))])
            }
        }
    }
}
