import Foundation
import MetalKit
import Combine
import GameController
import CoreData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(XemuCores)
import XemuCores
#endif

@MainActor
class GamePlayViewModel: ObservableObject {
    private static let minimumTouchPressDurationNs: UInt64 = 60_000_000
    private static let minimumDirectionalPressDurationNs: UInt64 = 28_000_000
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var showTouchOverlay = true
    @Published var statusMessage = ""
    @Published var currentFPS = 0
    @Published var saveStateDebugLine = ""

    private var emulatorSession: EmulatorSession?
    private(set) var metalRenderer: MetalRenderer?
    private var audioEngine: AudioEngine?
    private var inputBus: InputBus?
    private var activeCore: EmulatorCore?
    private var pendingReleaseTasks: [EmulatorButton: Task<Void, Never>] = [:]
    private var touchButtonStates: [EmulatorButton: Bool] = [:]
    private var currentROMHash: String = ""
    private var currentPlatform: Platform?
    private var currentGameTitle: String = ""
    private var sessionStartedAt: Date?
    private var lastFrameSnapshot: (data: Data, width: Int, height: Int, bytesPerRow: Int)?
    
    private var frameWidth = 160
    private var frameHeight = 144
    private var lastFPSTime: Double = 0
    private var lastNativeSavePersistTime: Double = 0
    private var isStoppingEmulation = false
    #if canImport(UIKit)
    private var lifecycleObservers: [NSObjectProtocol] = []
    #endif

