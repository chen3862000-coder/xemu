import Foundation

enum PlayInsightsSupportedGame: String, CaseIterable, Codable, Sendable {
    case superMarioAdvance2
    case superMarioAdvance4
    case dragonBallAdvancedAdventure
    case onePiece
    case kingdomHeartsChainOfMemories
    case zeldaMinishCap
    case kirbyNightmareInDreamLand
    case kirbyAmazingMirror
    case goldenSun
    case goldenSunTheLostAge
    case fireEmblemTheSacredStones
    case megaManZero
    case metroidFusion
    case metroidZeroMission
    case castlevaniaAriaOfSorrow
    case castlevaniaCircleOfTheMoon
    case castlevaniaHarmonyOfDissonance

    init?(profileID: String) {
        switch profileID {
        case MarioGameProfile.sma2SuperMarioWorld.id:
            self = .superMarioAdvance2
        case MarioGameProfile.sma4SuperMarioBros3.id:
            self = .superMarioAdvance4
        case MarioGameProfile.dragonBallAdvancedAdventure.id:
            self = .dragonBallAdvancedAdventure
        case MarioGameProfile.onePiece.id:
            self = .onePiece
        case MarioGameProfile.kingdomHeartsChainOfMemories.id:
            self = .kingdomHeartsChainOfMemories
        case MarioGameProfile.zeldaMinishCap.id:
            self = .zeldaMinishCap
        case MarioGameProfile.kirbyNightmareInDreamLand.id:
            self = .kirbyNightmareInDreamLand
        case MarioGameProfile.kirbyAmazingMirror.id:
            self = .kirbyAmazingMirror
        case MarioGameProfile.goldenSun.id:
            self = .goldenSun
        case MarioGameProfile.goldenSunTheLostAge.id:
            self = .goldenSunTheLostAge
        case MarioGameProfile.fireEmblemTheSacredStones.id:
            self = .fireEmblemTheSacredStones
        case MarioGameProfile.megaManZero.id:
            self = .megaManZero
        case MarioGameProfile.metroidFusion.id:
            self = .metroidFusion
        case MarioGameProfile.metroidZeroMission.id:
            self = .metroidZeroMission
        case MarioGameProfile.castlevaniaAriaOfSorrow.id:
            self = .castlevaniaAriaOfSorrow
        case MarioGameProfile.castlevaniaCircleOfTheMoon.id:
            self = .castlevaniaCircleOfTheMoon
        case MarioGameProfile.castlevaniaHarmonyOfDissonance.id:
            self = .castlevaniaHarmonyOfDissonance
        default:
            return nil
        }
    }

    var profileID: String {
        switch self {
        case .superMarioAdvance2: return MarioGameProfile.sma2SuperMarioWorld.id
        case .superMarioAdvance4: return MarioGameProfile.sma4SuperMarioBros3.id
        case .dragonBallAdvancedAdventure: return MarioGameProfile.dragonBallAdvancedAdventure.id
        case .onePiece: return MarioGameProfile.onePiece.id
        case .kingdomHeartsChainOfMemories: return MarioGameProfile.kingdomHeartsChainOfMemories.id
        case .zeldaMinishCap: return MarioGameProfile.zeldaMinishCap.id
        case .kirbyNightmareInDreamLand: return MarioGameProfile.kirbyNightmareInDreamLand.id
        case .kirbyAmazingMirror: return MarioGameProfile.kirbyAmazingMirror.id
        case .goldenSun: return MarioGameProfile.goldenSun.id
        case .goldenSunTheLostAge: return MarioGameProfile.goldenSunTheLostAge.id
        case .fireEmblemTheSacredStones: return MarioGameProfile.fireEmblemTheSacredStones.id
        case .megaManZero: return MarioGameProfile.megaManZero.id
        case .metroidFusion: return MarioGameProfile.metroidFusion.id
        case .metroidZeroMission: return MarioGameProfile.metroidZeroMission.id
        case .castlevaniaAriaOfSorrow: return MarioGameProfile.castlevaniaAriaOfSorrow.id
        case .castlevaniaCircleOfTheMoon: return MarioGameProfile.castlevaniaCircleOfTheMoon.id
        case .castlevaniaHarmonyOfDissonance: return MarioGameProfile.castlevaniaHarmonyOfDissonance.id
        }
    }

    var supportsEventMetrics: Bool {
        switch self {
        case .superMarioAdvance2, .superMarioAdvance4, .dragonBallAdvancedAdventure, .onePiece, .kingdomHeartsChainOfMemories, .zeldaMinishCap, .kirbyNightmareInDreamLand, .kirbyAmazingMirror, .fireEmblemTheSacredStones, .megaManZero, .metroidFusion, .metroidZeroMission, .castlevaniaAriaOfSorrow:
            return true
        case .goldenSun, .goldenSunTheLostAge, .castlevaniaCircleOfTheMoon, .castlevaniaHarmonyOfDissonance:
            return false
        }
    }

