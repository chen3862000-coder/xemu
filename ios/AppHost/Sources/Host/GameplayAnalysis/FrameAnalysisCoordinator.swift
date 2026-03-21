import Foundation

/// Enhanced frame analysis coordinator using hybrid detection system
final class FrameAnalysisCoordinator {
    private let profile: MarioGameProfile
    private let queue: DispatchQueue
    private let hybridAnalyzer = HybridGameplayAnalyzer()
    private var stateMachine: GameplayEventStateMachine?
    private let onResult: @MainActor ([GameplayEvent], MarioAnalysisSnapshot) -> Void

    private var lastSampleAt: Date?
    private var isProcessing = false
    private var pendingFrame: (frame: FrameBufferInfo, timestamp: Date, liveMemorySample: MarioLiveMemorySample?, saveStateData: Data?)?
    private var launchPlatform: Platform = .GB
    private var launchGameTitle: String = ""
    private var launchROMHash: String = ""

    init(
        profile: MarioGameProfile,
        onResult: @escaping @MainActor ([GameplayEvent], MarioAnalysisSnapshot) -> Void
    ) {
        self.profile = profile
        self.queue = DispatchQueue(label: "com.xemu.gameplay-analysis.\(profile.id)", qos: .userInitiated)
        self.stateMachine = GameplayEventStateMachine(profile: profile)
        self.onResult = onResult
    }

    func enqueue(
        frameBufferInfo: FrameBufferInfo,
        timestamp: Date = Date(),
        liveMemorySample: MarioLiveMemorySample? = nil,
        saveStateData: Data? = nil
    ) {
        if let lastSampleAt, timestamp.timeIntervalSince(lastSampleAt) < profile.minSampleInterval {
            return
        }
        lastSampleAt = timestamp

        if isProcessing {
            pendingFrame = (frameBufferInfo, timestamp, liveMemorySample, saveStateData)
            return
        }

        isProcessing = true
        process(frameBufferInfo, timestamp: timestamp, liveMemorySample: liveMemorySample, saveStateData: saveStateData)
    }

    func reset() {
        lastSampleAt = nil
        pendingFrame = nil
        isProcessing = false
        hybridAnalyzer.reset()
        stateMachine = GameplayEventStateMachine(profile: profile)
    }

    func updateProfile(_ newProfile: MarioGameProfile) {
        _ = newProfile
    }

    func getDetectionStatistics() -> DetectionStatistics {
        return DetectionStatistics(
            lastDetectionMethod: .unknown,
            confidenceThreshold: 0.75,
            totalAnalyses: 0,
            memoryAnalyses: 0,
            patternAnalyses: 0,
            visionAnalyses: 0
        )
    }

    private func process(
        _ frameBufferInfo: FrameBufferInfo,
        timestamp: Date,
        liveMemorySample: MarioLiveMemorySample?,
        saveStateData: Data?
    ) {
        queue.async { [weak self] in
            guard let self, let stateMachine = self.stateMachine else { return }

            let hybridResult = self.hybridAnalyzer.analyze(
                frameBufferInfo: frameBufferInfo,
                liveMemorySample: liveMemorySample,
                profile: self.profile,
                saveStateData: saveStateData,
                platform: self.launchPlatform,
                gameTitle: self.launchGameTitle,
                romHash: self.launchROMHash
            )

            let marioObservation = self.createMarioObservation(
                from: hybridResult,
                frameBufferInfo: frameBufferInfo,
                timestamp: timestamp
            )

            let (events, snapshot) = stateMachine.consume(marioObservation)

            if !events.isEmpty {
                let eventNames = events.map(\.rawValue).joined(separator: ",")
                GameplayAnalysisLogger.event(
                    """
                    emitted=\(eventNames) profile=\(self.profile.id) phase=\(snapshot.gameplayPhase.rawValue) \
                    state=\(snapshot.playerState.rawValue) damage=\(String(format: "%.2f", snapshot.damageConfidence)) \
                    death=\(String(format: "%.2f", snapshot.deathConfidence))
                    """
                )
            }

            DispatchQueue.main.async {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.onResult(events, snapshot)
                    self.finishProcessing()
                }
            }
        }
    }

    private func createMarioObservation(
        from hybridResult: HybridAnalysisResult,
        frameBufferInfo: FrameBufferInfo,
        timestamp: Date
    ) -> MarioObservation {
        let hasDamageEvent = hybridResult.events.contains(.damageHeavy) || hybridResult.events.contains(.damageLight)
        let hasDeathEvent = hybridResult.events.contains(.deathDetected)
        let memoryBacked = hybridResult.detectionMethod == .memory && hybridResult.memoryObservation != nil

        return MarioObservation(
            playerState: hybridResult.memoryObservation?.playerState ?? inferPlayerState(from: hybridResult.events),
            playerStateConfidence: max(
                hybridResult.confidence,
                hybridResult.memoryObservation != nil || hasDamageEvent || hasDeathEvent ? 0.9 : 0.0
            ),
            blinkConfidence: hybridResult.memoryObservation?.blinkConfidence ?? (hasDamageEvent ? 0.9 : 0.0),
            hurtPoseConfidence: hasDamageEvent ? (memoryBacked ? 1.0 : 0.95) : 0.0,
            deathAnimationConfidence: hasDeathEvent ? (memoryBacked ? 1.0 : 0.95) : 0.0,
            transitionFadeConfidence: hasDeathEvent ? (memoryBacked ? 1.0 : 0.8) : 0.0,
            lifeLossScreenConfidence: hasDeathEvent ? (memoryBacked ? 1.0 : 0.8) : 0.0,
            gameplayPhase: hybridResult.memoryObservation?.gameplayPhase ?? (hasDeathEvent ? .transition : .gameplayActive),
            playerBounds: nil,
            memoryDebugSummary: hybridResult.memoryObservation?.debugSummary,
            timestamp: timestamp
        )
    }

    private func inferPlayerState(from events: [GameplayEvent]) -> MarioPlayerState {
        if events.contains(.deathDetected) {
            return .dead
        } else if events.contains(.damageHeavy) {
            return .hurt
        } else if events.contains(.damageLight) {
            return .hurt
        } else if events.contains(.powerUpCollected) {
            return .poweredUp
        } else if events.contains(.levelCompleted) {
            return .superState
        }

        return .unknown
    }

    private func finishProcessing() {
        if let pendingFrame {
            self.pendingFrame = nil
            process(
                pendingFrame.frame,
                timestamp: pendingFrame.timestamp,
                liveMemorySample: pendingFrame.liveMemorySample,
                saveStateData: pendingFrame.saveStateData
            )
            return
        }
        isProcessing = false
    }

    func setLaunchInfo(platform: Platform, gameTitle: String, romHash: String) {
        launchPlatform = platform
        launchGameTitle = gameTitle
        launchROMHash = romHash
    }
}

struct DetectionStatistics: Sendable {
    let lastDetectionMethod: DetectionMethod
    let confidenceThreshold: Double
    let totalAnalyses: Int
    let memoryAnalyses: Int
    let patternAnalyses: Int
    let visionAnalyses: Int
}
