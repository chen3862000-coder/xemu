import Foundation
import CoreGraphics

enum GameplayEvent: String, Equatable, Sendable {
    case damageLight
    case damageHeavy
    case deathDetected
    case powerUpCollected
    case coinCollected
    case levelCompleted
    case lifeLost
    case checkpointReached
    case enemyStomped
    case lowHealthWarning
}

enum MarioPlayerState: String, Equatable, Sendable {
    case small
    case superState
    case poweredUp
    case hurt
    case invulnerableBlink
    case dead
    case unknown
}

enum MarioGameplayPhase: String, Equatable, Sendable {
    case gameplayActive
    case transition
    case pausedMenu
    case deathSequence
    case unknown
}

struct MarioObservation: Sendable {
    let playerState: MarioPlayerState
    let playerStateConfidence: Double
    let blinkConfidence: Double
    let hurtPoseConfidence: Double
    let deathAnimationConfidence: Double
    let transitionFadeConfidence: Double
    let lifeLossScreenConfidence: Double
    let gameplayPhase: MarioGameplayPhase
    let playerBounds: CGRect?
    let memoryDebugSummary: String?
    let timestamp: Date
}

struct MarioAnalysisSnapshot: Sendable {
    let profileName: String
    let gameplayPhase: MarioGameplayPhase
    let playerState: MarioPlayerState
    let playerStateConfidence: Double
    let damageConfidence: Double
    let deathConfidence: Double
    let blinkConfidence: Double
    let trackerBounds: CGRect?
    let inDamageCooldown: Bool
    let damageCooldownRemaining: TimeInterval
    let inDeathSequence: Bool
    let lastEvent: GameplayEvent?
    let lastEventAt: Date?
    let memoryDebugSummary: String?
    let sampledAt: Date
}

struct MarioLiveMemorySample: Sendable {
    let lives: UInt8?
    let powerUpState: UInt8?
    let gameplayState: UInt8?
    let invulnerabilityTimer: UInt8?
}
