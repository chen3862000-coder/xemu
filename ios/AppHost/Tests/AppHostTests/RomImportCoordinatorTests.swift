import XCTest
import Combine
@testable import Xemu

@MainActor
final class RomImportCoordinatorTests: XCTestCase {
    func testInit() {
        let controller = PersistenceController(inMemory: true)
        let coordinator = RomImportCoordinator(
            persistence: controller,
            romsDirectory: URL(fileURLWithPath: "/tmp/roms")
        )
        
        XCTAssertFalse(coordinator.isImporting)
        XCTAssertEqual(coordinator.importProgress, 0)
    }
    
    func testImportProgressPublished() {
        let controller = PersistenceController(inMemory: true)
        let coordinator = RomImportCoordinator(
            persistence: controller,
            romsDirectory: URL(fileURLWithPath: "/tmp/roms")
        )
        
        XCTAssertFalse(coordinator.isImporting)
        XCTAssertEqual(coordinator.importProgress, 0)
    }

    func testImportROMRejectsUnsupportedSystemWithFriendlyMessage() async throws {
        let controller = PersistenceController(inMemory: true)
        let romsDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let coordinator = RomImportCoordinator(
            persistence: controller,
            romsDirectory: romsDirectory
        )

        let url = try writeTempFile(data: makeNESROM(), ext: "nes")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: romsDirectory)
        }

        do {
            _ = try await coordinator.importROM(from: url)
            XCTFail("Expected unsupported ROM import to fail")
        } catch let error as RomImportCoordinator.ImportError {
            XCTAssertTrue((error.errorDescription ?? "").contains("GB, GBC, GBA, or NDS"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private func makeNESROM() -> Data {
        Data([0x4E, 0x45, 0x53, 0x1A] + Array(repeating: 0, count: 32))
    }

    private func writeTempFile(data: Data, ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try data.write(to: url, options: .atomic)
        return url
    }
}
