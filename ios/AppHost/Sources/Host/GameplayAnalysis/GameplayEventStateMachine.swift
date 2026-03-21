import Foundation

struct MarioRuntimeState: Sendable {
    var lastStablePlayerState: MarioPlayerState = .unknown
    var currentPlayerState: MarioPlayerState = .unknown
    var inDamageCooldown = false
    var damageCooldownUntil: Date?
    var inDeathSequence = false
    var deathConfirmed = false
    var lastDamageAt: Date?
    var lastDeathAt: Date?
    var lastEvent: GameplayEvent?
    var lastSeenPlayerAt: Date?
}

final class GameplayEventStateMachine {
    private let profile: MarioGameProfile
    private(set) var runtimeState = MarioRuntimeState()

    init(profile: MarioGameProfile) {
        self.profile = profile
    }

    func consume(_ observation: MarioObservation) -> (events: [GameplayEvent], snapshot: MarioAnalysisSnapshot) {
        let timestamp = observation.timestamp
        runtimeState.currentPlayerState = observation.playerState
        runtimeState.inDamageCooldown = runtimeState.damageCooldownUntil.map { $0 > timestamp } ?? false

        var emittedEvents: [GameplayEvent] = []
        let damageConf = damageConfidence(for: observation)
        let deathConf = deathConfidence(for: observation)
        
        let recentlySawPlayer = runtimeState.lastSeenPlayerAt.map { timestamp.timeIntervalSince($0) < 1.0 } ?? false
        _ = observation.playerBounds == nil && recentlySawPlayer && runtimeState.lastStablePlayerState != .unknown

        if shouldEmitDeath(observation: observation, deathConfidence: deathConf, timestamp: timestamp) {
            emittedEvents.append(.deathDetected)
            runtimeState.inDeathSequence = true
            runtimeState.deathConfirmed = true
            runtimeState.lastDeathAt = timestamp
            runtimeState.lastEvent = .deathDetected
        } else if shouldEmitDamage(observation: observation, damageConfidence: damageConf, timestamp: timestamp) {
            let damageEvent: GameplayEvent = damageIsHeavy(observation: observation) ? .damageHeavy : .damageLight
            emittedEvents.append(damageEvent)
            runtimeState.inDamageCooldown = true
            runtimeState.damageCooldownUntil = timestamp.addingTimeInterval(profile.damageCooldown)
            runtimeState.lastDamageAt = timestamp
            runtimeState.lastEvent = damageEvent
        } else if observation.gameplayPhase == .gameplayActive,
                  observation.playerStateConfidence >= 0.55,
                  stableStates.contains(observation.playerState) {
            runtimeState.inDeathSequence = false
            runtimeState.deathConfirmed = false
        }

        if observation.playerStateConfidence >= 0.65,
           stableStates.contains(observation.playerState),
           !runtimeState.inDeathSequence {
            runtimeState.lastStablePlayerState = observation.playerState
        }
        
        if observation.playerBounds != nil {
            runtimeState.lastSeenPlayerAt = timestamp
        }

        let remainingDamageCooldown = max(
            0,
            (runtimeState.damageCooldownUntil?.timeIntervalSince(timestamp) ?? 0)
        )
        let snapshot = MarioAnalysisSnapshot(
            profileName: profile.displayName,
            gameplayPhase: observation.gameplayPhase,
            playerState: observation.playerState,
            playerStateConfidence: observation.playerStateConfidence,
            damageConfidence: damageConf,
            deathConfidence: deathConf,
            blinkConfidence: observation.blinkConfidence,
            trackerBounds: observation.playerBounds,
            inDamageCooldown: runtimeState.inDamageCooldown,
            damageCooldownRemaining: remainingDamageCooldown,
            inDeathSequence: runtimeState.inDeathSequence,
            lastEvent: runtimeState.lastEvent,
            lastEventAt: runtimeState.lastEvent == .deathDetected ? runtimeState.lastDeathAt : runtimeState.lastDamageAt,
            memoryDebugSummary: observation.memoryDebugSummary,
            sampledAt: timestamp
        )
        return (emittedEvents, snapshot)
    }

    private func shouldEmitDamage(
        observation: MarioObservation,
        damageConfidence: Double,
        timestamp: Date
    ) -> Bool {
        guard observation.gameplayPhase == .gameplayActive else { return false }
        guard !runtimeState.inDeathSequence else { return false }
        guard (runtimeState.damageCooldownUntil?.timeIntervalSince(timestamp) ?? 0) <= 0 else { return false }
        // Increased threshold to reduce false positives - only trigger on clear damage events
        return damageConfidence >= 0.82
    }

    private func shouldEmitDeath(
        observation: MarioObservation,
        deathConfidence: Double,
        timestamp: Date
    ) -> Bool {
        guard (runtimeState.lastDeathAt?.addingTimeInterval(profile.deathCooldown).timeIntervalSince(timestamp) ?? 0) <= 0 else {
            return false
        }

        // Increased threshold to reduce false positives - only trigger on clear death events
        if deathConfidence >= 0.78 {
            return true
        }

        // Made sprite loss detection more strict to prevent false positives
        let recentlySawPlayer = runtimeState.lastSeenPlayerAt.map { timestamp.timeIntervalSince($0) < 0.6 } ?? false
        let spriteLost = observation.playerBounds == nil && recentlySawPlayer && runtimeState.lastStablePlayerState != .unknown
        let stateUnknown = observation.playerState == .unknown && recentlySawPlayer && runtimeState.lastStablePlayerState != .unknown && observation.gameplayPhase != .pausedMenu

        // Require both conditions to be true for sprite-based death detection
        return spriteLost && stateUnknown
    }

    private func damageConfidence(for observation: MarioObservation) -> Double {
        let downgradeScore: Double
        switch (runtimeState.lastStablePlayerState, observation.playerState) {
        case (.poweredUp, .superState), (.superState, .small), (.poweredUp, .small):
            downgradeScore = 0.92
        default:
            downgradeScore = 0
        }

        let hurtCombo = min(1.0, observation.hurtPoseConfidence * 0.5 + observation.blinkConfidence * 0.5)
        let stableScore = observation.playerStateConfidence * 0.15
        return max(downgradeScore, hurtCombo + stableScore)
    }

    private func damageIsHeavy(observation: MarioObservation) -> Bool {
        switch (runtimeState.lastStablePlayerState, observation.playerState) {
        case (.poweredUp, .small), (.poweredUp, .superState):
            return true
        case (.superState, .small):
            return true
        default:
            return false
        }
    }

    private func deathConfidence(for observation: MarioObservation) -> Double {
        let lethalFromSmall = runtimeState.lastStablePlayerState == .small ? 0.12 : 0
        let fadeContribution = (observation.gameplayPhase == .transition || observation.gameplayPhase == .deathSequence)
            ? observation.transitionFadeConfidence * 0.22
            : 0
        let combined = observation.deathAnimationConfidence * 0.48 +
            fadeContribution +
            observation.lifeLossScreenConfidence * 0.22 +
            lethalFromSmall
        return min(1.0, combined)
    }

    private var stableStates: Set<MarioPlayerState> {
        [.small, .superState, .poweredUp]
    }
}
