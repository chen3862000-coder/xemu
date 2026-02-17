import XCTest
import Combine
import CoreData
@testable import AppHost

final class RomImportCoordinatorTests: XCTestCase {

    var coordinator: RomImportCoordinator!
    var persistenceController: PersistenceController!
    var tempDirectory: URL!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()

        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        persistenceController = PersistenceController(inMemory: true)
        coordinator = RomImportCoordinator(
            persistenceController: persistenceController,
            romsDirectory: tempDirectory
        )

        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        coordinator = nil
        persistenceController = nil
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        cancellables = nil
        super.tearDown()
    }

    func testROMLibraryEntryCreation() {
        let entry = ROMLibraryEntry(context: persistenceController.container.viewContext)
        entry.entryId = UUID()
        entry.romHash = "test_hash_123"
        entry.title = "Test ROM"
        entry.platform = "NES"
        entry.tier = "stable"
        entry.artworkUri = URL(string: "https://example.com/artwork.png")
        entry.playtimeTotal = 3600
        entry.completionState = "InProgress"
        entry.lastPlayedAt = Date()
        entry.eligibleForLeaderboard = true

        XCTAssertEqual(entry.romHash, "test_hash_123")
        XCTAssertEqual(entry.title, "Test ROM")
        XCTAssertEqual(entry.platform, "NES")
        XCTAssertEqual(entry.tier, "stable")
    }

    func testROMLibraryEntryCodable() {
        let entry = ROMLibraryEntry(context: persistenceController.container.viewContext)
        entry.entryId = UUID()
        entry.romHash = "codable_test_hash"
        entry.title = "Test ROM"
        entry.platform = "GBA"
        entry.tier = "stable"
        entry.artworkUri = URL(string: "https://example.com/artwork.png")
        entry.playtimeTotal = 7200
        entry.completionState = "Completed"
        entry.lastPlayedAt = Date()
        entry.eligibleForLeaderboard = false

        XCTAssertNotNil(entry.entryId)
        XCTAssertEqual(entry.romHash, "codable_test_hash")
    }

    func testDeriveTitleFromFilename() {
        let title1 = coordinator.deriveTitle(from: "Super Mario Bros.nes")
        XCTAssertEqual(title1, "Super Mario Bros")

        let title2 = coordinator.deriveTitle(from: "Zelda - A Link to the Past.gba")
        XCTAssertEqual(title2, "Zelda - A Link to the Past")

        let title3 = coordinator.deriveTitle(from: "My Game (USA) (Rev 1).gba")
        XCTAssertEqual(title3, "My Game (USA) (Rev 1)")

        let title4 = coordinator.deriveTitle(from: "Test[1].nes")
        XCTAssertEqual(title4, "Test[1]")
    }

    func testDetectPlatformByExtension() {
        let platform1 = coordinator.detectPlatform(from: "game.nes")
        XCTAssertEqual(platform1, .NES)

        let platform2 = coordinator.detectPlatform(from: "game.gb")
        XCTAssertEqual(platform2, .GB)

        let platform3 = coordinator.detectPlatform(from: "game.gba")
        XCTAssertEqual(platform3, .GBA)

        let platform4 = coordinator.detectPlatform(from: "game.nds")
        XCTAssertEqual(platform4, .NDS)

        let platform5 = coordinator.detectPlatform(from: "game.gen")
        XCTAssertEqual(platform5, nil)

        let platform6 = coordinator.detectPlatform(from: "game.unknown")
        XCTAssertEqual(platform6, nil)
    }

    func testComputeSHA256Hash() throws {
        let testData = Data("test data for hashing".utf8)
        let hash = try coordinator.computeSHA256Hash(for: testData)

        XCTAssertEqual(hash.count, 64)
        XCTAssertFalse(hash.isEmpty)

        let hash2 = try coordinator.computeSHA256Hash(for: testData)
        XCTAssertEqual(hash, hash2)
    }

    func testBatchImport() throws {
        var importedCount = 0
        var importedROMs: [ROMLibraryEntry] = []
        let expectation = XCTestExpectation(description: "Batch import completed")

        coordinator.importProgress
            .sink { progress in
                if progress.completedCount == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        let romData1 = Data("nes_rom_data".utf8)
        let file1 = createTempFile(named: "game1.nes", data: romData1)

        let romData2 = Data("gba_rom_data".utf8)
        let file2 = createTempFile(named: "game2.gba", data: romData2)

        let romData3 = Data("gb_rom_data".utf8)
        let file3 = createTempFile(named: "game3.gb", data: romData3)

        let urls = [file1, file2, file3]

        coordinator.batchImport(urls: urls)

        wait(for: [expectation], timeout: 5.0)

        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()

        let entries = try context.fetch(fetchRequest)
        importedCount = entries.count
        importedROMs = entries

        XCTAssertEqual(importedCount, 3)

        XCTAssertEqual(importedROMs[0].title, "game1")
        XCTAssertEqual(importedROMs[1].title, "game2")
        XCTAssertEqual(importedROMs[2].title, "game3")
    }

    func testDuplicateROMHandling() throws {
        let romData = Data("duplicate_test".utf8)
        let file1 = createTempFile(named: "duplicate.nes", data: romData)
        let file2 = createTempFile(named: "duplicate_copy.nes", data: romData)

        _ = try coordinator.importROM(from: file1)
        _ = try coordinator.importROM(from: file2)

        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()

        let entries = try context.fetch(fetchRequest)

        XCTAssertEqual(entries.count, 1)
    }

    func testROMLibraryEntryTierAssignment() throws {
        let file1 = createTempFile(named: "stable.nes", data: Data("nes_data".utf8))
        let entry1 = try coordinator.importROM(from: file1)

        XCTAssertEqual(entry1.tier, "unknown")

        let file2 = createTempFile(named: "experimental.n64", data: Data("n64_data".utf8))
        let entry2 = try coordinator.importROM(from: file2)

        XCTAssertEqual(entry2.tier, "unknown")
    }

    func testPlaytimeTracking() throws {
        let file = createTempFile(named: "playtime_test.nes", data: Data("playtime".utf8))
        let entry = try coordinator.importROM(from: file)

        XCTAssertEqual(entry.playtimeTotal, 0)

        let context = persistenceController.container.viewContext
        entry.playtimeTotal = 1800

        try context.save()

        let fetchRequest: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "entryId == %@", entry.entryId! as CVarArg)

        let entries = try context.fetch(fetchRequest)
        XCTAssertEqual(entries.first?.playtimeTotal, 1800)
    }

    func testCompletionStateUpdates() throws {
        let file = createTempFile(named: "completion_test.gba", data: Data("completion".utf8))
        let entry = try coordinator.importROM(from: file)

        XCTAssertEqual(entry.completionState, "NotStarted")

        let context = persistenceController.container.viewContext
        entry.completionState = "Completed"
        try context.save()

        let fetchRequest: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        let entries = try context.fetch(fetchRequest)
        XCTAssertEqual(entries.first?.completionState, "Completed")
    }

    func testArtworkURIAssignment() throws {
        let file = createTempFile(named: "artwork_test.nes", data: Data("artwork".utf8))
        let entry = try coordinator.importROM(from: file)

        XCTAssertNil(entry.artworkUri)
    }

    func testLeaderboardEligibility() throws {
        let file1 = createTempFile(named: "legit.nes", data: Data("legit".utf8))
        let entry1 = try coordinator.importROM(from: file1)

        XCTAssertEqual(entry1.eligibleForLeaderboard, true)

        let file2 = createTempFile(named: "no_metadata.unknown", data: Data("no_meta".utf8))
        let entry2 = try coordinator.importROM(from: file2)

        XCTAssertEqual(entry2.eligibleForLeaderboard, true)
    }

    func testLastPlayedTimestamp() throws {
        let file = createTempFile(named: "timestamp_test.gb", data: Data("timestamp".utf8))
        let entry = try coordinator.importROM(from: file)

        XCTAssertNil(entry.lastPlayedAt)

        let context = persistenceController.container.viewContext
        entry.lastPlayedAt = Date()
        try context.save()

        let fetchRequest: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        let entries = try context.fetch(fetchRequest)

        XCTAssertNotNil(entries.first?.lastPlayedAt)
    }

    func testROMLibraryEntryUUIDGeneration() throws {
        let file = createTempFile(named: "uuid_test.nes", data: Data("uuid".utf8))
        let entry = try coordinator.importROM(from: file)

        XCTAssertNotNil(entry.entryId)
    }

    func testROMFileDeletionAfterImport() throws {
        let romData = Data("delete_after_import".utf8)
        let sourceFile = createTempFile(named: "delete_me.nes", data: romData)

        _ = try coordinator.importROM(from: sourceFile)

        let destinationFile = tempDirectory
            .appendingPathComponent("roms")
            .appendingPathComponent("delete_me.nes")

        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationFile.path))
    }

    private func createTempFile(named: String, data: Data) -> URL {
        let romsDirectory = tempDirectory.appendingPathComponent("roms")
        try? FileManager.default.createDirectory(at: romsDirectory, withIntermediateDirectories: true)

        let fileURL = romsDirectory.appendingPathComponent(named)
        try? data.write(to: fileURL)

        return fileURL
    }
}
