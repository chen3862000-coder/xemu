import Foundation
import os.log

struct LogEntry: Codable {
    let sessionId: UUID
    let userId: UUID
    let deviceId: UUID
    let type: String
    let timestamp: Date
    let metadata: [String: Any]

    enum CodingKeys: String, CodingKey {
        case sessionId, userId, deviceId, type, timestamp, metadata
    }

    init(sessionId: UUID, userId: UUID, deviceId: UUID, type: String, timestamp: Date, metadata: [String: Any]) {
        self.sessionId = sessionId
        self.userId = userId
        self.deviceId = deviceId
        self.type = type
        self.timestamp = timestamp
        self.metadata = metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try container.decode(UUID.self, forKey: .sessionId)
        userId = try container.decode(UUID.self, forKey: .userId)
        deviceId = try container.decode(UUID.self, forKey: .deviceId)
        type = try container.decode(String.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)

        if let metadataData = try? container.decode([String: String].self, forKey: .metadata) {
            metadata = metadataData
        } else {
            metadata = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionId, forKey: .sessionId)
        try container.encode(userId, forKey: .userId)
        try container.encode(deviceId, forKey: .deviceId)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)

        let stringMetadata = metadata.compactMapValues { $0 as? String }
        try container.encode(stringMetadata, forKey: .metadata)
    }
}

@MainActor
final class StableSessionTracker {
    public enum SessionError: LocalizedError {
        case noActiveSession
        case sessionAlreadyStarted
        case invalidParameters

        public var errorDescription: String? {
            switch self {
            case .noActiveSession:
                return "No active session"
            case .sessionAlreadyStarted:
                return "Session already started"
            case .invalidParameters:
                return "Invalid parameters"
            }
        }
    }

    static let shared = StableSessionTracker()

    private let logger = Logger(subsystem: "com.xemu.app", category: "SessionTracker")
    private var sessionId: UUID?
    internal var sessionIdAccessor: UUID? { sessionId }
    internal var sessionStartTime: Date?
    internal var heartbeatCount = 0
    internal var isTracking = false
    internal var currentMode: SessionMode = .singlePlayer
    internal var completionState: CompletionState = .completed
    private var crashCount = 0
    private var errorCount = 0
    private let maxCrashesBeforeWarning = 5
    private let maxErrorsBeforeWarning = 10
    private var totalSessionDuration: TimeInterval = 0

    static let testInstance: StableSessionTracker = {
        let tracker = StableSessionTracker()
        return tracker
    }()

    internal init() {}

    func recordCrash() {
        crashCount += 1

        if crashCount >= maxCrashesBeforeWarning {
            let count = crashCount
            logger.error("Crash threshold exceeded: \(count) crashes recorded")
            showReliabilityWarning(type: .crash, count: count)
        }
    }

    func recordError() {
        errorCount += 1

        if errorCount >= maxErrorsBeforeWarning {
            let count = errorCount
            logger.warning("Error threshold exceeded: \(count) errors recorded")
            showReliabilityWarning(type: .error, count: count)
        }
    }

    func resetCounters() {
        crashCount = 0
        errorCount = 0
    }

    private func showReliabilityWarning(type: ReliabilityIssue, count: Int) {
        logger.warning("Session reliability warning: \(type.rawValue) count: \(count)")
    }
}

enum ReliabilityIssue: String {
    case crash = "Crash"
    case error = "Error"
}
