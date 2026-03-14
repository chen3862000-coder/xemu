import Foundation
import MetalKit

enum CoreError: Error {
    case coreNotLoaded
    case coreInitializationFailed
    case romLoadFailed
    case saveStateFailed
    case loadStateFailed
}

@MainActor
final class StableSystemsCoordinator {
    private let inputBus: InputRouting
    private let saveStateStorage: SaveStateStorage
    private var activeCore: (any EmulatorCore)?

    init(inputBus: InputRouting, saveStateStorage: SaveStateStorage) {
        self.inputBus = inputBus
        self.saveStateStorage = saveStateStorage
    }

    func loadCore(for platform: Platform) throws {
        let core = createCore(for: platform)
        guard core != nil else {
            throw CoreError.coreInitializationFailed
        }
        activeCore = core
    }

    func loadROM(at url: URL) throws {
        guard let core = activeCore else {
            throw CoreError.coreNotLoaded
        }

        let loaded = core.loadROM(romPath: url.path)
        guard loaded else {
            throw CoreError.romLoadFailed
        }
    }

    func startEmulation(on view: MTKView) {
        guard let core = activeCore else { return }

        core.start()
        setupInputHandling(for: core)
    }

    func pauseEmulation() {
        activeCore?.pause()
    }

    func stopEmulation() {
        activeCore?.stop()
        activeCore = nil
    }

    func saveCurrentState(at slot: Int) throws {
        guard let core = activeCore else {
            throw CoreError.coreNotLoaded
        }

        guard core.saveState() != nil else {
            throw CoreError.saveStateFailed
        }

        // TODO: Persist state payload once StableSystemsCoordinator is wired to a ROM identity.
        _ = slot
    }

    func loadState(from slot: Int) throws {
        guard activeCore != nil else {
            throw CoreError.coreNotLoaded
        }

        // TODO: Load a previously persisted state once slot-to-ROM lookup exists here.
        _ = slot
    }

    func getCurrentCore() -> (any EmulatorCore)? {
        return activeCore
    }

    private func createCore(for platform: Platform) -> (any EmulatorCore)? {
        switch platform {
        case .NES: return NESCore()
        case .GB: return GBCore()
        case .GBA: return GBACore()
        case .GENESIS: return GenesisCore()
        case .NDS: return NDSCore()
        case .PS1: return PS1Core()
        default: return nil
        }
    }

    private func setupInputHandling(for core: any EmulatorCore) {
        _ = inputBus.addListener { [weak self] event in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self, let core = self.activeCore else { return }
                self.handleInput(event, for: core)
            }
        }
    }

    private func handleInput(_ event: InputEvent, for core: any EmulatorCore) {
    }
}
