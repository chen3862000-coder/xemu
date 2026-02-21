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

        do {
            if let data = try core.saveState() {
                // TODO: Implement saveStateStorage.save when SaveStateStorage API is ready
                // try saveStateStorage.save(data: data, for: url, slot: slot)
            }
        } catch {
            throw CoreError.saveStateFailed
        }
    }

    func loadState(from slot: Int) throws {
        guard let core = activeCore else {
            throw CoreError.coreNotLoaded
        }

        do {
            // TODO: Implement saveStateStorage.load when SaveStateStorage API is ready
            // let data = try saveStateStorage.load(for: url, slot: slot)
            // try core.loadState(from: data)
        } catch {
            throw CoreError.loadStateFailed
        }
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

    private var url: URL {
        URL(fileURLWithPath: "")
    }

    private func setupInputHandling(for core: any EmulatorCore) {
        inputBus.addListener { [weak self] event in
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
