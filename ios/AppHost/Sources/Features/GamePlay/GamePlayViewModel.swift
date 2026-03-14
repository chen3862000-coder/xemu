import Foundation
import SwiftUI
import MetalKit
import Combine
import GameController
import CoreData
import AVFoundation
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
    @Published var latestUnlockedAchievement: PlayerAchievementUnlock?
    @AppStorage("audioQuality") private var audioQuality = 1

    private var emulatorSession: EmulatorSession?
    private(set) var metalRenderer: MetalRenderer?
    private var audioEngine: AudioEngine?
    private var inputBus: InputBus?
    private var activeCore: EmulatorCore?
    private let performanceProfiler = PerformanceProfiler.shared
    private var activeDisplayPlatform: Platform?
    private var lastAppliedQualityProfile: PerfQualityProfile?
    private var activeAudioSampleRate: Double = 48_000
    private var pendingReleaseTasks: [EmulatorButton: Task<Void, Never>] = [:]
    private var touchButtonStates: [EmulatorButton: Bool] = [:]
    private var currentROMHash: String = ""
    private var currentPlatform: Platform?
    private var currentGameTitle: String = ""
    private var sessionStartedAt: Date?
    private var lastFrameSnapshot: (data: Data, width: Int, height: Int, bytesPerRow: Int)?
    private var audioDebugChunkCount: Int = 0
    private var ndsRateNormalizationLogCount: Int = 0
    
    private var frameWidth = 160
    private var frameHeight = 144
    private var lastFPSTime: Double = 0
    private var lastNativeSavePersistTime: Double = 0
    private var isStoppingEmulation = false
    private var hasAutoResumedStateThisSession = false
    private var isStateLoadInProgress = false
    private var audioResamplerSourceRate: Int = 0
    private var audioResamplerTargetRate: Int = 0
    private var audioResamplerPosition: Double = 0
    private var audioResamplerCarryFrame: (Int16, Int16)?
    private var ndsTouchIsPressed = false
    private var requestedNDSScreenLayout: NDSScreenLayout = .stacked
    private var ndsTouchPressedAtNs: UInt64 = 0
    private var pendingNDSTouchReleaseTask: Task<Void, Never>?
    @Published private(set) var currentNDSDisplayLayout: NDSScreenLayout = .stacked
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
                Task { @MainActor [weak self] in
                    self?.persistNativeSaveIfNeeded(force: true)
                }
            }
        )
        lifecycleObservers.append(
            center.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.persistNativeSaveIfNeeded(force: true)
                }
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

    static func effectiveDisplayPlatform(
        requestedPlatform: Platform,
        isCGBModeDetected: Bool
    ) -> Platform {
        switch requestedPlatform {
        case .GBC:
            // Preserve the GBC display pipeline for explicit GBC launches even if
            // runtime detection is late or temporarily unavailable.
            return .GBC
        case .GB:
            return isCGBModeDetected ? .GBC : .GB
        default:
            return requestedPlatform
        }
    }

    static func shouldEnablePostProcessing(
        for profile: PerfQualityProfile,
        displayPlatform: Platform?
    ) -> Bool {
        if displayPlatform == .GBC {
            return true
        }
        return profile.shadersEnabled
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
                let frameSize = Self.ndsFrameDimensions(for: requestedNDSScreenLayout)
                frameWidth = frameSize.width
                frameHeight = frameSize.height
                currentNDSDisplayLayout = requestedNDSScreenLayout
            default:
                frameWidth = 160
                frameHeight = 144
            }

            if platform == .NDS, let ndsCore = core as? NDSCore {
                _ = applyNDSScreenLayout(requestedNDSScreenLayout, to: ndsCore)
            }
            
            // NDS native saves are file-backed sidecars and must be materialized
            // before ROM load so the core can pick them up during initialization.
            if platform == .NDS {
                restoreNativeSaveIfAvailable(for: core)
            }

            let success = core.loadROM(romPath: romPath)
            guard success else {
                statusMessage = "Failed to load ROM"
                return
            }
            if platform != .NDS {
                restoreNativeSaveIfAvailable(for: core)
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
            case .NDS:
                textureSize = CGSize(width: frameWidth, height: frameHeight)
            default:
                textureSize = CGSize(width: 160, height: 144)
            }
            metalRenderer = MetalRenderer(textureSize: textureSize)
            let effectiveDisplayPlatform = Self.effectiveDisplayPlatform(
                requestedPlatform: platform,
                isCGBModeDetected: (core as? GBCore)?.isCGBModeDetected ?? false
            )
            activeDisplayPlatform = effectiveDisplayPlatform
            applyDisplayColorAdjustments(for: effectiveDisplayPlatform)

            let isNDSCore = core is NDSCore
            let audioEngineRate: Double
            switch audioQuality {
            case 0:  // Sound First - 48kHz for best quality
                audioEngineRate = 48_000
            case 1:  // Balanced - stable 44.1kHz output
                if platform == .GB || platform == .GBC {
                    audioEngineRate = Double(GBCore.nativeAudioSampleRate)
                } else if platform == .NDS || isNDSCore {
                    // Keep NDS output pinned to hardware-friendly 48kHz.
                    audioEngineRate = 48_000
                } else {
                    audioEngineRate = 44_100
                }
            default:  // Frame First - direct pass-through; keep GB/GBC native
                if platform == .GB || platform == .GBC {
                    audioEngineRate = Double(GBCore.nativeAudioSampleRate)
                } else if platform == .NDS || isNDSCore {
                    audioEngineRate = 48_000
                } else {
                    audioEngineRate = 44_100
                }
            }
            NSLog("[AudioTune] start platform=%@ core=%@ quality=%d initRate=%.1f",
                  platform.rawValue,
                  String(describing: type(of: core)),
                  audioQuality,
                  audioEngineRate)
            activeAudioSampleRate = audioEngineRate
            audioEngine = AudioEngine(sampleRate: audioEngineRate)
            audioEngine?.configureAudioSession()
            try? audioEngine?.start()
            audioEngine?.setVolume(0.8)
            resetAudioResamplerState()

            emulatorSession?.start()
            refreshSaveStateDebugLine()
            sessionStartedAt = Date()
            hasAutoResumedStateThisSession = false
            isStateLoadInProgress = false
            latestUnlockedAchievement = nil

            isRunning = true
            isPaused = false
            statusMessage = ""
            performanceProfiler.startSession(platform: platform)
            applyPerformanceProfileIfNeeded(performanceProfiler.currentQualityProfile)
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
            clearPendingNDSTouchRelease()

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
            activeDisplayPlatform = nil
            lastAppliedQualityProfile = nil
            activeAudioSampleRate = 44_100
            resetAudioResamplerState()
            currentPlatform = nil
            currentROMHash = ""
            currentGameTitle = ""
            sessionStartedAt = nil
            lastFrameSnapshot = nil
            hasAutoResumedStateThisSession = false
            isStateLoadInProgress = false
            ndsTouchIsPressed = false
            ndsTouchPressedAtNs = 0
            latestUnlockedAchievement = nil
        }
        
        isRunning = false
        isPaused = false
        performanceProfiler.stopSession()
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

    func restartEmulation() {
        guard let core = activeCore else {
            statusMessage = "No active session"
            return
        }
        persistPlayedTimeIfNeeded()
        persistNativeSaveIfNeeded(force: true)
        core.reset()
        emulatorSession?.resume()
        audioEngine?.resume()
        sessionStartedAt = Date()
        isRunning = true
        isPaused = false
        statusMessage = "Game restarted"
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
            let op = performanceProfiler.beginOperation("quick_save", metadata: ["slot": "0"])
            defer { performanceProfiler.endOperation(op) }
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
        guard emulatorSession != nil else {
            statusMessage = "No active session"
            return
        }
        guard !currentROMHash.isEmpty else {
            statusMessage = "Load failed: missing ROM hash"
            return
        }
        loadStateInternal(slot: 0, source: "quick_load", markAutoResume: false)
    }

    func saveState(slot: Int) {
        guard let session = emulatorSession else {
            statusMessage = "No active session"
            return
        }
        
        Task {
            let op = performanceProfiler.beginOperation("save_state", metadata: ["slot": String(slot)])
            defer { performanceProfiler.endOperation(op) }
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
        guard emulatorSession != nil else {
            statusMessage = "No active session"
            return
        }
        loadStateInternal(slot: slot, source: "manual_slot", markAutoResume: false)
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
        let endedAt = Date()
        let elapsed = Int(endedAt.timeIntervalSince(startedAt))
        guard elapsed > 0 else { return }
        let context = PersistenceController.shared.viewContext
        let request: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        request.predicate = NSPredicate(format: "checksum == %@", currentROMHash)
        request.fetchLimit = 1

        var resolvedTitle = currentGameTitle
        var resolvedSystem = currentPlatform?.rawValue.lowercased() ?? ""
        if let entry = try? context.fetch(request).first {
            entry.lastPlayedAt = endedAt
            entry.playtimeTotal += Int64(elapsed)
            if let entryTitle = entry.title, !entryTitle.isEmpty {
                resolvedTitle = entryTitle
            }
            let rawSystem = (entry.system ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !rawSystem.isEmpty {
                resolvedSystem = rawSystem.lowercased()
            }
            try? context.save()
        }

        let unlocks = PlayerProgressStore.shared.recordSession(
            gameID: currentROMHash,
            gameTitle: resolvedTitle,
            system: resolvedSystem,
            startTime: startedAt,
            endTime: endedAt,
            durationSeconds: elapsed
        )
        if let firstUnlock = unlocks.first {
            latestUnlockedAchievement = firstUnlock
            if isRunning && !isPaused {
                statusMessage = "🏆 \(firstUnlock.title) unlocked"
            }
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
        return platform == .GB || platform == .GBC || platform == .GBA || platform == .NDS
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
        let op = performanceProfiler.beginOperation(
            "battery_restore",
            metadata: ["platform": currentPlatform?.rawValue ?? "unknown"]
        )
        defer { performanceProfiler.endOperation(op) }

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
        let op = performanceProfiler.beginOperation(
            "battery_persist",
            metadata: ["platform": currentPlatform?.rawValue ?? "unknown", "forced": force ? "1" : "0"]
        )
        defer { performanceProfiler.endOperation(op) }

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
        requestedNDSScreenLayout = layout
        let frameSize = Self.ndsFrameDimensions(for: layout)
        frameWidth = frameSize.width
        frameHeight = frameSize.height
        currentNDSDisplayLayout = layout
        guard let ndsCore = activeCore as? NDSCore else { return }
        _ = applyNDSScreenLayout(layout, to: ndsCore)
    }

    func getNDSScreenLayout() -> NDSScreenLayout {
        guard let ndsCore = activeCore as? NDSCore else { return .stacked }
        return ndsCore.getScreenLayout()
    }

    static func ndsFrameDimensions(for layout: NDSScreenLayout) -> (width: Int, height: Int) {
        switch layout {
        case .stacked:
            return (256, 384)
        case .sideBySide:
            return (512, 192)
        case .topOnly, .bottomOnly:
            return (256, 192)
        }
    }

    static func resolvedNDSDisplayLayout(
        renderedWidth: Int,
        renderedHeight: Int,
        fallback: NDSScreenLayout
    ) -> NDSScreenLayout {
        guard renderedWidth > 0, renderedHeight > 0 else { return fallback }
        if renderedHeight > renderedWidth {
            return .stacked
        }
        if renderedWidth >= (renderedHeight * 2) {
            return .sideBySide
        }
        return fallback
    }

    @discardableResult
    private func applyNDSScreenLayout(_ layout: NDSScreenLayout, to ndsCore: NDSCore) -> Bool {
        guard ndsCore.setScreenLayout(layout) else { return false }
        let frameSize = Self.ndsFrameDimensions(for: layout)
        frameWidth = frameSize.width
        frameHeight = frameSize.height
        currentNDSDisplayLayout = layout
        return true
    }

    func setNDSTouchNormalized(x: CGFloat, y: CGFloat, pressed: Bool) {
        guard pressed else {
            clearNDSTouch()
            return
        }
        guard let ndsCore = activeCore as? NDSCore else { return }
        clearPendingNDSTouchRelease()
        let nowNs = DispatchTime.now().uptimeNanoseconds
        if !ndsTouchIsPressed {
            ndsTouchIsPressed = true
            ndsTouchPressedAtNs = nowNs
        }
        let clampedX = max(0, min(1, x))
        let clampedY = max(0, min(1, y))
        ndsCore.setStylus(
            x: Int((clampedX * 255.0).rounded()),
            y: Int((clampedY * 191.0).rounded()),
            pressed: true
        )
    }

    func clearNDSTouch() {
        guard let ndsCore = activeCore as? NDSCore else { return }
        guard ndsTouchIsPressed else {
            ndsCore.clearStylus()
            return
        }
        let nowNs = DispatchTime.now().uptimeNanoseconds
        let elapsed = nowNs >= ndsTouchPressedAtNs ? nowNs - ndsTouchPressedAtNs : 0
        let minimum = Self.minimumTouchPressDurationNs
        let remaining = minimum > elapsed ? minimum - elapsed : 0
        clearPendingNDSTouchRelease()

        if remaining == 0 {
            ndsCore.clearStylus()
            ndsTouchIsPressed = false
            ndsTouchPressedAtNs = 0
            return
        }

        pendingNDSTouchReleaseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: remaining)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.ndsTouchIsPressed else { return }
                (self.activeCore as? NDSCore)?.clearStylus()
                self.ndsTouchIsPressed = false
                self.ndsTouchPressedAtNs = 0
                self.pendingNDSTouchReleaseTask = nil
            }
        }
    }

    private func clearPendingNDSTouchRelease() {
        pendingNDSTouchReleaseTask?.cancel()
        pendingNDSTouchReleaseTask = nil
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

    func currentRenderScale() -> Double {
        max(0.5, min(1.0, performanceProfiler.currentQualityProfile.renderScale))
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

    func autoResumeLaunchState(_ summary: SaveStateSlotSummary) {
        guard !summary.isEmpty else { return }
        guard !hasAutoResumedStateThisSession else {
            NSLog("[StateLoadGuard] auto-resume skipped reason=already_loaded slot=%d rom=%@", summary.slot, currentROMHash)
            return
        }
        loadStateInternal(slot: summary.slot, source: "launch_auto_resume", markAutoResume: true)
    }

    private func loadStateInternal(slot: Int, source: String, markAutoResume: Bool) {
        guard !isStoppingEmulation else {
            NSLog("[StateLoadGuard] load skipped source=%@ reason=stopping slot=%d rom=%@", source, slot, currentROMHash)
            return
        }
        guard !isStateLoadInProgress else {
            NSLog("[StateLoadGuard] load skipped source=%@ reason=in_progress slot=%d rom=%@", source, slot, currentROMHash)
            return
        }
        guard !currentROMHash.isEmpty else {
            statusMessage = "Load failed: missing ROM hash"
            return
        }
        guard let session = emulatorSession else {
            statusMessage = "No active session"
            return
        }

        isStateLoadInProgress = true
        Task {
            let op = performanceProfiler.beginOperation("load_state", metadata: ["slot": String(slot), "source": source])
            defer {
                performanceProfiler.endOperation(op)
                isStateLoadInProgress = false
            }

            do {
                // Serialize state restore by pausing emulation/audio first.
                let wasPaused = isPaused
                emulatorSession?.pause()
                audioEngine?.pause()
                defer {
                    if !wasPaused {
                        emulatorSession?.resume()
                        audioEngine?.resume()
                    }
                }

                let (data, _, _) = try SaveStateStorage.shared.load(slot: slot, romHash: currentROMHash)
                try session.loadState(from: data)
                if currentPlatform == .NDS {
                    // NDS savestate restore can emit transient invalid audio; hold longer.
                    resetAudioResamplerState()
                    audioEngine?.quarantineAfterStateLoad(silenceMs: 700, fadeInMs: 260)
                } else {
                    audioEngine?.quarantineAfterStateLoad(silenceMs: 220, fadeInMs: 120)
                }
                if markAutoResume {
                    hasAutoResumedStateThisSession = true
                }
                statusMessage = slot == 0 ? "State loaded" : "State loaded from slot \(slot)"
                refreshSaveStateDebugLine()
                NSLog("[StateLoadGuard] load applied source=%@ slot=%d bytes=%d rom=%@", source, slot, data.count, currentROMHash)
            } catch {
                NSLog("[StateLoadGuard] load failed source=%@ slot=%d rom=%@ error=%@", source, slot, currentROMHash, error.localizedDescription)
                statusMessage = "Load failed: \(detailedErrorMessage(error))"
            }
        }
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

    private func applyDisplayColorAdjustments(for displayPlatform: Platform?) {
        switch displayPlatform {
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
    }

    private func applyPerformanceProfileIfNeeded(_ profile: PerfQualityProfile) {
        guard let renderer = metalRenderer else { return }
        guard lastAppliedQualityProfile != profile else { return }
        lastAppliedQualityProfile = profile
        emulatorSession?.setRenderFrameSkip(max(0, profile.frameSkip))
        let shouldEnablePostProcessing = Self.shouldEnablePostProcessing(
            for: profile,
            displayPlatform: activeDisplayPlatform
        )
        renderer.setPostProcessingEnabled(shouldEnablePostProcessing)
        if shouldEnablePostProcessing {
            applyDisplayColorAdjustments(for: activeDisplayPlatform)
        }
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
            if currentPlatform == .NDS {
                currentNDSDisplayLayout = Self.resolvedNDSDisplayLayout(
                    renderedWidth: width,
                    renderedHeight: height,
                    fallback: requestedNDSScreenLayout
                )
            }
            lastFrameSnapshot = (data: data, width: width, height: height, bytesPerRow: pitch)
            let qualityProfile = performanceProfiler.currentQualityProfile
            applyPerformanceProfileIfNeeded(qualityProfile)

            metalRenderer?.enqueueFrame(data, width: width, height: height, bytesPerRow: pitch)
            performanceProfiler.recordFrame()
            let now = CACurrentMediaTime()
            if now - lastFPSTime > 0.5 {
                let fps = Int(emulatorSession?.currentFrameRate ?? 0)
                self.currentFPS = fps
                lastFPSTime = now
            }
            persistNativeSaveIfNeeded(force: false)
        }
    }
    
    func emulatorDidGenerateAudio(samples: Data?, sampleRate: Int) {
        autoreleasepool {
            guard let samples = samples, !samples.isEmpty else { return }
            let normalizedInputRate = normalizedInputSampleRate(sampleRate)

            if audioQuality != 0,
               prefersNativeAudioRateForCurrentPlatform(),
               normalizedInputRate > 0,
               currentPlatform != .NDS {
                retuneAudioEngineIfNeeded(to: normalizedInputRate)
            }

            var outputSamples = samples
            var outputRate = normalizedInputRate

            switch audioQuality {
            case 0:  // Sound First - resample to 48kHz for best quality
                let targetRate = 48_000
                outputRate = targetRate
                if normalizedInputRate != targetRate {
                    guard let resampled = resampleAudioLinearStreaming(samples: samples, fromRate: normalizedInputRate, toRate: targetRate) else {
                        return
                    }
                    outputSamples = resampled
                } else {
                    resetAudioResamplerState()
                }
                
            case 1:  // Balanced
                if currentPlatform == .NDS {
                    let targetRate = 48_000
                    outputRate = targetRate
                    if normalizedInputRate != targetRate {
                        guard let resampled = resampleAudioLinearStreaming(samples: samples, fromRate: normalizedInputRate, toRate: targetRate) else {
                            return
                        }
                        outputSamples = resampled
                    } else {
                        resetAudioResamplerState()
                    }
                } else if prefersNativeAudioRateForCurrentPlatform() {
                    outputSamples = samples
                    outputRate = normalizedInputRate
                    resetAudioResamplerState()
                } else {
                    let targetRate = 44_100
                    outputRate = targetRate
                    if normalizedInputRate != targetRate {
                        guard let resampled = resampleAudioLinearStreaming(samples: samples, fromRate: normalizedInputRate, toRate: targetRate) else {
                            return
                        }
                        outputSamples = resampled
                    } else {
                        resetAudioResamplerState()
                    }
                }
                
            case 2:  // Frame First
                if currentPlatform == .NDS {
                    let targetRate = 48_000
                    outputRate = targetRate
                    if normalizedInputRate != targetRate {
                        guard let resampled = resampleAudioLinearStreaming(samples: samples, fromRate: normalizedInputRate, toRate: targetRate) else {
                            return
                        }
                        outputSamples = resampled
                    } else {
                        resetAudioResamplerState()
                    }
                } else {
                    outputSamples = samples
                    resetAudioResamplerState()
                }
                
            default:
                outputSamples = samples
                resetAudioResamplerState()
            }

            audioEngine?.updateAudioBuffer(outputSamples)
            logAudioABIfNeeded(rawSamples: samples,
                               rawRate: normalizedInputRate,
                               outputSamples: outputSamples,
                               outputRate: outputRate)
        }
    }

    private func normalizedInputSampleRate(_ sampleRate: Int) -> Int {
        guard currentPlatform == .NDS else { return sampleRate }
        guard sampleRate > 0 else { return sampleRate }

        // melonDS/libretro occasionally reports a near-32k value (e.g. 32728).
        // Normalize near-native DS rates so resampling ratio stays stable.
        if abs(sampleRate - 32_768) <= 300 {
            if sampleRate != 32_768 {
                ndsRateNormalizationLogCount += 1
                if ndsRateNormalizationLogCount <= 3 || ndsRateNormalizationLogCount % 240 == 0 {
                    NSLog("[AudioTune] normalize nds inputRate from=%d to=32768", sampleRate)
                }
            }
            return 32_768
        }
        return sampleRate
    }

    private func prefersNativeAudioRateForCurrentPlatform() -> Bool {
        currentPlatform == .GB ||
        currentPlatform == .GBC ||
        currentPlatform == .NDS ||
        activeCore is NDSCore
    }

    private func retuneAudioEngineIfNeeded(to sampleRate: Int) {
        let targetRate = Double(sampleRate)
        guard targetRate >= 8_000, targetRate <= 96_000 else { return }
        guard abs(activeAudioSampleRate - targetRate) >= 12 else { return }

        NSLog("[AudioTune] retune from=%.1f to=%.1f platform=%@",
              activeAudioSampleRate,
              targetRate,
              currentPlatform?.rawValue ?? "unknown")

        audioEngine?.stop()
        audioEngine?.deactivateAudioSession()

        activeAudioSampleRate = targetRate
        let engine = AudioEngine(sampleRate: targetRate)
        engine.configureAudioSession()
        try? engine.start()
        engine.setVolume(0.8)
        audioEngine = engine
    }

    private func resetAudioResamplerState() {
        audioResamplerSourceRate = 0
        audioResamplerTargetRate = 0
        audioResamplerPosition = 0
        audioResamplerCarryFrame = nil
    }

    private func resampleAudioLinearStreaming(samples: Data, fromRate: Int, toRate: Int) -> Data? {
        guard fromRate > 0, toRate > 0 else { return samples }
        guard fromRate != toRate else { return samples }

        let channelCount = 2
        let bytesPerFrame = MemoryLayout<Int16>.size * channelCount
        let sourceFrames = samples.count / bytesPerFrame
        guard sourceFrames > 0 else { return nil }

        if audioResamplerSourceRate != fromRate || audioResamplerTargetRate != toRate {
            audioResamplerSourceRate = fromRate
            audioResamplerTargetRate = toRate
            audioResamplerPosition = 0
            audioResamplerCarryFrame = nil
        }

        var sourceSamples = [Int16](repeating: 0, count: sourceFrames * channelCount)
        _ = sourceSamples.withUnsafeMutableBytes { dst in
            samples.copyBytes(to: dst)
        }

        var workingSamples: [Int16]
        if let carry = audioResamplerCarryFrame {
            workingSamples = [carry.0, carry.1]
            workingSamples.append(contentsOf: sourceSamples)
        } else {
            workingSamples = sourceSamples
        }

        let workingFrames = workingSamples.count / channelCount
        guard workingFrames > 1 else {
            let last = sourceSamples.count - channelCount
            if last >= 0 {
                audioResamplerCarryFrame = (sourceSamples[last], sourceSamples[last + 1])
            }
            return nil
        }

        let step = Double(fromRate) / Double(toRate)
        if !step.isFinite || step <= 0 {
            return samples
        }

        let capacityFrames = max(
            1,
            Int((Double(workingFrames - 1) - audioResamplerPosition) / step) + 2
        )
        var outSamples: [Int16] = []
        outSamples.reserveCapacity(capacityFrames * channelCount)

        var position = audioResamplerPosition
        while position + 1.0 < Double(workingFrames) {
            let baseFrame = Int(position)
            let nextFrame = baseFrame + 1
            let frac = position - Double(baseFrame)

            for channel in 0..<channelCount {
                let s0 = Double(workingSamples[(baseFrame * channelCount) + channel])
                let s1 = Double(workingSamples[(nextFrame * channelCount) + channel])
                let mixed = s0 + ((s1 - s0) * frac)
                let clamped = max(Double(Int16.min), min(Double(Int16.max), mixed.rounded()))
                outSamples.append(Int16(clamped))
            }

            position += step
        }

        audioResamplerPosition = position - Double(workingFrames - 1)
        if !audioResamplerPosition.isFinite || audioResamplerPosition < 0 {
            audioResamplerPosition = 0
        }

        let lastFrameIndex = (workingFrames - 1) * channelCount
        audioResamplerCarryFrame = (
            workingSamples[lastFrameIndex],
            workingSamples[lastFrameIndex + 1]
        )

        guard !outSamples.isEmpty else { return nil }
        return outSamples.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return Data() }
            return Data(bytes: base, count: buffer.count * MemoryLayout<Int16>.size)
        }
    }

    private func logAudioABIfNeeded(rawSamples: Data,
                                    rawRate: Int,
                                    outputSamples: Data,
                                    outputRate: Int) {
        guard currentPlatform == .GBA || currentPlatform == .NDS else { return }
        guard UserDefaults.standard.bool(forKey: "dev.audio.debugAB") else { return }

        audioDebugChunkCount += 1
        guard audioDebugChunkCount % 120 == 0 else { return }

        let rawMetrics = audioMetrics(for: rawSamples)
        let outMetrics = audioMetrics(for: outputSamples)
        let title = currentGameTitle.isEmpty ? "unknown" : currentGameTitle
        let hashPrefix = String(currentROMHash.prefix(8))
        NSLog("[AudioAB] game=%@ hash=%@ chunk=%d quality=%d rawRate=%d outRate=%d rawFrames=%d outFrames=%d rawPeak=%d outPeak=%d rawDcL=%.1f rawDcR=%.1f outDcL=%.1f outDcR=%.1f",
              title,
              hashPrefix,
              audioDebugChunkCount,
              audioQuality,
              rawRate,
              outputRate,
              rawSamples.count / 4,
              outputSamples.count / 4,
              rawMetrics.peak,
              outMetrics.peak,
              rawMetrics.dcL,
              rawMetrics.dcR,
              outMetrics.dcL,
              outMetrics.dcR)
    }

    private func audioMetrics(for samples: Data) -> (peak: Int, dcL: Double, dcR: Double) {
        guard samples.count >= 4 else { return (0, 0, 0) }
        let sampleCount = samples.count / 2
        guard sampleCount >= 2 else { return (0, 0, 0) }

        return samples.withUnsafeBytes { raw in
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: Int16.self) else {
                return (0, 0, 0)
            }
            var peak = 0
            var sumL: Double = 0
            var sumR: Double = 0
            var frames = 0
            var idx = 0
            while idx + 1 < sampleCount {
                let l = Int(ptr[idx])
                let r = Int(ptr[idx + 1])
                let absL = Swift.abs(l)
                let absR = Swift.abs(r)
                if absL > peak { peak = absL }
                if absR > peak { peak = absR }
                sumL += Double(l)
                sumR += Double(r)
                frames += 1
                idx += 2
            }
            guard frames > 0 else { return (peak, 0, 0) }
            return (peak, sumL / Double(frames), sumR / Double(frames))
        }
    }

}
