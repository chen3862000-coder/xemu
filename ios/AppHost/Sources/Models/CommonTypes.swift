import Foundation

public enum Platform: String, Codable, CaseIterable, Sendable {
    case NES = "NES"
    case GB = "GB"
    case GBC = "GBC"
    case GBA = "GBA"
    case GENESIS = "GENESIS"
    case NDS = "NDS"
    case PS1 = "PS1"
    case PS2 = "PS2"
    case _3DS = "3DS"
}

public enum Tier: String, Codable {
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

public enum EntitlementStatus: String, Codable {
    case active = "Active"
    case inactive = "Inactive"
    case revoked = "Revoked"
    case refunded = "Refunded"
    case expired = "Expired"
    case unknown = "Unknown"
}

public enum ProductCode: String, Codable, Sendable {
    case removeAds = "REMOVE_ADS"
    case experimentalPack = "EXPERIMENTAL_PACK"
    case proBundle = "PRO_BUNDLE"
}

public enum HardwareClass: String, Codable, Comparable {
    case tier1 = "Tier1"
    case tier2 = "Tier2"
    case tier3 = "Tier3"
    case unsupported = "Unsupported"
    
    public static func < (lhs: HardwareClass, rhs: HardwareClass) -> Bool {
        let order: [HardwareClass] = [.unsupported, .tier1, .tier2, .tier3]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
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

public protocol InputRouting: Sendable {
    nonisolated func route(_ event: InputEvent)
    nonisolated func addListener(_ listener: @escaping @Sendable (InputEvent) -> Void) -> UUID
}

public struct InputEvent: Codable, Sendable, Equatable {
    public let button: ControllerButton
    public let isPressed: Bool
    public let timestamp: Date

    public init(button: ControllerButton, isPressed: Bool, timestamp: Date) {
        self.button = button
        self.isPressed = isPressed
        self.timestamp = timestamp
    }
}

enum InputEventType: String, Codable {
    case buttonPress
    case axisMove
    case triggerPull
}

public enum ControllerButton: String, Codable, Sendable {
    case a
    case b
    case x
    case y
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case leftShoulder
    case rightShoulder
    case leftTrigger
    case rightTrigger
    case l
    case r
    case start
    case select
    case menu
    case triggerLeft
    case triggerRight
    case leftStick
    case rightStick
    case home
}