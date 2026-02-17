import XCTest
import CommonCrypto
@testable import AppHost

final class SaveStateStorageTests: XCTestCase {

    var storage: SaveStateStorage!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()

        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)

        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        storage = SaveStateStorage(baseURL: tempDirectory)
    }

    override func tearDown() {
        storage = nil
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }

    func testSaveStateMetadataInitialization() {
        let metadata = SaveStateMetadata(
            stateId: UUID(),
            romHash: "abc123",
            platform: .NES,
            timestamp: Date(),
            screenshotPath: "screenshot.png",
            fileSize: 1024,
            checksum: "xyz789"
        )

        XCTAssertEqual(metadata.romHash, "abc123")
        XCTAssertEqual(metadata.platform, .NES)
        XCTAssertEqual(metadata.fileSize, 1024)
    }

    func testSaveStateMetadataCodable() {
        let originalMetadata = SaveStateMetadata(
            stateId: UUID(),
            romHash: "test_hash_123",
            platform: .GBA,
            timestamp: Date(),
            screenshotPath: "test.png",
            fileSize: 2048,
            checksum: "checksum_456"
        )

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(originalMetadata),
              let decodedMetadata = try? JSONDecoder().decode(SaveStateMetadata.self, from: data) else {
            XCTFail("Encoding/decoding failed")
            return
        }

        XCTAssertEqual(originalMetadata.stateId, decodedMetadata.stateId)
        XCTAssertEqual(originalMetadata.romHash, decodedMetadata.romHash)
        XCTAssertEqual(originalMetadata.platform, decodedMetadata.platform)
        XCTAssertEqual(originalMetadata.checksum, decodedMetadata.checksum)
    }

    func testCreateSaveState() throws {
        let romHash = "test_rom_hash"
        let platform: Platform = .NES
        let stateData = Data("save_state_data".utf8)
        let screenshot = Data("screenshot_data".utf8)

        let metadata = try storage.createSaveState(
            romHash: romHash,
            platform: platform,
            stateData: stateData,
            screenshot: screenshot
        )

        XCTAssertNotNil(metadata.stateId)
        XCTAssertEqual(metadata.romHash, romHash)
        XCTAssertEqual(metadata.platform, platform)
        XCTAssertEqual(metadata.fileSize, stateData.count)
    }

    func testLoadSaveState() throws {
        let romHash = "test_load_hash"
        let platform: Platform = .GBA
        let stateData = Data("original_state".utf8)
        let screenshot = Data("original_screenshot".utf8)

        let createdMetadata = try storage.createSaveState(
            romHash: romHash,
            platform: platform,
            stateData: stateData,
            screenshot: screenshot
        )

        let loadedState = try storage.loadSaveState(stateId: createdMetadata.stateId)

        XCTAssertEqual(loadedState.metadata.stateId, createdMetadata.stateId)
        XCTAssertEqual(loadedState.data, stateData)
        XCTAssertEqual(loadedState.metadata.romHash, romHash)
    }

    func testLoadSaveStateInvalidId() {
        XCTAssertThrowsError(
            try storage.loadSaveState(stateId: UUID())
        ) { error in
            XCTAssertEqual(error as? SaveStateError, .notFound)
        }
    }

    func testListSaveStates() throws {
        let romHash = "test_list_hash"
        let platform: Platform = .NES

        _ = try storage.createSaveState(
            romHash: romHash,
            platform: platform,
            stateData: Data("state1".utf8),
            screenshot: Data("screenshot1".utf8)
        )

        _ = try storage.createSaveState(
            romHash: romHash,
            platform: platform,
            stateData: Data("state2".utf8),
            screenshot: Data("screenshot2".utf8)
        )

        _ = try storage.createSaveState(
            romHash: "other_hash",
            platform: platform,
            stateData: Data("state3".utf8),
            screenshot: Data("screenshot3".utf8)
        )

        let states = try storage.listSaveStates(forRomHash: romHash)

        XCTAssertEqual(states.count, 2)
        XCTAssertTrue(states.allSatisfy { $0.romHash == romHash })
    }

    func testListSaveStatesEmpty() throws {
        let states = try storage.listSaveStates(forRomHash: "nonexistent_hash")
        XCTAssertEqual(states.count, 0)
    }

    func testDeleteSaveState() throws {
        let romHash = "test_delete_hash"
        let platform: Platform = .GBA

        let createdMetadata = try storage.createSaveState(
            romHash: romHash,
            platform: platform,
            stateData: Data("delete_me".utf8),
            screenshot: Data("delete_screenshot".utf8)
        )

        try storage.deleteSaveState(stateId: createdMetadata.stateId)

        XCTAssertThrowsError(
            try storage.loadSaveState(stateId: createdMetadata.stateId)
        ) { error in
            XCTAssertEqual(error as? SaveStateError, .notFound)
        }
    }

    func testDeleteSaveStateInvalidId() {
        XCTAssertThrowsError(
            try storage.deleteSaveState(stateId: UUID())
        ) { error in
            XCTAssertEqual(error as? SaveStateError, .notFound)
        }
    }

    func testSaveStateChecksumValidation() throws {
        let romHash = "test_checksum_hash"
        let platform: Platform = .NES
        let stateData = Data("checksum_test".utf8)
        let screenshot = Data("screenshot".utf8)

        let createdMetadata = try storage.createSaveState(
            romHash: romHash,
            platform: platform,
            stateData: stateData,
            screenshot: screenshot
        )

        let loadedState = try storage.loadSaveState(stateId: createdMetadata.stateId)

        let expectedChecksum = stateData.md5()
        XCTAssertEqual(loadedState.metadata.checksum, expectedChecksum)
    }

    func testMultiplePlatformsSaveStates() throws {
        let romHash = "test_multi_hash"

        _ = try storage.createSaveState(
            romHash: romHash,
            platform: .NES,
            stateData: Data("nes_state".utf8),
            screenshot: Data("nes_ss".utf8)
        )

        _ = try storage.createSaveState(
            romHash: romHash,
            platform: .GBA,
            stateData: Data("gba_state".utf8),
            screenshot: Data("gba_ss".utf8)
        )

        _ = try storage.createSaveState(
            romHash: romHash,
            platform: .PS1,
            stateData: Data("ps1_state".utf8),
            screenshot: Data("ps1_ss".utf8)
        )

        let allStates = try storage.listSaveStates(forRomHash: romHash)
        XCTAssertEqual(allStates.count, 3)

        let nesStates = allStates.filter { $0.platform == .NES }
        let gbaStates = allStates.filter { $0.platform == .GBA }
        let ps1States = allStates.filter { $0.platform == .PS1 }

        XCTAssertEqual(nesStates.count, 1)
        XCTAssertEqual(gbaStates.count, 1)
        XCTAssertEqual(ps1States.count, 1)
    }

    func testSaveStateFileCreation() throws {
        let romHash = "test_file_hash"
        let platform: Platform = .NES
        let stateData = Data("file_test".utf8)
        let screenshot = Data("screenshot_test".utf8)

        let metadata = try storage.createSaveState(
            romHash: romHash,
            platform: platform,
            stateData: stateData,
            screenshot: screenshot
        )

        let stateFileURL = tempDirectory
            .appendingPathComponent("states")
            .appendingPathComponent(metadata.stateId.uuidString + ".sav")

        let screenshotFileURL = tempDirectory
            .appendingPathComponent("screenshots")
            .appendingPathComponent(metadata.stateId.uuidString + ".png")

        XCTAssertTrue(FileManager.default.fileExists(atPath: stateFileURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: screenshotFileURL.path))
    }

    func testSaveStateMetadataEquality() {
        let metadata1 = SaveStateMetadata(
            stateId: UUID(),
            romHash: "hash1",
            platform: .NES,
            timestamp: Date(),
            screenshotPath: "path1",
            fileSize: 100,
            checksum: "check1"
        )

        let metadata2 = SaveStateMetadata(
            stateId: metadata1.stateId,
            romHash: "hash1",
            platform: .NES,
            timestamp: metadata1.timestamp,
            screenshotPath: "path1",
            fileSize: 100,
            checksum: "check1"
        )

        let metadata3 = SaveStateMetadata(
            stateId: UUID(),
            romHash: "hash2",
            platform: .GBA,
            timestamp: Date(),
            screenshotPath: "path2",
            fileSize: 200,
            checksum: "check2"
        )

        XCTAssertEqual(metadata1, metadata2)
        XCTAssertNotEqual(metadata1, metadata3)
    }

    func testLargeSaveState() throws {
        let romHash = "test_large_hash"
        let platform: Platform = .PS2

        let largeData = Data(repeating: 0xFF, count: 10_000_000)

        let screenshot = Data("screenshot".utf8)

        let metadata = try storage.createSaveState(
            romHash: romHash,
            platform: platform,
            stateData: largeData,
            screenshot: screenshot
        )

        XCTAssertEqual(metadata.fileSize, largeData.count)

        let loadedState = try storage.loadSaveState(stateId: metadata.stateId)
        XCTAssertEqual(loadedState.data, largeData)
    }

    func testGetSaveStateCount() throws {
        let romHash = "test_count_hash"
        let platform: Platform = .NES

        let countBefore = try storage.getSaveStateCount(forRomHash: romHash)
        XCTAssertEqual(countBefore, 0)

        _ = try storage.createSaveState(
            romHash: romHash,
            platform: platform,
            stateData: Data("state1".utf8),
            screenshot: Data("ss1".utf8)
        )

        _ = try storage.createSaveState(
            romHash: romHash,
            platform: platform,
            stateData: Data("state2".utf8),
            screenshot: Data("ss2".utf8)
        )

        let countAfter = try storage.getSaveStateCount(forRomHash: romHash)
        XCTAssertEqual(countAfter, 2)
    }
}

extension Data {
    func md5() -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))

        _ = self.withUnsafeBytes { (body: UnsafeRawBufferPointer) in
            CC_MD5(body.baseAddress, CC_LONG(self.count), &digest)
        }

        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
