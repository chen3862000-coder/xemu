import Foundation
import MetalKit

protocol EmulatorCoreProtocol {
    func loadROM(at url: URL) throws
    func startEmulation(on view: MTKView)
    func pauseEmulation()
    func stopEmulation()
    func saveState(at slot: Int) throws
    func loadState(from slot: Int) throws
    func processFrame() -> Int
}

enum CoreError: Error {
    case coreNotLoaded
    case coreInitializationFailed
    case romLoadFailed
    case saveStateFailed
    case loadStateFailed
}

final class StableSystemsCoordinator {
    static let shared = StableSystemsCoordinator()

    private var activeCore: EmulatorCoreProtocol?
    private let inputBus: InputRouting
    private let saveStateStorage: SaveStateStorage

    init(inputBus: InputRouting = InputBus.shared, saveStateStorage: SaveStateStorage = .init()) {
        self.inputBus = inputBus
        self.saveStateStorage = saveStateStorage
    }

    func loadCore(for platform: Platform) throws {
        guard let core = CoreFactory.shared.createCore(for: platform) else {
            throw CoreError.coreInitializationFailed
        }

        activeCore = core
    }

    func loadROM(at url: URL) throws {
        guard let core = activeCore else {
            throw CoreError.coreNotLoaded
        }

        try core.loadROM(at: url)
    }

    func startEmulation(on view: MTKView) {
        guard let core = activeCore else { return }

        core.startEmulation(on: view)
        setupInputHandling(for: core)
    }

    func pauseEmulation() {
        activeCore?.pauseEmulation()
    }

    func stopEmulation() {
        activeCore?.stopEmulation()
        activeCore = nil
    }

    func saveCurrentState(at slot: Int) throws {
        guard let core = activeCore else {
            throw CoreError.coreNotLoaded
        }

        try core.saveState(at: slot)
    }

    func loadState(from slot: Int) throws {
        guard let core = activeCore else {
            throw CoreError.coreNotLoaded
        }

        try core.loadState(from: slot)
    }

    func getCurrentCore() -> EmulatorCoreProtocol? {
        return activeCore
    }

    private func setupInputHandling(for core: EmulatorCoreProtocol) {
        inputBus.addListener { [weak self] event in
            guard let self = self, let core = self.activeCore else { return }
            self.handleInput(event, for: core)
        }
    }

    private func handleInput(_ event: InputEvent, for core: EmulatorCoreProtocol) {
        switch event.button {
        case .a: core.input(.buttonA, pressed: event.isPressed)
        case .b: core.input(.buttonB, pressed: event.isPressed)
        case .x: core.input(.buttonX, pressed: event.isPressed)
        case .y: core.input(.buttonY, pressed: event.isPressed)
        case .l: core.input(.buttonL, pressed: event.isPressed)
        case .r: core.input(.buttonR, pressed: event.isPressed)
        case .dpadUp: core.input(.dpadUp, pressed: event.isPressed)
        case .dpadDown: core.input(.dpadDown, pressed: event.isPressed)
        case .dpadLeft: core.input(.dpadLeft, pressed: event.isPressed)
        case .dpadRight: core.input(.dpadRight, pressed: event.isPressed)
        case .start: core.input(.start, pressed: event.isPressed)
        case .select: core.input(.select, pressed: event.isPressed)
        case .menu, .triggerLeft, .triggerRight:
            break
        }
    }
}

extension EmulatorCoreProtocol {
    func input(_ button: CoreButton, pressed: Bool) {
    }
}

enum CoreButton {
    case buttonA
    case buttonB
    case buttonX
    case buttonY
    case buttonL
    case buttonR
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case start
    case select
}

final class CoreFactory {
    static let shared = CoreFactory()

    private init() {}

    func createCore(for platform: Platform) -> EmulatorCoreProtocol? {
        switch platform {
        case .nes:
            return NESCore()
        case .gba:
            return GBACore()
        case .gb:
            return GBCore()
        case .genesis:
            return GenesisCore()
        case .nds:
            return NDSCore()
        case .ps1:
            return PS1Core()
        case .ps2, .threeDS:
            return nil
        }
    }
}

final class NESCore: EmulatorCoreProtocol {
    private var isRunning = false

    func loadROM(at url: URL) throws {
    }

    func startEmulation(on view: MTKView) {
        isRunning = true
    }

    func pauseEmulation() {
        isRunning = false
    }

    func stopEmulation() {
        isRunning = false
    }

    func saveState(at slot: Int) throws {
    }

    func loadState(from slot: Int) throws {
    }

    func processFrame() -> Int {
        return 60
    }
}

final class GBACore: EmulatorCoreProtocol {
    private var isRunning = false

    func loadROM(at url: URL) throws {
    }

    func startEmulation(on view: MTKView) {
        isRunning = true
    }

    func pauseEmulation() {
        isRunning = false
    }

    func stopEmulation() {
        isRunning = false
    }

    func saveState(at slot: Int) throws {
    }

    func loadState(from slot: Int) throws {
    }

    func processFrame() -> Int {
        return 60
    }
}

final class GBCore: EmulatorCoreProtocol {
    private var isRunning = false

    func loadROM(at url: URL) throws {
    }

    func startEmulation(on view: MTKView) {
        isRunning = true
    }

    func pauseEmulation() {
        isRunning = false
    }

    func stopEmulation() {
        isRunning = false
    }

    func saveState(at slot: Int) throws {
    }

    func loadState(from slot: Int) throws {
    }

    func processFrame() -> Int {
        return 60
    }
}

final class GenesisCore: EmulatorCoreProtocol {
    private var isRunning = false

    func loadROM(at url: URL) throws {
    }

    func startEmulation(on view: MTKView) {
        isRunning = true
    }

    func pauseEmulation() {
        isRunning = false
    }

    func stopEmulation() {
        isRunning = false
    }

    func saveState(at slot: Int) throws {
    }

    func loadState(from slot: Int) throws {
    }

    func processFrame() -> Int {
        return 60
    }
}

final class NDSCore: EmulatorCoreProtocol {
    private var isRunning = false

    func loadROM(at url: URL) throws {
    }

    func startEmulation(on view: MTKView) {
        isRunning = true
    }

    func pauseEmulation() {
        isRunning = false
    }

    func stopEmulation() {
        isRunning = false
    }

    func saveState(at slot: Int) throws {
    }

    func loadState(from slot: Int) throws {
    }

    func processFrame() -> Int {
        return 60
    }
}

final class PS1Core: EmulatorCoreProtocol {
    private var isRunning = false

    func loadROM(at url: URL) throws {
    }

    func startEmulation(on view: MTKView) {
        isRunning = true
    }

    func pauseEmulation() {
        isRunning = false
    }

    func stopEmulation() {
        isRunning = false
    }

    func saveState(at slot: Int) throws {
    }

    func loadState(from slot: Int) throws {
    }

    func processFrame() -> Int {
        return 60
    }
}
