import Foundation
import Combine
import CommonCrypto

public struct LogEntry: Equatable {
    public let sessionId: UUID
    public let userId: UUID
    public let deviceId: UUID
    public let type: String
    public let timestamp: Date
    public let metadata: [String: Any]

    public init(sessionId: UUID, userId: UUID, deviceId: UUID, type: String, timestamp: Date, metadata: [String: Any]?) {
        self.sessionId = sessionId
        self.userId = userId
        self.deviceId = deviceId
        self.type = type
        self.timestamp = timestamp
        self.metadata = metadata ?? [:]
    }

    public static func == (lhs: LogEntry, rhs: LogEntry) -> Bool {
        return lhs.sessionId == rhs.sessionId &&
               lhs.userId == rhs.userId &&
               lhs.deviceId == rhs.deviceId &&
               lhs.type == rhs.type &&
               lhs.timestamp == rhs.timestamp
    }
}

public final class StableSessionTracker: @unchecked Sendable {
    public enum SessionError: Error, Equatable {
        case sessionAlreadyInProgress
        case noSessionInProgress
        case invalidSessionState
    }

    internal let userId: UUID
    internal let deviceId: UUID
    private let logDirectory: URL
    
    private var logs: [LogEntry] = []
    private var heartbeatTimer: Timer?
    
    public private(set) var currentSessionId: UUID?
    public private(set) var sessionStartTime: Date?
    public var totalSessionDuration: Double = 0
    public var heartbeatIntervalMs: Int = 5000
    public private(set) var isHeartbeatRunning: Bool = false
    public private(set) var rewindCount: Int = 0
    public var achievementTriggers: [AchievementTrigger] = []
    public private(set) var currentMode: SessionMode?
    public private(set) var currentEntryId: UUID?
    public var sessionVerdict: SessionVerdict = .Pending
    
    public init(userId: UUID, deviceId: UUID, logDirectory: URL) {
        self.userId = userId
        self.deviceId = deviceId
        self.logDirectory = logDirectory
    }
    
    public func startSession() {
        guard currentSessionId == nil else { return }

        currentSessionId = UUID()
        sessionStartTime = Date()
        rewindCount = 0
        achievementTriggers = []
        currentMode = .SinglePlayer
        sessionVerdict = .Pending

        log(type: "session_start", metadata: ["sessionId": currentSessionId!])
    }
    
    public func stopSession(completionState: CompletionState) {
        guard currentSessionId != nil else { return }

        if let startTime = sessionStartTime {
            totalSessionDuration += Date().timeIntervalSince(startTime)
        }

        log(type: "session_end", metadata: [
            "completionState": completionState.rawValue,
            "sessionDuration": totalSessionDuration
        ])

        currentSessionId = nil
        sessionStartTime = nil
    }

    public func stopSession() {
        guard currentSessionId != nil else { return }

        if let startTime = sessionStartTime {
            totalSessionDuration += Date().timeIntervalSince(startTime)
        }

        log(type: "session_end", metadata: [
            "completionState": CompletionState.NotStarted.rawValue,
            "sessionDuration": totalSessionDuration
        ])

        currentSessionId = nil
        sessionStartTime = nil
    }
    
    public func startHeartbeat(intervalMs: Int = 5000) {
        heartbeatIntervalMs = intervalMs
        isHeartbeatRunning = true

        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: Double(intervalMs) / 1000, repeats: true) { [weak self] _ in
            guard let self = self, let sessionId = self.currentSessionId else { return }
            self.log(type: "heartbeat", metadata: ["sessionId": sessionId])
        }
    }
    
    public func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        isHeartbeatRunning = false
    }
    
    public func recordRewindEvent() {
        guard currentSessionId != nil else { return }

        rewindCount += 1
        log(type: "rewind", metadata: ["count": rewindCount])
    }

    public func recordAchievementTrigger(_ trigger: AchievementTrigger) {
        guard currentSessionId != nil else { return }

        achievementTriggers.append(trigger)
        log(type: "achievement", metadata: [
            "achievementId": trigger.achievementId.uuidString,
            "triggeredAt": trigger.triggeredAt
        ])
    }

    public func setSessionMode(_ mode: SessionMode) {
        currentMode = mode
        log(type: "mode_change", metadata: ["mode": mode.rawValue])
    }
    
    public func setEntryId(_ id: UUID) {
        currentEntryId = id
        log(type: "entry_set", metadata: ["entryId": id.uuidString])
    }
    
    public func getLogEntries() -> [LogEntry] {
        return logs
    }
    
    public func clearLogs() {
        logs = []
    }
    
    public func exportLogs(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let exportEntries = logs.map { entry in
            LogExportEntry(
                sessionId: entry.sessionId,
                userId: entry.userId,
                deviceId: entry.deviceId,
                type: entry.type,
                timestamp: entry.timestamp,
                metadata: entry.metadata.mapValues { "\($0)" }
            )
        }

        let logData = try encoder.encode(LogExport(logs: exportEntries))
        try logData.write(to: url)
    }
    
    private func log(type: String, metadata: [String: Any]? = nil) {
        guard let sessionId = currentSessionId else { return }

        let entry = LogEntry(
            sessionId: sessionId,
            userId: userId,
            deviceId: deviceId,
            type: type,
            timestamp: Date(),
            metadata: metadata
        )

        logs.append(entry)
    }
}

private struct LogExport: Codable {
    let logs: [LogExportEntry]
}

private struct LogExportEntry: Codable {
    let sessionId: UUID
    let userId: UUID
    let deviceId: UUID
    let type: String
    let timestamp: Date
    let metadata: [String: String]?
}
