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
    private let coreFactory: (Platform) throws -> EmulatorCore
    private var activeCore: (any EmulatorCore)?
    private var currentPlatform: Platform?
    private var loadedROMURL: URL?
    private var inputListenerToken: UUID?

    init(
        inputBus: InputRouting,
        saveStateStorage: SaveStateStorage,
        coreFactory: @escaping (Platform) throws -> EmulatorCore = EmulatorCoreFactory.createCore(for:)
    ) {
        self.inputBus = inputBus
        self.saveStateStorage = saveStateStorage
        self.coreFactory = coreFactory
    }

    func loadCore(for platform: Platform) throws {
        let core = try coreFactory(platform)
        activeCore = core
        currentPlatform = platform
    }

    func loadROM(at url: URL) throws {
        guard let core = activeCore else {
            throw CoreError.coreNotLoaded
        }

        let loaded = core.loadROM(romPath: url.path)
        guard loaded else {
            throw CoreError.romLoadFailed
        }
        loadedROMURL = url
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
        activeCore?.cleanup()
        activeCore = nil
        loadedROMURL = nil
        currentPlatform = nil
    }

    func saveCurrentState(at slot: Int) throws {
        guard let core = activeCore else {
            throw CoreError.coreNotLoaded
        }

        guard let stateData = core.saveState() else {
            throw CoreError.saveStateFailed
        }

        let metadata = SaveStateMetadata(
            slot: slot,
            romHash: romHash,
            platform: currentPlatform?.rawValue ?? "",
            createdAt: Date(),
            gameTitle: gameTitle,
            emulatorVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            screenshotData: nil
        )

        do {
            try saveStateStorage.persistImmediately(data: stateData, metadata: metadata)
        } catch {
            throw CoreError.saveStateFailed
        }
    }

    func loadState(from slot: Int) throws {
        guard let core = activeCore else {
            throw CoreError.coreNotLoaded
        }

        do {
            let (data, _, _) = try saveStateStorage.load(slot: slot, romHash: romHash)
            guard core.loadState(data) else {
                throw CoreError.loadStateFailed
            }
        } catch let error as CoreError {
            throw error
        } catch {
            throw CoreError.loadStateFailed
        }
    }

    func getCurrentCore() -> (any EmulatorCore)? {
        return activeCore
    }

    private func setupInputHandling(for core: any EmulatorCore) {
        guard inputListenerToken == nil else { return }
        _ = inputBus.addListener { [weak self] event in
            guard let self = self else { return }
            Task { @MainActor [weak self] in
                guard let self = self, let core = self.activeCore else { return }
                self.handleInput(event, for: core)
            }
        }
        inputListenerToken = UUID()
    }

    private func handleInput(_ event: InputEvent, for core: any EmulatorCore) {
        let inputType = mapButtonToInputType(event.button)
        guard inputType >= 0 else { return }
        let value: Float = event.isPressed ? 1.0 : 0.0
        core.setInput(inputType, value: value)
    }

    private func mapButtonToInputType(_ button: ControllerButton) -> Int {
        switch button {
        case .a: return 0
        case .b: return 1
        case .x: return 2
        case .y: return 3
        case .l, .leftShoulder: return 4
        case .r, .rightShoulder: return 5
        case .select: return 6
        case .start: return 7
        case .menu, .home: return 8
        case .triggerLeft, .leftTrigger: return 9
        case .triggerRight, .rightTrigger: return 10
        case .dpadUp: return 11
        case .dpadDown: return 12
        case .dpadLeft: return 13
        case .dpadRight: return 14
        default: return -1
        }
    }

    private var romHash: String {
        guard let loadedROMURL else { return "" }
        return loadedROMURL.deletingPathExtension().lastPathComponent.lowercased()
    }

    private var gameTitle: String {
        loadedROMURL?.deletingPathExtension().lastPathComponent ?? "Unknown Game"
    }
}
