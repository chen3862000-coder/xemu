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
    @Published private(set) var gameplayAnalysisSnapshot: MarioAnalysisSnapshot?
    @AppStorage("audioQuality") private var audioQuality = 1
    @AppStorage("settings.dev.hpDeathDetection") private var hpDeathDetectionEnabled = false

    private var emulatorSession: EmulatorSession?
    private(set) var metalRenderer: MetalRenderer?
    private var audioEngine: AudioEngine?
    private var inputBus: InputBus?
    private var activeCore: EmulatorCore?
    private let performanceProfiler = PerformanceProfiler.shared
    private var activeDisplayPlatform: Platform?
    private var lastAppliedQualityProfile: PerfQualityProfile?
    private var activeAudioSampleRate: Double = 48_000
    private var fastForwardSpeed = 1
    private var pendingReleaseTasks: [EmulatorButton: Task<Void, Never>] = [:]
    private var touchButtonStates: [EmulatorButton: Bool] = [:]
    private var currentROMHash: String = ""
    private var currentPlatform: Platform?
    private var currentGameTitle: String = ""
    private var frameAnalysisCoordinator: FrameAnalysisCoordinator?
    private var activePlayInsightsGame: PlayInsightsSupportedGame?
    private var latestPlayInsightsLiveSample: MarioLiveMemorySample?
    private var lastPublishedPlayInsightsPayload: [String: UInt16] = [:]
    private var lastPublishedPlayInsightsLocationSummary: String?
    private var sessionDeathEvents = 0
    private var sessionDamageEvents = 0
    private var sessionStartedAt: Date?
    private var lastFrameSnapshot: (data: Data, width: Int, height: Int, bytesPerRow: Int)?
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
    private var audioDebugPacketCount = 0
    private var ndsTouchIsPressed = false
    private var requestedNDSScreenLayout: NDSScreenLayout = .stacked
    private var ndsTouchPressedAtNs: UInt64 = 0
    private var pendingNDSTouchReleaseTask: Task<Void, Never>?
    @Published private(set) var currentNDSDisplayLayout: NDSScreenLayout = .stacked
    private var currentSaveStateData: Data? = nil
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
        Self.targetFrameTime(forSpeed: fastForwardSpeed)
    }

    static func targetFrameTime(forSpeed speed: Int) -> Double {
        let normalizedSpeed = max(1, speed)
        return 1.0 / (60.0 * Double(normalizedSpeed))
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

    static func initialAudioEngineRate(
        requestedPlatform: Platform,
        isNDSCore: Bool,
        audioQuality: Int,
        nativeRateHint: Int? = nil
    ) -> Double {
        #if os(iOS)
        return AudioEngine.preferredHardwareSampleRate(fallback: 48_000)
        #else
        let preferredRate: Double
        switch audioQuality {
        case 0:
            preferredRate = 48_000
        case 1, 2:
            if requestedPlatform == .GB || requestedPlatform == .GBC {
                preferredRate = Double(GBCore.nativeAudioSampleRate)
            } else if requestedPlatform == .NDS || isNDSCore {
                let hintedRate = nativeRateHint ?? 32_728
                preferredRate = Double(max(8_000, hintedRate))
            } else {
                preferredRate = 44_100
            }
        default:
            preferredRate = 44_100
        }
        return preferredRate
        #endif
    }

    static func audioLatencyProfile(
        requestedPlatform: Platform,
        isNDSCore: Bool
    ) -> AudioEngine.LatencyProfile {
        if requestedPlatform == .GB || requestedPlatform == .GBC {
            return .lowLatency
        }
        if requestedPlatform == .NDS || isNDSCore {
            return .streaming
        }
        return .balanced
    }

    static func shouldAutoResumeLaunchState(for platform: Platform?) -> Bool {
        _ = platform
        return true
    }

    static func resolvedAudioSampleRate(_ sampleRate: Int, platform: Platform?) -> Int {
        guard platform == .NDS else { return sampleRate }
        guard sampleRate > 0 else { return sampleRate }
        return sampleRate
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
            configureGameplayAnalysisIfNeeded(platform: platform)
            
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

            // Reset save state data for new game
            currentSaveStateData = nil

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
            let audioEngineRate = Self.initialAudioEngineRate(
                requestedPlatform: platform,
                isNDSCore: isNDSCore,
                audioQuality: audioQuality,
                nativeRateHint: core.getAudioSampleRate()
            )
            activeAudioSampleRate = audioEngineRate
            audioEngine = makeAudioEngine(
                sampleRate: audioEngineRate,
                platform: platform,
                isNDSCore: isNDSCore
            )
            audioEngine?.configureAudioSession()
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            let bluetoothPorts: Set<AVAudioSession.Port> = [.bluetoothA2DP, .bluetoothHFP, .bluetoothLE]
            let isBluetoothRouteActive = session.currentRoute.outputs.contains { bluetoothPorts.contains($0.portType) }
            audioEngine?.applyRouteOverride(isBluetooth: isBluetoothRouteActive)

            let activatedHardwareSampleRate = session.sampleRate
            if activatedHardwareSampleRate > 0, abs(activatedHardwareSampleRate - activeAudioSampleRate) >= 1 {
                rebuildAudioEngineForHardwareChange(sampleRate: activatedHardwareSampleRate)
            }
            NSLog(
                "[AudioLaunch] platform=%@ requestedRate=%d activatedRate=%d ioBufferMs=%d bluetooth=%@ route=%@",
                platform.rawValue,
                Int(audioEngineRate.rounded()),
                Int(session.sampleRate.rounded()),
                Int((session.ioBufferDuration * 1000).rounded()),
                isBluetoothRouteActive ? "1" : "0",
                session.currentRoute.outputs.map { "\($0.portType.rawValue):\($0.portName)" }.joined(separator: ",")
            )
            #endif
            try? audioEngine?.start()
            audioEngine?.setVolume(0.8)
            resetAudioResamplerState()
            audioDebugPacketCount = 0

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
            fastForwardSpeed = 1
            activeAudioSampleRate = 44_100
            resetAudioResamplerState()
            currentPlatform = nil
            currentROMHash = ""
            currentGameTitle = ""
            frameAnalysisCoordinator?.reset()
            frameAnalysisCoordinator = nil
            activePlayInsightsGame = nil
            latestPlayInsightsLiveSample = nil
            lastPublishedPlayInsightsPayload = [:]
            lastPublishedPlayInsightsLocationSummary = nil
            sessionDeathEvents = 0
            sessionDamageEvents = 0
            sessionStartedAt = nil
            lastFrameSnapshot = nil
            hasAutoResumedStateThisSession = false
            isStateLoadInProgress = false
            ndsTouchIsPressed = false
            ndsTouchPressedAtNs = 0
            latestUnlockedAchievement = nil
            gameplayAnalysisSnapshot = nil
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
                currentSaveStateData = data // Track save state for memory analysis
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

    private func makeAudioEngine(sampleRate: Double, platform: Platform, isNDSCore: Bool) -> AudioEngine {
        let engine = AudioEngine(
            sampleRate: sampleRate,
            latencyProfile: Self.audioLatencyProfile(
                requestedPlatform: platform,
                isNDSCore: isNDSCore
            )
        )
        #if os(iOS)
        engine.onHardwareConfigurationChanged = { [weak self] newSampleRate in
            self?.rebuildAudioEngineForHardwareChange(sampleRate: newSampleRate)
        }
        #endif
        return engine
    }

    private func rebuildAudioEngineForHardwareChange(sampleRate: Double) {
        guard !isStoppingEmulation else { return }
        guard let platform = currentPlatform else { return }
        guard activeCore != nil else { return }

        let resolvedSampleRate = max(8_000, sampleRate)
        guard abs(activeAudioSampleRate - resolvedSampleRate) >= 1 else { return }

        let isNDSCore = activeCore is NDSCore
        let wasPaused = isPaused

        NSLog(
            "[AudioLaunch] rebuild platform=%@ oldRate=%d newRate=%d running=%@ paused=%@",
            platform.rawValue,
            Int(activeAudioSampleRate.rounded()),
            Int(resolvedSampleRate.rounded()),
            isRunning ? "1" : "0",
            wasPaused ? "1" : "0"
        )

        audioEngine?.stop()
        activeAudioSampleRate = resolvedSampleRate

        let replacement = makeAudioEngine(
            sampleRate: resolvedSampleRate,
            platform: platform,
            isNDSCore: isNDSCore
        )
        audioEngine = replacement
        replacement.configureAudioSession()
        try? replacement.start()
        replacement.setVolume(0.8)
        if wasPaused {
            replacement.pause()
        }

        resetAudioResamplerState()
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

    private func configureGameplayAnalysisIfNeeded(platform: Platform) {
        // Completely disable analysis for GB/GBC platforms due to performance issues
        guard platform != .GB && platform != .GBC else {
            GameplayAnalysisLogger.session("gb-gbc-analysis-disabled platform=\(platform.rawValue)")
            frameAnalysisCoordinator = nil
            gameplayAnalysisSnapshot = nil
            activePlayInsightsGame = nil
            return
        }

        guard let profile = MarioGameProfile.activeProfile(
            title: currentGameTitle,
            platform: platform,
            romHash: currentROMHash
        ) else {
            GameplayAnalysisLogger.session("no-profile title=\(currentGameTitle) platform=\(platform.rawValue) romHash=\(currentROMHash)")
            frameAnalysisCoordinator = nil
            gameplayAnalysisSnapshot = nil
            activePlayInsightsGame = nil
            return
        }

        activePlayInsightsGame = PlayInsightsSupportedGame(profileID: profile.id)
        latestPlayInsightsLiveSample = nil
        lastPublishedPlayInsightsPayload = [:]
        lastPublishedPlayInsightsLocationSummary = nil
        sessionDeathEvents = 0
        sessionDamageEvents = 0

        GameplayAnalysisLogger.session(
            "configured profile=\(profile.id) title=\(currentGameTitle) platform=\(platform.rawValue) romHash=\(currentROMHash)"
        )
        frameAnalysisCoordinator = FrameAnalysisCoordinator(profile: profile) { [weak self] events, snapshot in
            guard let self else { return }
            guard self.isRunning else { return }
            self.gameplayAnalysisSnapshot = snapshot
            self.refreshPlayInsightsLiveSnapshotIfNeeded(with: snapshot)
            self.sessionDeathEvents += events.filter { $0 == .deathDetected }.count
            self.sessionDamageEvents += events.filter { $0 == .damageLight || $0 == .damageHeavy }.count
            guard self.hpDeathDetectionEnabled else { return }
            for event in events {
                HapticManager.shared.gameplayEvent(event)
            }
        }
        frameAnalysisCoordinator?.setLaunchInfo(platform: platform, gameTitle: currentGameTitle, romHash: currentROMHash)
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
        if let supportedGame = activePlayInsightsGame {
            let payload = latestPlayInsightsLiveSample.map {
                GameSpecificTelemetrySnapshot(
                    gameId: currentROMHash,
                    timestamp: endedAt,
                    payloadType: supportedGame.profileID,
                    payloadJson: $0.contextValues
                )
            }
            PlayInsightsStore.shared.recordSession(
                .init(
                    gameId: currentROMHash,
                    gameTitle: resolvedTitle,
                    system: resolvedSystem,
                    supportedGame: supportedGame,
                    startedAt: startedAt,
                    endedAt: endedAt,
                    durationSeconds: elapsed,
                    deaths: sessionDeathEvents,
                    damageEvents: sessionDamageEvents,
                    snapshot: payload,
                    latestLocationSummary: gameplayAnalysisSnapshot?.locationDebugSummary
                )
            )
        }
        NotificationCenter.default.post(name: .romLibraryDidChange, object: nil)
        if let firstUnlock = unlocks.first {
            latestUnlockedAchievement = firstUnlock
            if isRunning && !isPaused {
                statusMessage = "🏆 \(firstUnlock.title) unlocked"
            }
        }
    }

    private func refreshPlayInsightsLiveSnapshotIfNeeded(with snapshot: MarioAnalysisSnapshot) {
        guard let supportedGame = activePlayInsightsGame,
              !currentROMHash.isEmpty,
              let liveSample = latestPlayInsightsLiveSample else { return }

        let payload = liveSample.contextValues
        let locationSummary = snapshot.locationDebugSummary
        guard payload != lastPublishedPlayInsightsPayload || locationSummary != lastPublishedPlayInsightsLocationSummary else {
            return
        }

        lastPublishedPlayInsightsPayload = payload
        lastPublishedPlayInsightsLocationSummary = locationSummary

        PlayInsightsStore.shared.refreshLiveSnapshot(
            .init(
                gameId: currentROMHash,
                gameTitle: currentGameTitle,
                system: currentPlatform?.rawValue.lowercased() ?? "",
                supportedGame: supportedGame,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: currentROMHash,
                    timestamp: snapshot.sampledAt,
                    payloadType: supportedGame.profileID,
                    payloadJson: payload
                ),
                latestLocationSummary: locationSummary
            )
        )
        NotificationCenter.default.post(name: .romLibraryDidChange, object: nil)
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

    private func currentLiveMemorySample() -> MarioLiveMemorySample? {
        guard let platform = currentPlatform,
              let profile = MarioGameProfile.activeProfile(
                  title: currentGameTitle,
                  platform: platform,
                  romHash: currentROMHash
              ),
              let liveMemory = profile.liveMemory else {
            return nil
        }

        if platform == .GBA, let gbaCore = activeCore as? GBACore {
            let sample = MarioLiveMemorySample(
                lives: gbaCore.readMemory8(at: liveMemory.livesAddress),
                powerUpState: gbaCore.readMemory8(at: liveMemory.powerUpAddress),
                gameplayState: gbaCore.readMemory8(at: liveMemory.gameplayStateAddress),
                invulnerabilityTimer: gbaCore.readMemory8(at: liveMemory.invulnerabilityTimerAddress),
                health: liveMemory.healthAddress16.flatMap { gbaCore.readMemory16(at: $0) },
                maxHealth: liveMemory.maxHealthAddress16.flatMap { gbaCore.readMemory16(at: $0) },
                gameMode: liveMemory.gameModeAddress.flatMap { gbaCore.readMemory8(at: $0) },
                contextValues: readContextValues(fields: liveMemory.contextFields) { field in
                    switch field.width {
                    case .u8:
                        return gbaCore.readMemory8(at: field.address).map(UInt16.init)
                    case .u16:
                        return gbaCore.readMemory16(at: field.address)
                    }
                }
            )
            latestPlayInsightsLiveSample = sample
            return sample
        }

        if (platform == .GB || platform == .GBC),
           let gbcCore = activeCore as? GBCore,
           liveMemory.livesAddress <= UInt32(UInt16.max),
           liveMemory.powerUpAddress <= UInt32(UInt16.max),
           liveMemory.gameplayStateAddress <= UInt32(UInt16.max),
           liveMemory.invulnerabilityTimerAddress <= UInt32(UInt16.max) {
            let sample = MarioLiveMemorySample(
                lives: gbcCore.readMemory8(at: UInt16(liveMemory.livesAddress)),
                powerUpState: gbcCore.readMemory8(at: UInt16(liveMemory.powerUpAddress)),
                gameplayState: gbcCore.readMemory8(at: UInt16(liveMemory.gameplayStateAddress)),
                invulnerabilityTimer: gbcCore.readMemory8(at: UInt16(liveMemory.invulnerabilityTimerAddress)),
                health: nil,
                maxHealth: nil,
                gameMode: nil,
                contextValues: readContextValues(fields: liveMemory.contextFields) { field in
                    guard field.address <= UInt32(UInt16.max) else { return nil }
                    switch field.width {
                    case .u8:
                        return gbcCore.readMemory8(at: UInt16(field.address)).map(UInt16.init)
                    case .u16:
                        let low = gbcCore.readMemory8(at: UInt16(field.address))
                        let high = field.address < UInt32(UInt16.max)
                            ? gbcCore.readMemory8(at: UInt16(field.address + 1))
                            : nil
                        guard let low, let high else { return nil }
                        return UInt16(low) | (UInt16(high) << 8)
                    }
                }
            )
            latestPlayInsightsLiveSample = sample
            return sample
        }

        GameplayAnalysisLogger.event("live-memory unsupported profile=\(profile.id) platform=\(platform.rawValue)")
        return nil
    }

    private func readContextValues(
        fields: [MarioLiveMemoryContextField],
        reader: (MarioLiveMemoryContextField) -> UInt16?
    ) -> [String: UInt16] {
        var values: [String: UInt16] = [:]
        for field in fields {
            if let value = reader(field) {
                values[field.key] = value
            }
        }
        return values
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
        let normalizedSpeed = max(1, speed)
        guard fastForwardSpeed != normalizedSpeed else {
            statusMessage = normalizedSpeed > 1 ? "Fast forward: \(normalizedSpeed)x" : "Fast forward off"
            return
        }

        fastForwardSpeed = normalizedSpeed
        updateFastForwardAudioState()
        statusMessage = normalizedSpeed > 1 ? "Fast forward: \(normalizedSpeed)x" : "Fast forward off"
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
        guard Self.shouldAutoResumeLaunchState(for: currentPlatform) else {
            NSLog("[StateLoadGuard] auto-resume skipped reason=nds_audio_guard slot=%d rom=%@", summary.slot, currentROMHash)
            return
        }
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

        guard let swappedData = swapRBChannels(in: snapshot.data, width: width, height: height, bytesPerRow: snapshot.bytesPerRow) else {
            return nil
        }
        
        var mutableData = swappedData
        let dataCount = mutableData.count
        let result = mutableData.withUnsafeMutableBytes { ptr -> Data? in
            guard let baseAddress = ptr.baseAddress else { return nil }
            let cfData = CFDataCreate(nil, baseAddress.assumingMemoryBound(to: UInt8.self), dataCount)
            guard let cfData = cfData, let provider = CGDataProvider(data: cfData) else { return nil }
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
                CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue)
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

            var uiImage = UIImage(cgImage: cgImage)
            
            if currentPlatform == .GBC {
                uiImage = applyGBCColorAdjustments(to: uiImage) ?? uiImage
            }

            return uiImage.jpegData(compressionQuality: 0.72)
        }
        
        return result
        #else
        return nil
        #endif
    }
    
    #if canImport(UIKit)
    private func swapRBChannels(in data: Data, width: Int, height: Int, bytesPerRow: Int) -> Data? {
        var result = Data(count: data.count)
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * bytesPerRow + x * 4
                guard offset + 3 < data.count else { break }
                
                // BGRA -> RGBA (swap R and B)
                let b = data[offset]
                let g = data[offset + 1]
                let r = data[offset + 2]
                let a = data[offset + 3]
                
                result[offset] = r
                result[offset + 1] = g
                result[offset + 2] = b
                result[offset + 3] = a
            }
        }
        
        return result
    }
    #endif
    
    #if canImport(UIKit)
    private func applyGBCColorAdjustments(to image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        guard let contrastFilter = CIFilter(name: "CIColorControls") else { return nil }
        contrastFilter.setValue(ciImage, forKey: kCIInputImageKey)
        contrastFilter.setValue(1.10, forKey: kCIInputContrastKey)
        contrastFilter.setValue(1.22, forKey: kCIInputSaturationKey)
        contrastFilter.setValue(0.72, forKey: kCIInputBrightnessKey)
        
        guard let contrastAdjusted = contrastFilter.outputImage else { return nil }
        
        guard let gammaFilter = CIFilter(name: "CIGamma") else { return nil }
        gammaFilter.setValue(contrastAdjusted, forKey: kCIInputImageKey)
        gammaFilter.setValue(1.86, forKey: "inputPower")
        
        guard let gammaAdjusted = gammaFilter.outputImage else { return nil }
        
        let context = CIContext()
        guard let cgOutput = context.createCGImage(gammaAdjusted, from: gammaAdjusted.extent) else { return nil }
        
        return UIImage(cgImage: cgOutput)
    }
    #endif

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
        emulatorSession?.setRenderFrameSkip(profile.frameSkip)
        let shouldEnablePostProcessing = Self.shouldEnablePostProcessing(
            for: profile,
            displayPlatform: activeDisplayPlatform
        )
        renderer.setPostProcessingEnabled(shouldEnablePostProcessing)
        if shouldEnablePostProcessing {
            applyDisplayColorAdjustments(for: activeDisplayPlatform)
        }
    }

    private func updateFastForwardAudioState() {
        guard let audioEngine else { return }
        if fastForwardSpeed > 1 {
            audioEngine.pause()
            audioEngine.quarantineAfterStateLoad(silenceMs: 0, fadeInMs: 0)
        } else if isRunning && !isPaused {
            audioEngine.quarantineAfterStateLoad(silenceMs: 60, fadeInMs: 90)
            audioEngine.resume()
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
            frameAnalysisCoordinator?.enqueue(
                frameBufferInfo: frameBufferInfo,
                timestamp: Date(),
                liveMemorySample: currentLiveMemorySample(),
                saveStateData: currentSaveStateData
            )
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
            guard fastForwardSpeed == 1 else { return }
            guard let samples = samples, !samples.isEmpty else { return }
            let normalizedInputRate = resolvedInputSampleRate(sampleRate)

            var outputSamples = samples
            let targetRate = Int(activeAudioSampleRate.rounded())
            if normalizedInputRate > 0, targetRate > 0, normalizedInputRate != targetRate {
                guard let resampled = resampleAudioLinearStreaming(
                    samples: samples,
                    fromRate: normalizedInputRate,
                    toRate: targetRate
                ) else {
                    return
                }
                outputSamples = resampled
            } else {
                resetAudioResamplerState()
            }

            if audioDebugPacketCount < 6 {
                audioDebugPacketCount += 1
                NSLog(
                    "[AudioFeed] packet=%d inputRate=%d targetRate=%d inputBytes=%d outputBytes=%d platform=%@",
                    audioDebugPacketCount,
                    normalizedInputRate,
                    targetRate,
                    samples.count,
                    outputSamples.count,
                    currentPlatform?.rawValue ?? "unknown"
                )
            }

            switch audioQuality {
            case 0:  // Sound First - resample to 48kHz for best quality
                break
            case 1:  // Balanced
                break
            case 2:  // Frame First
                break
            default:
                break
            }

            audioEngine?.updateAudioBuffer(outputSamples)
        }
    }

    private func resolvedInputSampleRate(_ sampleRate: Int) -> Int {
        let resolvedRate = Self.resolvedAudioSampleRate(sampleRate, platform: currentPlatform)
        guard currentPlatform == .NDS else { return resolvedRate }
        guard resolvedRate > 0 else { return resolvedRate }

        return resolvedRate
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

    private func audioMetrics(for samples: Data) -> (peak: Int, rms: Double, clippedSamples: Int, dcL: Double, dcR: Double) {
        guard samples.count >= 4 else { return (0, 0, 0, 0, 0) }
        let sampleCount = samples.count / 2
        guard sampleCount >= 2 else { return (0, 0, 0, 0, 0) }

        return samples.withUnsafeBytes { raw in
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: Int16.self) else {
                return (0, 0, 0, 0, 0)
            }
            var peak = 0
            var sumSquares: Double = 0
            var clippedSamples = 0
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
                sumSquares += Double(l * l)
                sumSquares += Double(r * r)
                if absL >= 32_000 { clippedSamples += 1 }
                if absR >= 32_000 { clippedSamples += 1 }
                sumL += Double(l)
                sumR += Double(r)
                frames += 1
                idx += 2
            }
            guard frames > 0 else { return (peak, 0, clippedSamples, 0, 0) }
            let channelSamples = Double(frames * 2)
            let rms = sqrt(sumSquares / max(1.0, channelSamples))
            return (peak, rms, clippedSamples, sumL / Double(frames), sumR / Double(frames))
        }
    }

}
