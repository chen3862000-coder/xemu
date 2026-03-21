import Foundation

/// Enhanced frame analysis coordinator using hybrid detection system
final class FrameAnalysisCoordinator {
    private let profile: MarioGameProfile
    private let queue: DispatchQueue
    private let hybridAnalyzer = HybridGameplayAnalyzer()
    private var stateMachine: GameplayEventStateMachine? // Make it optional
    private let onResult: @MainActor ([GameplayEvent], MarioAnalysisSnapshot) -> Void

    private var lastSampleAt: Date?
    private var isProcessing = false
    private var pendingFrame: (frame: FrameBufferInfo, timestamp: Date)?
    private var currentPlatform: Platform = .GB  // Default fallback
    private var currentGameTitle: String = ""
    private var currentROMHash: String = ""
    private var launchPlatform: Platform = .GB  // Preserve platform from launch
    private var launchGameTitle: String = ""  // Preserve game title from launch

    init(
        profile: MarioGameProfile,
        onResult: @escaping @MainActor ([GameplayEvent], MarioAnalysisSnapshot) -> Void
    ) {
        self.profile = profile
        self.queue = DispatchQueue(label: "com.xemu.gameplay-analysis.\(profile.id)", qos: .userInitiated)
        self.stateMachine = GameplayEventStateMachine(profile: profile)
        self.onResult = onResult
    }

    func enqueue(frameBufferInfo: FrameBufferInfo, timestamp: Date = Date()) {
        // Preserve launch values if not overridden
        let effectivePlatform = launchPlatform
        let effectiveGameTitle = launchGameTitle

        // Update current game info
        currentPlatform = effectivePlatform
        currentGameTitle = effectiveGameTitle

        if let lastSampleAt, timestamp.timeIntervalSince(lastSampleAt) < profile.minSampleInterval {
            return
        }
        lastSampleAt = timestamp

        if isProcessing {
            pendingFrame = (frameBufferInfo, timestamp)
            return
        }

        isProcessing = true
        process(frameBufferInfo, timestamp: timestamp)
    }

    func reset() {
        lastSampleAt = nil
        pendingFrame = nil
        isProcessing = false
        hybridAnalyzer.reset()
        stateMachine = GameplayEventStateMachine(profile: profile) // Reinitialize state machine with profile
        print("🔄 FrameAnalysisCoordinator reset for new session")
    }

    func updateProfile(_ newProfile: MarioGameProfile) {
        print("🔄 Profile update requested to: \(newProfile.displayName)")
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

    private func process(_ frameBufferInfo: FrameBufferInfo, timestamp: Date) {
        queue.async { [weak self] in
            guard let self, let stateMachine = self.stateMachine else { return }

            // Use hybrid analysis to get gameplay events
            let hybridResult = self.hybridAnalyzer.analyze(
                frameBufferInfo: frameBufferInfo,
                saveStateData: nil, // Save state tracking not yet implemented
                platform: launchPlatform, // Use preserved platform
                gameTitle: launchGameTitle // Use preserved game title
            )

            // Convert hybrid events to MarioObservation for state machine
            let marioObservation = self.createMarioObservation(
                from: hybridResult,
                frameBufferInfo: frameBufferInfo,
                timestamp: timestamp
            )

            // Process through existing state machine
            guard let stateMachine = self.stateMachine else {
                // If state machine not available, skip processing
                return
            }

            let (events, snapshot) = stateMachine.consume(marioObservation)

            DispatchQueue.main.async {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.onResult(events, snapshot)
                    self.logDetectionResults(hybridResult, events: events)
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
        return MarioObservation(
            playerState: inferPlayerState(from: hybridResult.events),
            playerStateConfidence: hybridResult.confidence,
            blinkConfidence: 0.0,
            hurtPoseConfidence: hybridResult.events.contains(.damageHeavy) ? hybridResult.confidence : 0.0,
            deathAnimationConfidence: hybridResult.events.contains(.deathDetected) ? hybridResult.confidence : 0.0,
            transitionFadeConfidence: 0.0,
            lifeLossScreenConfidence: 0.0,
            gameplayPhase: .gameplayActive,
            playerBounds: nil,
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

    private func logDetectionResults(_ result: HybridAnalysisResult, events: [GameplayEvent]) {
        let detectionMethod: String
        switch result.detectionMethod {
        case .memory:
            detectionMethod = "🧠 MEMORY (95-99%)"
        case .pattern:
            detectionMethod = "🔍 PATTERN (80-85%)"
        case .vision:
            detectionMethod = "👁️ VISION (60-70%)"
        case .unknown:
            detectionMethod = "❓ UNKNOWN"
        }

        let eventsString = events.isEmpty ? "none" : events.map { "\($0)" }.joined(separator: ", ")

        print("🎮 Gameplay Analysis:")
        print("   Method: \(detectionMethod)")
        print("   Confidence: \(String(format: "%.1f%%", result.confidence * 100))")
        print("   Events: \(eventsString)")
        print("   Performance: \(result.performanceMetrics)")

        if result.confidence < 0.7 {
            print("⚠️ Low confidence detection - may need address discovery")
        }
    }

    private func finishProcessing() {
        if let pendingFrame {
            self.pendingFrame = nil
            process(pendingFrame.frame, timestamp: pendingFrame.timestamp)
            return
        }
        isProcessing = false
    }

    func setLaunchInfo(platform: Platform, gameTitle: String) {
        launchPlatform = platform
        launchGameTitle = gameTitle
        print("🎮 Launch info preserved: Platform=\(platform), Title='\(gameTitle)')")
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
