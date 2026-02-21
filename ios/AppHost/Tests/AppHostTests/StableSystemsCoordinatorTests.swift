import XCTest
import MetalKit
@testable import Xemu

@MainActor
final class StableSystemsCoordinatorTests: XCTestCase {

    var coordinator: StableSystemsCoordinator!
    var inputBus: InputBus!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()

        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        inputBus = InputBus.shared
        coordinator = StableSystemsCoordinator(
            inputBus: inputBus,
            saveStateStorage: SaveStateStorage(directory: tempDirectory)
        )
    }

    override func tearDown() {
        coordinator = nil
        inputBus = nil
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }

    func testInitialization() {
        XCTAssertNotNil(coordinator)
    }

    func testLoadCoreForNES() throws {
        try coordinator.loadCore(for: .NES)
    }

    func testLoadCoreForGBA() throws {
        try coordinator.loadCore(for: .GBA)
    }

    func testLoadCoreForPS1() throws {
        try coordinator.loadCore(for: .PS1)
    }
}
