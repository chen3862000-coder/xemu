import XCTest
import MetalKit
@testable import AppHost

final class StableSystemsCoordinatorTests: XCTestCase {

    var coordinator: StableSystemsCoordinator!
    var inputBus: InputBus!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()

        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        inputBus = InputBus()
        coordinator = StableSystemsCoordinator(
            inputBus: inputBus,
            saveStateStorage: SaveStateStorage(baseURL: tempDirectory)
        )
    }

    override func tearDown() {
        coordinator = nil
        inputBus = nil
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }

    func testLoadCoreForNES() {
        XCTAssertNoThrow(try coordinator.loadCore(for: .NES))
        XCTAssertNotNil(coordinator.activeCore)
    }

    func testLoadCoreForGBA() {
        XCTAssertNoThrow(try coordinator.loadCore(for: .GBA))
        XCTAssertNotNil(coordinator.activeCore)
    }

    func testLoadCoreForGB() {
        XCTAssertNoThrow(try coordinator.loadCore(for: .GB))
        XCTAssertNotNil(coordinator.activeCore)
    }

    func testLoadCoreForGenesis() {
        XCTAssertNoThrow(try coordinator.loadCore(for: .GENESIS))
        XCTAssertNotNil(coordinator.activeCore)
    }

    func testLoadCoreForNDS() {
        XCTAssertNoThrow(try coordinator.loadCore(for: .NDS))
        XCTAssertNotNil(coordinator.activeCore)
    }

    func testLoadCoreForPS1() {
        XCTAssertNoThrow(try coordinator.loadCore(for: .PS1))
        XCTAssertNotNil(coordinator.activeCore)
    }

    func testLoadCoreForUnsupportedPlatform() {
        XCTAssertThrowsError(try coordinator.loadCore(for: .PS2)) { error in
            XCTAssertEqual(error as? StableSystemsCoordinator.CoreError, .unsupportedPlatform)
        }
    }

    func testLoadCoreFor3DS() {
        XCTAssertNoThrow(try coordinator.loadCore(for: ._3DS))
        XCTAssertNotNil(coordinator.activeCore)
    }

    func testLoadROM() throws {
        try coordinator.loadCore(for: .NES)

        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try romData.write(to: romFile)

        XCTAssertNoThrow(try coordinator.loadROM(at: romFile))
    }

    func testLoadROMWithoutCore() {
        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try? romData.write(to: romFile)

        XCTAssertThrowsError(try coordinator.loadROM(at: romFile)) { error in
            XCTAssertEqual(error as? StableSystemsCoordinator.CoreError, .noCoreLoaded)
        }
    }

    func testLoadROMInvalidPath() throws {
        try coordinator.loadCore(for: .NES)

        let invalidFile = tempDirectory.appendingPathComponent("nonexistent.nes")

        XCTAssertNoThrow(try coordinator.loadROM(at: invalidFile))
    }

    func testStartEmulation() throws {
        try coordinator.loadCore(for: .NES)

        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try romData.write(to: romFile)
        try coordinator.loadROM(at: romFile)

        let device = MTLCreateSystemDefaultDevice()
        guard let device = device else {
            throw XCTSkip("Metal not supported")
        }

        let view = MTKView(frame: .zero, device: device)
        XCTAssertNoThrow(try coordinator.startEmulation(on: view))
    }

    func testStartEmulationWithoutROM() throws {
        try coordinator.loadCore(for: .NES)

        let device = MTLCreateSystemDefaultDevice()
        guard let device = device else {
            throw XCTSkip("Metal not supported")
        }

        let view = MTKView(frame: .zero, device: device)

        XCTAssertThrowsError(try coordinator.startEmulation(on: view)) { error in
            XCTAssertEqual(error as? StableSystemsCoordinator.CoreError, .noROMLoaded)
        }
    }

    func testPauseEmulation() throws {
        try coordinator.loadCore(for: .NES)

        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try romData.write(to: romFile)
        try coordinator.loadROM(at: romFile)

        XCTAssertNoThrow(coordinator.pauseEmulation())
    }

    func testStopEmulation() throws {
        try coordinator.loadCore(for: .NES)

        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try romData.write(to: romFile)
        try coordinator.loadROM(at: romFile)

        XCTAssertNoThrow(coordinator.stopEmulation())
    }

    func testCreateSaveState() throws {
        try coordinator.loadCore(for: .NES)

        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try romData.write(to: romFile)
        try coordinator.loadROM(at: romFile)

        let saveFile = tempDirectory.appendingPathComponent("save.json")
        let saveState = try coordinator.saveState(at: saveFile)
        XCTAssertNotNil(saveState)
    }

    func testLoadSaveState() throws {
        try coordinator.loadCore(for: .NES)

        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try romData.write(to: romFile)
        try coordinator.loadROM(at: romFile)

        let saveFile = tempDirectory.appendingPathComponent("save.json")
        let saveState = try coordinator.saveState(at: saveFile)
        XCTAssertNoThrow(try coordinator.loadState(from: saveState))
    }

    func testLoadSaveStateInvalidPath() throws {
        try coordinator.loadCore(for: .NES)

        let invalidSaveState = tempDirectory.appendingPathComponent("nonexistent.sav")

        XCTAssertNoThrow(try coordinator.loadState(from: invalidSaveState))
    }

    func testInputRouting() throws {
        try coordinator.loadCore(for: .NES)

        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try romData.write(to: romFile)
        try coordinator.loadROM(at: romFile)

        let device = MTLCreateSystemDefaultDevice()
        guard let device = device else {
            throw XCTSkip("Metal not supported")
        }

        let view = MTKView(frame: .zero, device: device)
        try coordinator.startEmulation(on: view)

        coordinator.setupInputHandling()

        let testEvent = InputEvent(type: .buttonA, player: 0, value: 1.0, timestamp: Date())
        inputBus.send(testEvent)

        XCTAssertNotNil(coordinator.activeCore)
    }

    func testCoreReplacement() throws {
        try coordinator.loadCore(for: .NES)
        let firstCore = coordinator.activeCore

        try coordinator.loadCore(for: .GBA)
        let secondCore = coordinator.activeCore

        XCTAssertNotEqual(firstCore?.platform, secondCore?.platform)
    }

    func testEmulationStateTransitions() throws {
        try coordinator.loadCore(for: .NES)

        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try romData.write(to: romFile)
        try coordinator.loadROM(at: romFile)

        let device = MTLCreateSystemDefaultDevice()
        guard let device = device else {
            throw XCTSkip("Metal not supported")
        }

        let view = MTKView(frame: .zero, device: device)

        try coordinator.startEmulation(on: view)
        coordinator.pauseEmulation()
        try coordinator.startEmulation(on: view)
        coordinator.stopEmulation()
    }

    func testFrameRateTarget() throws {
        try coordinator.loadCore(for: .NES)

        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try romData.write(to: romFile)
        try coordinator.loadROM(at: romFile)

        XCTAssertEqual(coordinator.targetFrameRate, 60)
    }

    func testAudioBufferSetup() throws {
        try coordinator.loadCore(for: .NES)

        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try romData.write(to: romFile)
        try coordinator.loadROM(at: romFile)

        let device = MTLCreateSystemDefaultDevice()
        guard let device = device else {
            throw XCTSkip("Metal not supported")
        }

        let view = MTKView(frame: .zero, device: device)
        try coordinator.startEmulation(on: view)

        XCTAssertNotNil(coordinator.audioBuffer)
    }

    func testSaveStateCompression() throws {
        try coordinator.loadCore(for: .NES)

        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try romData.write(to: romFile)
        try coordinator.loadROM(at: romFile)

        let saveFile = tempDirectory.appendingPathComponent("save.json")
        let saveState = try coordinator.saveState(at: saveFile)

        let attributes = try FileManager.default.attributesOfItem(atPath: saveState.path)
        let fileSize = attributes[.size] as? Int

        XCTAssertNotNil(fileSize)
        XCTAssertGreaterThan(fileSize!, 0)
    }

    func testResetEmulation() throws {
        try coordinator.loadCore(for: .NES)

        let romData = Data("test_rom_data".utf8)
        let romFile = tempDirectory.appendingPathComponent("test.nes")
        try romData.write(to: romFile)
        try coordinator.loadROM(at: romFile)

        XCTAssertNoThrow(coordinator.resetEmulation())
    }
}
