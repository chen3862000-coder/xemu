import Foundation
import MetalKit
import Combine
import GameController

@MainActor
class GamePlayViewModel: ObservableObject {
    private static let minimumTouchPressDurationNs: UInt64 = 200_000_000
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var showTouchOverlay = true
    @Published var statusMessage = ""
    @Published var currentFPS = 0

    private var emulatorSession: EmulatorSession?
    private(set) var metalRenderer: MetalRenderer?
    private var audioEngine: AudioEngine?
    private var inputBus: InputBus?
    private var activeCore: EmulatorCore?
    private var pendingReleaseTasks: [EmulatorButton: Task<Void, Never>] = [:]
    
    private var frameWidth = 160
    private var frameHeight = 144
    private var lastFPSTime: Double = 0
    private var isStoppingEmulation = false
    
    var tick: (() -> Void)? {
        { [weak self] in
            guard let self, !self.isStoppingEmulation else { return }
            self.emulatorSession?.stepOnce()
        }
    }

    var metalDevice: MTLDevice? {
        metalRenderer?.metalDevice
    }
    
    var renderer: MetalRenderer? {
        metalRenderer
    }

    var targetFrameTime: Double {
        1.0 / 60.0
    }

    func startEmulation(romPath: String, platform: Platform) {
        if emulatorSession != nil || metalRenderer != nil || isRunning {
            stopEmulation()
        }

        do {
            let core = try EmulatorCoreFactory.createCore(for: platform)
            activeCore = core
            
            switch platform {
            case .GB, .GBC:
                frameWidth = 160
                frameHeight = 144
            case .GBA:
                frameWidth = 240
                frameHeight = 160
            default:
                frameWidth = 160
                frameHeight = 144
            }
            
            let success = core.loadROM(romPath: romPath)
            guard success else {
                statusMessage = "Failed to load ROM"
                return
            }

            emulatorSession = EmulatorSession()
            emulatorSession?.loadCore(core)
            emulatorSession?.renderDelegate = self
            
            inputBus = InputBus.shared
            inputBus?.setTarget(core)
            inputBus?.setPlatform(platform)

            let textureSize: CGSize
            switch platform {
            case .GB, .GBC:
                textureSize = CGSize(width: 160, height: 144)
            case .GBA:
                textureSize = CGSize(width: 240, height: 160)
            default:
                textureSize = CGSize(width: 160, height: 144)
            }
            metalRenderer = MetalRenderer(textureSize: textureSize)
            switch platform {
            case .GBC:
                metalRenderer?.setColorAdjustments(
                    brightness: 1.58,
                    gamma: 1.42,
                    contrast: 1.03,
                    saturation: 1.04
                )
            case .GB:
                metalRenderer?.setColorAdjustments(
                    brightness: 1.08,
                    gamma: 0.95,
                    contrast: 1.02,
                    saturation: 1.0
                )
            default:
                metalRenderer?.setColorAdjustments()
            }

            audioEngine = AudioEngine()
            audioEngine?.configureAudioSession()

            emulatorSession?.start()

            isRunning = true
            isPaused = false
            statusMessage = ""
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    func stopEmulation() {
        if isStoppingEmulation {
            return
        }

        guard emulatorSession != nil || metalRenderer != nil || audioEngine != nil || isRunning else {
            return
        }

        isStoppingEmulation = true
        defer { isStoppingEmulation = false }

        autoreleasepool {
            cancelPendingTouchReleases()
            releaseAllTouchButtons()

            inputBus?.clearTarget()

            emulatorSession?.renderDelegate = nil
            emulatorSession?.stop()
            emulatorSession?.cleanup()

            audioEngine?.stop()
            audioEngine?.deactivateAudioSession()

            metalRenderer?.cleanup()

            emulatorSession = nil
            metalRenderer = nil
            audioEngine = nil
            inputBus = nil
            activeCore = nil
        }
        
        isRunning = false
        isPaused = false
    }

    func pauseEmulation() {
        guard !isPaused else { return }
        emulatorSession?.pause()
        audioEngine?.pause()
        isPaused = true
        statusMessage = "Paused"
    }

    func resumeEmulation() {
        guard isPaused else { return }
        emulatorSession?.resume()
        audioEngine?.resume()
        isPaused = false
        statusMessage = ""
    }

    func quickSave() {
        guard let session = emulatorSession else {
            statusMessage = "No active session"
            return
        }
        
        Task {
            do {
                let data = try await session.saveState(to: 0)
                let metadata = SaveStateMetadata(
                    slot: 0,
                    romHash: "",
                    platform: "",
                    createdAt: Date(),
                    gameTitle: "",
                    emulatorVersion: "1.0",
                    screenshotData: nil
                )
                try await SaveStateStorage.shared.persist(data: data, metadata: metadata, screenshotData: nil)
                statusMessage = "State saved"
            } catch {
                statusMessage = "Save failed: \(error.localizedDescription)"
            }
        }
    }

    func quickLoad() {
        guard let session = emulatorSession else {
            statusMessage = "No active session"
            return
        }
        
        Task {
            do {
                let (data, _, _) = try SaveStateStorage.shared.load(slot: 0)
                try session.loadState(from: data)
                statusMessage = "State loaded"
            } catch {
                statusMessage = "Load failed: \(error.localizedDescription)"
            }
        }
    }

    func saveState(slot: Int) {
        guard let session = emulatorSession else {
            statusMessage = "No active session"
            return
        }
        
        Task {
            do {
                let data = try await session.saveState(to: slot)
                let metadata = SaveStateMetadata(
                    slot: slot,
                    romHash: "",
                    platform: "",
                    createdAt: Date(),
                    gameTitle: "",
                    emulatorVersion: "1.0",
                    screenshotData: nil
                )
                try await SaveStateStorage.shared.persist(data: data, metadata: metadata, screenshotData: nil)
                self.statusMessage = "State saved to slot \(slot)"
            } catch {
                statusMessage = "Save failed: \(error.localizedDescription)"
            }
        }
    }

    func loadState(slot: Int) {
        guard let session = emulatorSession else {
            statusMessage = "No active session"
            return
        }
        
        Task {
            do {
                let (data, _, _) = try SaveStateStorage.shared.load(slot: slot)
                try session.loadState(from: data)
                statusMessage = "State loaded from slot \(slot)"
            } catch {
                statusMessage = "Load failed: \(error.localizedDescription)"
            }
        }
    }

    func handleButtonPress(_ button: EmulatorButton, pressed: Bool) {
        if pressed {
            pendingReleaseTasks[button]?.cancel()
            pendingReleaseTasks[button] = nil
            sendTouchInput(button, pressed: true)
            return
        }

        pendingReleaseTasks[button]?.cancel()
        pendingReleaseTasks[button] = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.minimumTouchPressDurationNs)
            guard let self, !Task.isCancelled else { return }
            self.sendTouchInput(button, pressed: false)
            self.pendingReleaseTasks[button] = nil
        }
    }

