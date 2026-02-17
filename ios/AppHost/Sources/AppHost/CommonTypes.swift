import Foundation

public enum Platform: String, Codable, Equatable {
    case NES = "nes"
    case GB = "gb"
    case GBA = "gba"
    case GENESIS = "genesis"
    case NDS = "nds"
    case PS1 = "ps1"
    case PS2 = "ps2"
    case _3DS = "3ds"
}

public enum Tier: String, Codable, Equatable {
    case stable = "stable"
    case experimental = "experimental"
    case unknown = "unknown"
}

public enum CompletionState: String, Codable, Equatable {
    case NotStarted = "NotStarted"
    case InProgress = "InProgress"
    case Completed = "Completed"
    case Mastered = "Mastered"
}

public enum SessionMode: String, Codable, Equatable {
    case SinglePlayer = "SinglePlayer"
    case Legit = "Legit"
    case MultiplayerHost = "MultiplayerHost"
    case MultiplayerGuest = "MultiplayerGuest"
}

public enum SessionVerdict: String, Codable, Equatable {
    case Pending = "Pending"
    case Valid = "Valid"
    case Invalid = "Invalid"
    case Flagged = "Flagged"
}

public enum EntitlementStatus: String, Codable, Equatable {
    case Active = "Active"
    case Revoked = "Revoked"
    case Refunded = "Refunded"
    case Expired = "Expired"
}

public enum ProductCode: String, Codable, Equatable {
    case REMOVE_ADS = "REMOVE_ADS"
    case EXPERIMENTAL_PACK = "EXPERIMENTAL_PACK"
    case PRO_BUNDLE = "PRO_BUNDLE"
}

public enum HardwareClass: String, Codable, Equatable {
    case Tier1 = "Tier1"
    case Tier2 = "Tier2"
    case Tier3 = "Tier3"
    case Unsupported = "Unsupported"
}

public struct AchievementTrigger: Codable, Equatable {
    public let achievementId: UUID
    public let triggeredAt: Date
    public let metadata: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case achievementId
        case triggeredAt
        case metadata
    }
    
    public init(achievementId: UUID, triggeredAt: Date, metadata: [String: Any]) {
        self.achievementId = achievementId
        self.triggeredAt = triggeredAt
        self.metadata = metadata
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        achievementId = try container.decode(UUID.self, forKey: .achievementId)
        triggeredAt = try container.decode(Date.self, forKey: .triggeredAt)
        let anyCodableDict = try container.decode([String: AnyCodable].self, forKey: .metadata)
        metadata = anyCodableDict.mapValues { $0.value }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(achievementId, forKey: .achievementId)
        try container.encode(triggeredAt, forKey: .triggeredAt)
        try container.encode(metadata.mapValues { AnyCodable($0) }, forKey: .metadata)
    }
    
    public static func == (lhs: AchievementTrigger, rhs: AchievementTrigger) -> Bool {
        return lhs.achievementId == rhs.achievementId &&
               lhs.triggeredAt == rhs.triggeredAt
    }
}

private struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue
        } else if let doubleValue = try? container.decode(Double.self) {
            value = doubleValue
        } else if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else if let dictValue = try? container.decode([String: AnyCodable].self) {
            value = dictValue.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let stringValue as String:
            try container.encode(stringValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
        }
    }
}

public struct DeviceBinding: Codable, Equatable {
    public let deviceName: String
    public let deviceId: UUID
    public let boundAt: Date
    
    public init(deviceName: String, deviceId: UUID, boundAt: Date) {
        self.deviceName = deviceName
        self.deviceId = deviceId
        self.boundAt = boundAt
    }
}