    init() {
        #if canImport(UIKit)
        let center = NotificationCenter.default
        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.willResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.persistNativeSaveIfNeeded(force: true)
            }
        )
        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.persistNativeSaveIfNeeded(force: true)
            }
        )
        #endif
    }

    deinit {
        #if canImport(UIKit)
        let center = NotificationCenter.default
        for observer in lifecycleObservers {
            center.removeObserver(observer)
        }
        #endif
    }
    
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

    func startEmulation(romPath: String, platform: Platform, gameTitle: String? = nil, romHash: String? = nil) {
        if emulatorSession != nil || metalRenderer != nil || isRunning {
            stopEmulation()
        }

        do {
            let core = try EmulatorCoreFactory.createCore(for: platform)
            activeCore = core
            currentPlatform = platform
            currentGameTitle = gameTitle ?? ""
            currentROMHash = romHash ?? deriveROMHash(from: romPath)
            
            switch platform {
            case .GB, .GBC:
                frameWidth = 160
                frameHeight = 144
            case .GBA:
                frameWidth = 240
                frameHeight = 160
            case .NDS:
                frameWidth = 256
                frameHeight = 384
            default:
                frameWidth = 160
                frameHeight = 144
            }

            if platform == .NDS, let ndsCore = core as? NDSCore {
                _ = ndsCore.setScreenLayout(.stacked)
            }
            
            let success = core.loadROM(romPath: romPath)
            guard success else {
                statusMessage = "Failed to load ROM"
                return
            }
            restoreNativeSaveIfAvailable(for: core)

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
            case .NDS:
                textureSize = CGSize(width: 256, height: 384)
            default:
                textureSize = CGSize(width: 160, height: 144)
            }
            metalRenderer = MetalRenderer(textureSize: textureSize)
            let effectiveDisplayPlatform: Platform = {
                switch platform {
                case .GB, .GBC:
                    if let gbCore = core as? GBCore, gbCore.isCGBModeDetected {
                        return .GBC
                    } else {
                        return .GB
                    }
                default:
                    return platform
                }
            }()

            switch effectiveDisplayPlatform {
            case .GBC:
                metalRenderer?.setColorAdjustments(
                    brightness: 2.28,
                    gamma: 1.86,
                    contrast: 1.10,
                    saturation: 1.22
                )
            case .GB:
                metalRenderer?.setColorAdjustments()
            default:
                metalRenderer?.setColorAdjustments()
            }

            let audioSampleRate: Double
            switch platform {
            case .GB, .GBC:
                audioSampleRate = 65536
            case .GBA:
                audioSampleRate = 32768
            default:
                audioSampleRate = 44100
            }

            audioEngine = AudioEngine(sampleRate: audioSampleRate)
            audioEngine?.configureAudioSession()
            try? audioEngine?.start()
            audioEngine?.setVolume(1.0)

            emulatorSession?.start()
            refreshSaveStateDebugLine()
            sessionStartedAt = Date()

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
            persistPlayedTimeIfNeeded()
            persistNativeSaveIfNeeded(force: true)
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
            currentPlatform = nil
            currentROMHash = ""
            currentGameTitle = ""
            sessionStartedAt = nil
            lastFrameSnapshot = nil
        }
        
        isRunning = false
        isPaused = false
    }

    func pauseEmulation() {
        guard !isPaused else { return }
        emulatorSession?.pause()
        audioEngine?.pause()
        persistNativeSaveIfNeeded(force: true)
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
        guard !currentROMHash.isEmpty else {
            statusMessage = "Save failed: missing ROM hash"
            return
        }
        
        Task {
            do {
                let data = try session.saveState(to: 0)
                let metadata = makeMetadata(slot: 0)
                try await SaveStateStorage.shared.persist(data: data, metadata: metadata, screenshotData: makeSaveStateScreenshotData())
                let (verifyData, _, _) = try SaveStateStorage.shared.load(slot: 0, romHash: currentROMHash)
                statusMessage = "State saved (\(verifyData.count) bytes)"
                refreshSaveStateDebugLine()
            } catch {
                NSLog("[QuickSave] failed: %@", error.localizedDescription)
                statusMessage = "Save failed: \(detailedErrorMessage(error))"
            }
        }
    }

    func quickLoad() {
        guard let session = emulatorSession else {
            statusMessage = "No active session"
            return
        }
        guard !currentROMHash.isEmpty else {
            statusMessage = "Load failed: missing ROM hash"
            return
        }
        
        Task {
            do {
                let (data, _, _) = try SaveStateStorage.shared.load(slot: 0, romHash: currentROMHash)
                try session.loadState(from: data)
                statusMessage = "State loaded"
                refreshSaveStateDebugLine()
            } catch {
                NSLog("[QuickLoad] failed: %@", error.localizedDescription)
                statusMessage = "Load failed: \(detailedErrorMessage(error))"
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
                let data = try session.saveState(to: slot)
                let metadata = makeMetadata(slot: slot)
                try await SaveStateStorage.shared.persist(data: data, metadata: metadata, screenshotData: makeSaveStateScreenshotData())
                self.statusMessage = "State saved to slot \(slot) (\(data.count) bytes)"
                refreshSaveStateDebugLine()
            } catch {
                statusMessage = "Save failed: \(detailedErrorMessage(error))"
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
                let (data, _, _) = try SaveStateStorage.shared.load(slot: slot, romHash: currentROMHash)
                try session.loadState(from: data)
                statusMessage = "State loaded from slot \(slot)"
                refreshSaveStateDebugLine()
            } catch {
                statusMessage = "Load failed: \(detailedErrorMessage(error))"
            }
        }
    }

    func saveGameProgress() { saveState(slot: 1) }
    func loadGameProgress() { loadState(slot: 1) }

    func handleButtonPress(_ button: EmulatorButton, pressed: Bool) {
        if touchButtonStates[button] == pressed {
            return
        }

        if pressed {
            pendingReleaseTasks[button]?.cancel()
            pendingReleaseTasks[button] = nil
            touchButtonStates[button] = true
            sendTouchInput(button, pressed: true)
            return
        }

        pendingReleaseTasks[button]?.cancel()
        pendingReleaseTasks[button] = Task { @MainActor [weak self] in
            guard let self else { return }
            let delayNs = self.minimumPressDuration(for: button)
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled else { return }
            self.touchButtonStates[button] = false
            self.sendTouchInput(button, pressed: false)
            self.pendingReleaseTasks[button] = nil
        }
    }

    private func minimumPressDuration(for button: EmulatorButton) -> UInt64 {
        switch button {
        case .dpadUp, .dpadDown, .dpadLeft, .dpadRight:
            return Self.minimumDirectionalPressDurationNs
        default:
            return Self.minimumTouchPressDurationNs
        }
    }

    private func sendTouchInput(_ button: EmulatorButton, pressed: Bool) {
        guard let core = activeCore else { return }
        let inputType = mapTouchButtonToInputType(button)
        guard inputType >= 0 else { return }
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
        touchButtonStates.removeAll()
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

    private func deriveROMHash(from romPath: String) -> String {
        let filename = URL(fileURLWithPath: romPath).lastPathComponent
        let hash = filename.split(separator: ".").first.map(String.init) ?? ""
        return hash.lowercased()
    }

    private func makeMetadata(slot: Int) -> SaveStateMetadata {
        SaveStateMetadata(
            slot: slot,
            romHash: currentROMHash,
            platform: currentPlatform?.rawValue ?? "",
            createdAt: Date(),
            gameTitle: currentGameTitle,
            emulatorVersion: "1.0",
            screenshotData: nil
        )
    }

    private func persistPlayedTimeIfNeeded() {
        guard let startedAt = sessionStartedAt, !currentROMHash.isEmpty else { return }
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        guard elapsed > 0 else { return }
        let context = PersistenceController.shared.viewContext
        let request: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        request.predicate = NSPredicate(format: "checksum == %@", currentROMHash)
        request.fetchLimit = 1
        if let entry = try? context.fetch(request).first {
            entry.lastPlayedAt = Date()
            entry.playtimeTotal += Int64(elapsed)
            try? context.save()
        }
    }

    private func refreshSaveStateDebugLine() {
        guard !currentROMHash.isEmpty else {
            saveStateDebugLine = ""
            return
        }
        saveStateDebugLine = SaveStateStorage.shared.debugSummary(romHash: currentROMHash)
    }

    private func detailedErrorMessage(_ error: Error) -> String {
        let nsError = error as NSError
        if let reason = nsError.localizedFailureReason, !reason.isEmpty {
            return reason
        }
        if !nsError.localizedDescription.isEmpty,
           nsError.localizedDescription != "The operation couldn’t be completed." {
            return nsError.localizedDescription
        }
        return "\(nsError.domain) (\(nsError.code))"
    }

    private func supportsNativeBatterySave(_ platform: Platform?) -> Bool {
        guard let platform else { return false }
        return platform == .GB || platform == .GBC || platform == .GBA
    }

    private func nativeSaveDirectoryURL() -> URL? {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let dir = documents.appendingPathComponent("NativeSaves", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            NSLog("[NativeSave] Failed to create NativeSaves directory: %@", error.localizedDescription)
            return nil
        }
    }

    private func nativeSaveURL() -> URL? {
        guard supportsNativeBatterySave(currentPlatform),
              !currentROMHash.isEmpty,
              let platform = currentPlatform,
              let baseDir = nativeSaveDirectoryURL() else {
            return nil
        }
        let filename = "\(currentROMHash).\(platform.rawValue.lowercased()).sav"
        return baseDir.appendingPathComponent(filename, isDirectory: false)
    }

    private func restoreNativeSaveIfAvailable(for core: EmulatorCore) {
        guard supportsNativeBatterySave(currentPlatform), let url = nativeSaveURL() else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let data = try Data(contentsOf: url)
            guard !data.isEmpty else { return }
            if core.importBatterySave(data) {
                NSLog("[NativeSave] Loaded battery save bytes=%d rom=%@", data.count, currentROMHash)
            } else {
                NSLog("[NativeSave] Failed to restore battery save rom=%@", currentROMHash)
            }
        } catch {
            NSLog("[NativeSave] Read failed path=%@ error=%@", url.path, error.localizedDescription)
        }
    }

    private func persistNativeSaveIfNeeded(force: Bool) {
        guard supportsNativeBatterySave(currentPlatform),
              let core = activeCore,
              let url = nativeSaveURL() else { return }

        let now = CACurrentMediaTime()
        if !force, now - lastNativeSavePersistTime < 8.0 {
            return
        }
        lastNativeSavePersistTime = now

        guard let data = core.exportBatterySave(), !data.isEmpty else { return }

        do {
            if let existing = try? Data(contentsOf: url), existing == data {
                return
            }
            try data.write(to: url, options: [.atomic])
        } catch {
            NSLog("[NativeSave] Persist failed path=%@ error=%@", url.path, error.localizedDescription)
        }
    }

    func setNDSScreenLayout(_ layout: NDSScreenLayout) {
        guard let ndsCore = activeCore as? NDSCore else { return }
        guard ndsCore.setScreenLayout(layout) else { return }

        switch layout {
        case .stacked:
            frameWidth = 256
            frameHeight = 384
        case .sideBySide:
            frameWidth = 512
            frameHeight = 192
        case .topOnly, .bottomOnly:
            frameWidth = 256
            frameHeight = 192
        }
    }

    func getNDSScreenLayout() -> NDSScreenLayout {
        guard let ndsCore = activeCore as? NDSCore else { return .stacked }
        return ndsCore.getScreenLayout()
    }

    func setNDSTouchNormalized(x: CGFloat, y: CGFloat, pressed: Bool) {
        guard let ndsCore = activeCore as? NDSCore else { return }
        let clampedX = max(0, min(1, x))
        let clampedY = max(0, min(1, y))
        ndsCore.setStylus(
            x: Int((clampedX * 255.0).rounded()),
            y: Int((clampedY * 191.0).rounded()),
            pressed: pressed
        )
    }

    func clearNDSTouch() {
        guard let ndsCore = activeCore as? NDSCore else { return }
        ndsCore.clearStylus()
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

    func saveSlotSummaries() -> [SaveStateSlotSummary] {
        guard !currentROMHash.isEmpty else { return [] }
        return SaveStateStorage.shared.listSlotSummaries(for: currentROMHash)
    }

    func hasSavedStatesForCurrentGame() -> Bool {
        guard !currentROMHash.isEmpty else { return false }
        return SaveStateStorage.shared.hasAnySaveState(for: currentROMHash)
    }

    func loadSlotSummary(_ summary: SaveStateSlotSummary) {
        guard !summary.isEmpty else { return }
        loadState(slot: summary.slot)
    }

    func refreshSaveStatesStatus() {
        refreshSaveStateDebugLine()
    }

    private func makeSaveStateScreenshotData() -> Data? {
        #if canImport(UIKit)
        guard let snapshot = lastFrameSnapshot else { return nil }
        let width = snapshot.width
        let height = snapshot.height
        guard width > 0, height > 0, snapshot.bytesPerRow >= width * 4 else { return nil }

        let data = snapshot.data as CFData
        guard let provider = CGDataProvider(data: data) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        )
        guard let cgImage = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: snapshot.bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        ) else { return nil }

        return UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.72)
        #else
        return nil
        #endif
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
            lastFrameSnapshot = (data: data, width: width, height: height, bytesPerRow: pitch)
            
            metalRenderer?.enqueueFrame(data, width: width, height: height, bytesPerRow: pitch)
            
            let now = CACurrentMediaTime()
            if now - lastFPSTime > 0.5 {
                let fps = Int(emulatorSession?.currentFrameRate ?? 0)
                self.currentFPS = fps
                lastFPSTime = now
            }
            persistNativeSaveIfNeeded(force: false)
        }
    }
    
    func emulatorDidGenerateAudio(samples: Data?) {
        autoreleasepool {
            guard let samples = samples, !samples.isEmpty else { return }
            audioEngine?.updateAudioBuffer(samples)
        }
    }
}
