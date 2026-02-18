import XCTest
@testable import AppHost

@MainActor
final class SaveStateStorageTests: XCTestCase {

    var storage: SaveStateStorage!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()

        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)

        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        storage = SaveStateStorage(directory: tempDirectory)
    }

    override func tearDown() {
        storage = nil
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }

    func testSaveStateMetadataInitialization() {
        let metadata = SaveStateMetadata(
            slot: 1,
            romHash: "abc123",
            platform: "NES",
            createdAt: Date(),
            gameTitle: "Test Game",
            emulatorVersion: "1.0.0"
        )

        XCTAssertEqual(metadata.romHash, "abc123")
        XCTAssertEqual(metadata.platform, "NES")
        XCTAssertEqual(metadata.slot, 1)
    }

    func testSaveStateMetadataCodable() throws {
        let originalMetadata = SaveStateMetadata(
            slot: 2,
            romHash: "test_hash_123",
            platform: "GBA",
            createdAt: Date(),
            gameTitle: "Test Game",
            emulatorVersion: "1.0.0"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(originalMetadata)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedMetadata = try decoder.decode(SaveStateMetadata.self, from: data)

        XCTAssertEqual(originalMetadata.slot, decodedMetadata.slot)
        XCTAssertEqual(originalMetadata.romHash, decodedMetadata.romHash)
        XCTAssertEqual(originalMetadata.platform, decodedMetadata.platform)
    }

    func testPersistAndLoad() throws {
        let metadata = SaveStateMetadata(
            slot: 1,
            romHash: "test_rom_hash",
            platform: "NES",
            createdAt: Date(),
            gameTitle: "Test Game",
            emulatorVersion: "1.0.0"
        )

        let stateData = Data("save_state_data".utf8)

        let expectation = XCTestExpectation(description: "Persist completes")
        
        storage.persist(data: stateData, metadata: metadata) { result in
            switch result {
            case .success(let url):
                XCTAssertNotNil(url)
            case .failure(let error):
                XCTFail("Persist failed: \(error)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        let loaded = try storage.load(slot: "1")
        XCTAssertEqual(loaded.0, stateData)
        XCTAssertEqual(loaded.1.romHash, "test_rom_hash")
    }

    func testLoadInvalidSlot() {
        XCTAssertThrowsError(try storage.load(slot: "999")) { error in
            XCTAssertTrue(error is SaveStateStorage.StorageError)
        }
    }

    func testList() throws {
        let metadata1 = SaveStateMetadata(
            slot: 1,
            romHash: "hash1",
            platform: "NES",
            createdAt: Date(),
            gameTitle: "Game 1",
            emulatorVersion: "1.0.0"
        )

        let metadata2 = SaveStateMetadata(
            slot: 2,
            romHash: "hash2",
            platform: "GBA",
            createdAt: Date(),
            gameTitle: "Game 2",
            emulatorVersion: "1.0.0"
        )

        let expectation = XCTestExpectation(description: "Persist completes")
        expectation.expectedFulfillmentCount = 2

        storage.persist(data: Data("data1".utf8), metadata: metadata1) { _ in
            expectation.fulfill()
        }
        storage.persist(data: Data("data2".utf8), metadata: metadata2) { _ in
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5.0)

        let list = try storage.list()
        XCTAssertEqual(list.count, 2)
    }

    func testListEmpty() throws {
        let list = try storage.list()
        XCTAssertEqual(list.count, 0)
    }
}
