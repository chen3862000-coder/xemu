import XCTest
import MetalKit
@testable import Xemu

@MainActor
final class StableSystemsCoordinatorTests: XCTestCase {

    private var coordinator: StableSystemsCoordinator!
    private var inputBus: MockInputRouting!
    private var core: MockCoordinatorCore!
    private var tempDirectory: URL!
    private var saveStateStorage: SaveStateStorage!

    override func setUp() {
        super.setUp()

        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        inputBus = MockInputRouting()
        core = MockCoordinatorCore()
        saveStateStorage = SaveStateStorage(directory: tempDirectory)
        coordinator = StableSystemsCoordinator(
            inputBus: inputBus,
            saveStateStorage: saveStateStorage,
            coreFactory: { [unowned self] _ in self.core }
        )
    }

    override func tearDown() {
        coordinator = nil
        inputBus = nil
        core = nil
        saveStateStorage = nil
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

    func testSaveAndLoadStateRoundTripsThroughStorage() throws {
        let romURL = tempDirectory.appendingPathComponent("testrom.gba")
        try Data("rom".utf8).write(to: romURL)
        core.saveStateData = Data("save-payload".utf8)

        try coordinator.loadCore(for: .GBA)
        try coordinator.loadROM(at: romURL)
        try coordinator.saveCurrentState(at: 2)

        core.loadStateCallCount = 0
        core.lastLoadedState = nil

        try coordinator.loadState(from: 2)

        XCTAssertEqual(core.loadStateCallCount, 1)
        XCTAssertEqual(core.lastLoadedState, Data("save-payload".utf8))
    }

    func testStartEmulationRoutesInputToCore() async throws {
        try coordinator.loadCore(for: .GBA)
        coordinator.startEmulation(on: MTKView())

        inputBus.send(InputEvent(button: .a, isPressed: true, timestamp: Date()))
        await Task.yield()

        XCTAssertEqual(core.lastInputType, 0)
        XCTAssertEqual(core.lastInputValue, 1.0)
    }
}

private final class MockCoordinatorCore: EmulatorCore {
    let platform: Platform = .GBA
    var saveStateData = Data()
    var lastLoadedState: Data?
    var loadStateCallCount = 0
    var lastInputType: Int?
    var lastInputValue: Float?

    func initialize() -> Bool { true }
    func loadROM(romPath: String) -> Bool { true }
    func frame() -> Bool { true }
    func saveState() -> Data? { saveStateData }
    func loadState(_ state: Data) -> Bool {
        loadStateCallCount += 1
        lastLoadedState = state
        return true
    }
    func setInput(_ inputType: Int, value: Float) {
        lastInputType = inputType
        lastInputValue = value
    }
}

private final class MockInputRouting: @unchecked Sendable, InputRouting {
    private var listener: (@Sendable (InputEvent) -> Void)?
    private let lock = NSLock()

    nonisolated func route(_ event: InputEvent) {}

    nonisolated func addListener(_ listener: @escaping @Sendable (InputEvent) -> Void) -> UUID {
        lock.lock()
        self.listener = listener
        lock.unlock()
        return UUID()
    }

    func send(_ event: InputEvent) {
        lock.lock()
        let listener = self.listener
        lock.unlock()
        listener?(event)
    }
}