    private func sendTouchInput(_ button: EmulatorButton, pressed: Bool) {
        guard let core = activeCore else {
            NSLog("[InputTrace] drop button=\(button) pressed=\(pressed) reason=no-active-core")
            return
        }
        let inputType = mapTouchButtonToInputType(button)
        guard inputType >= 0 else {
            NSLog("[InputTrace] drop button=\(button) pressed=\(pressed) reason=unmapped")
            return
        }
        NSLog("[InputTrace] touch button=\(button) pressed=\(pressed) inputType=\(inputType) core=\(String(describing: type(of: core)))")
        core.setInput(inputType, value: pressed ? 1.0 : 0.0)
    }

    private func cancelPendingTouchReleases() {
        for (_, task) in pendingReleaseTasks {
            task.cancel()
        }
        pendingReleaseTasks.removeAll()
    }

    private func releaseAllTouchButtons() {
        guard let core = activeCore else { return }
        let buttonsToRelease: [EmulatorButton] = [
            .a, .b, .x, .y,
            .l1, .l2, .r1, .r2,
            .start, .select,
            .menu,
            .dpadUp, .dpadDown, .dpadLeft, .dpadRight
        ]

        for button in buttonsToRelease {
            let inputType = mapTouchButtonToInputType(button)
            if inputType >= 0 {
                core.setInput(inputType, value: 0.0)
            }
        }
    }

    private func mapTouchButtonToInputType(_ button: EmulatorButton) -> Int {
        switch button {
        case .a: return 0
        case .b: return 1
        case .x: return 2
        case .y: return 3
        case .l1: return 4
        case .r1: return 5
        case .select: return 6
        case .start: return 7
        case .menu: return 8
        case .l2: return 9
        case .r2: return 10
        case .dpadUp: return 11
        case .dpadDown: return 12
        case .dpadLeft: return 13
        case .dpadRight: return 14
        case .screenshot: return -1
        }
    }

    private func mapButtonToInputType(_ button: EmulatorButton) -> ControllerButton {
        switch button {
        case .dpadUp: return .dpadUp
        case .dpadDown: return .dpadDown
        case .dpadLeft: return .dpadLeft
        case .dpadRight: return .dpadRight
        case .a: return .a
        case .b: return .b
        case .x: return .x
        case .y: return .y
        case .l1: return .leftShoulder
        case .l2: return .leftTrigger
        case .r1: return .rightShoulder
        case .r2: return .rightTrigger
        case .start: return .start
        case .select: return .select
        case .menu: return .menu
        case .screenshot: return .home
        }
    }

    func setFastForward(_ speed: Int) {
        // TODO: Implement fast forward by adjusting frame timing
        statusMessage = "Fast forward: \(speed)x"
    }

    func setupRenderer(mtkView: MTKView) {
        metalRenderer?.setupWithMTKView(mtkView)
    }
}

extension GamePlayViewModel: EmulatorRenderDelegate {
    func emulatorDidRenderFrameBufferInfo(_ frameBufferInfo: FrameBufferInfo) {
        autoreleasepool {
            let width = frameBufferInfo.width
            let height = frameBufferInfo.height
            let pitch = frameBufferInfo.pitch
            let data = frameBufferInfo.data
            
            // Final safety validation before upload
            let neededSize = pitch * height
            guard data.count >= neededSize, width > 0, height > 0, pitch > 0 else {
                return
            }
            
            metalRenderer?.enqueueFrame(data, width: width, height: height, bytesPerRow: pitch)
            
            let now = CACurrentMediaTime()
            if now - lastFPSTime > 0.5 {
                let fps = Int(emulatorSession?.currentFrameRate ?? 0)
                self.currentFPS = fps
                lastFPSTime = now
            }
        }
    }
    
    func emulatorDidGenerateAudio(samples: Data?) {
        autoreleasepool {
            guard let samples = samples, !samples.isEmpty else { return }
            audioEngine?.updateAudioBuffer(samples)
        }
    }
}
