import Foundation

enum Platform: String, Codable, CaseIterable {
    case nes = "NES"
    case gb = "GB"
    case gba = "GBA"
    case genesis = "GENESIS"
    case nds = "NDS"
    case ps1 = "PS1"
    case ps2 = "PS2"
    case threeDS = "3DS"
}

enum Tier: String, Codable {
    case stable
    case experimental
    case unknown
}

enum CompletionState: String, Codable {
    case notStarted = "NotStarted"
    case inProgress = "InProgress"
    case completed = "Completed"
    case mastered = "Mastered"
}

enum SessionMode: String, Codable {
    case singlePlayer = "SinglePlayer"
    case legit = "Legit"
    case multiplayerHost = "MultiplayerHost"
    case multiplayerGuest = "MultiplayerGuest"
}

enum SessionVerdict: String, Codable {
    case pending = "Pending"
    case valid = "Valid"
    case invalid = "Invalid"
    case flagged = "Flagged"
}

enum EntitlementStatus: String, Codable {
    case active = "Active"
    case revoked = "Revoked"
    case refunded = "Refunded"
    case expired = "Expired"
}

enum ProductCode: String, Codable {
    case removeAds = "REMOVE_ADS"
    case experimentalPack = "EXPERIMENTAL_PACK"
    case proBundle = "PRO_BUNDLE"
}

enum HardwareClass: String, Codable {
    case tier1 = "Tier1"
    case tier2 = "Tier2"
    case tier3 = "Tier3"
    case unsupported = "Unsupported"
}

enum Region: String, Codable {
    case na = "NA"
    case eu = "EU"
    case apac = "APAC"
}

enum DisconnectReason: String, Codable {
    case none = "None"
    case timeout = "Timeout"
    case cheatSuspected = "CheatSuspected"
    case quit = "Quit"
}

enum EnforcementAction: String, Codable {
    case none = "None"
    case shadowBan = "ShadowBan"
    case leaderboardBan = "LeaderboardBan"
}

struct AchievementTrigger: Codable, Identifiable {
    let id: UUID
    let achievementId: UUID
    let triggeredAt: Date
    let metadata: [String: String]
}

struct DeviceBinding: Codable, Identifiable {
    let id: UUID
    let deviceName: String
    let deviceId: UUID
    let boundAt: Date
}