    var prefersExplorationLanguage: Bool {
        switch self {
        case .metroidFusion, .metroidZeroMission, .zeldaMinishCap, .castlevaniaAriaOfSorrow, .castlevaniaCircleOfTheMoon, .castlevaniaHarmonyOfDissonance:
            return true
        case .superMarioAdvance2, .superMarioAdvance4, .dragonBallAdvancedAdventure, .onePiece, .kingdomHeartsChainOfMemories, .kirbyNightmareInDreamLand, .kirbyAmazingMirror, .fireEmblemTheSacredStones, .megaManZero:
            return false
        case .goldenSun, .goldenSunTheLostAge:
            return true
        }
    }
}

struct GameSpecificTelemetrySnapshot: Codable, Equatable, Sendable {
    var gameId: String
    var timestamp: Date
    var payloadType: String
    var payloadJson: [String: UInt16]
}

struct GameEventStatsSummary: Codable, Equatable, Sendable {
    var gameId: String
    var totalDeaths: Int?
    var totalDamageEvents: Int?
    var currentSessionDeaths: Int?
    var currentSessionDamageEvents: Int?
    var lastSessionDeaths: Int?
    var lastSessionDamageEvents: Int?
    var bestSessionDeaths: Int?
    var averageDamagePerSession: Double?
    var lastPlayedAt: Date?
}

struct GamePlayInsightsSummary: Codable, Equatable, Sendable {
    var gameId: String
    var playInsightsEnabled: Bool
    var currentRunEnabled: Bool

    var deathsPrimaryValue: String?
    var deathsSecondaryLine1: String?
    var deathsSecondaryLine2: String?
    var deathsChip: String?

    var damagePrimaryValue: String?
    var damageSecondaryLine1: String?
    var damageSecondaryLine2: String?
    var damageChip: String?

    var progressPrimaryValue: String?
    var progressSecondaryValue: String?

    var performanceInsightText: String?
    var playStyleTitle: String?
    var playStyleBullet1: String?
    var playStyleBullet2: String?

    var currentRunPrimary: String?
    var currentRunSecondary: String?
    var currentRunBadge: String?

    var lastPlayedAt: Date?
    var updatedAt: Date
}

struct GlobalPlaySummary: Equatable, Sendable {
    var totalDeaths: Int
    var totalDamageEvents: Int
    var supportedGamesPlayed: Int
    var heroSummaryText: String
    var activeRuns: [ActiveRunItem]
    var hardestGames: [HardestGameItem]
    var supportedGameCards: [SupportedGameCardItem]
    var updatedAt: Date
}

struct ActiveRunItem: Identifiable, Equatable, Sendable {
    var id: String { gameId }
    var gameId: String
    var gameTitle: String
    var primaryText: String
    var secondaryText: String
    var badgeText: String?
    var lastPlayedAt: Date?
}

struct HardestGameItem: Identifiable, Equatable, Sendable {
    var id: String { gameId }
    var gameId: String
    var gameTitle: String
    var primaryMetricText: String
    var badgeText: String
    var rank: Int
}

struct SupportedGameCardItem: Identifiable, Equatable, Sendable {
    var id: String { gameId }
    var gameId: String
    var gameTitle: String
    var progressLine: String
    var performanceLine: String
    var insightLine: String
    var lastPlayedAt: Date?
}

struct PlayStyleSummary: Equatable, Sendable {
    let title: String
    let bullet1: String?
    let bullet2: String?
}

struct ProgressSummary: Equatable, Sendable {
    let primary: String
    let secondary: String
}

struct CurrentRunSummary: Equatable, Sendable {
    let primary: String
    let secondary: String
    let badge: String?
}

struct ContinuePlayingSmartSummary: Equatable, Sendable {
    let primaryProgressLine: String
    let supportingStateLine: String?
    let badgeText: String?
}

struct PlayInsightsSessionRecord: Codable, Equatable, Sendable {
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var deaths: Int
    var damageEvents: Int
}

struct PlayInsightsStoredGameRecord: Codable, Equatable, Sendable {
    var gameId: String
    var gameTitle: String
    var system: String
    var supportedGame: PlayInsightsSupportedGame
    var eventStats: GameEventStatsSummary
    var sessions: [PlayInsightsSessionRecord]
    var latestSnapshot: GameSpecificTelemetrySnapshot?
    var latestLocationSummary: String?
    var updatedAt: Date
}
