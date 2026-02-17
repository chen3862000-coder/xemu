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
    private var sessionStartTime: Date?
    private var heartbeatCount = 0
    private var lastHeartbeat: Date?
    private var isTracking = false

    private init(userId: UUID = UUID(), deviceId: UUID = UUID(), logDirectory: URL = FileManager.default.temporaryDirectory) {
        self.userId = userId
        self.deviceId = deviceId
        self.logDirectory = logDirectory
    }

    internal let userId: UUID
    internal let deviceId: UUID
    internal let logDirectory: URL

    private var currentSessionId: UUID? {
        sessionId
    }

    internal var sessionStartTime: Date? {
        sessionStartTime
    }

    internal var totalSessionDuration: TimeInterval = 0
    internal var isHeartbeatRunning = false
    internal var heartbeatIntervalMs: Int = 5000
    internal var rewindCount = 0
    internal var achievementTriggers: [AchievementTrigger] = []
    internal var currentMode: SessionMode = .singlePlayer
    internal var currentEntryId: UUID?
    internal var sessionVerdict: SessionVerdict = .pending

    private var logs: [LogEntry] = []
    private var timer: Timer?

    func startSession() {
        guard !isTracking else { return }

        sessionId = UUID()
        sessionStartTime = Date()
        heartbeatCount = 0
        isTracking = true
        rewindCount = 0
        achievementTriggers.removeAll()

        logEvent(
            type: "session_start",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "user_id": userId.uuidString,
                "device_id": deviceId.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: sessionStartTime!)
            ]
        )
    }

    func stopSession(completionState: CompletionState) throws {
        guard let sessionId = sessionId,
              let startTime = sessionStartTime,
              isTracking else {
            throw SessionError.noActiveSession
        }

        stopHeartbeat()

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        totalSessionDuration += duration

        logEvent(
            type: "session_end",
            data: [
                "session_id": sessionId.uuidString,
                "duration_seconds": Int(duration),
                "completion_state": completionState.rawValue,
                "heartbeat_count": heartbeatCount,
                "timestamp": ISO8601DateFormatter().string(from: endTime),
                "mode": currentMode.rawValue
            ]
        )

        self.sessionId = nil
        self.sessionStartTime = nil
        self.heartbeatCount = 0
        self.isTracking = false
    }

    func stopSession() {
        guard isTracking else { return }

        stopHeartbeat()

        let endTime = Date()
        let duration = sessionStartTime.map { endTime.timeIntervalSince($0) } ?? 0
        totalSessionDuration += duration

        logEvent(
            type: "session_end",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "duration_seconds": Int(duration),
                "completion_state": CompletionState.notStarted.rawValue,
                "heartbeat_count": heartbeatCount,
                "timestamp": ISO8601DateFormatter().string(from: endTime),
                "mode": currentMode.rawValue
            ]
        )

        self.sessionId = nil
        self.sessionStartTime = nil
        self.heartbeatCount = 0
        self.isTracking = false
    }

    func recordFrameUpdate(fps: Int, skipped: Int) {
        guard isTracking else { return }

        logEvent(
            type: "frame_update",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "fps": fps,
                "skipped_frames": skipped,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    func recordInputEvent(button: ControllerButton, isPressed: Bool) {
        guard isTracking else { return }

        logEvent(
            type: "input_event",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "button": buttonName(for: button),
                "pressed": isPressed,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    func recordSaveState(slot: Int, success: Bool) {
        guard isTracking else { return }

        logEvent(
            type: "save_state",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "slot": slot,
                "success": success,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    func recordLoadState(slot: Int, success: Bool) {
        guard isTracking else { return }

        logEvent(
            type: "load_state",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "slot": slot,
                "success": success,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    func recordRewind(eventCount: Int) {
        guard isTracking else { return }

        logEvent(
            type: "rewind",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "event_count": eventCount,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    func recordRewindEvent() {
        guard isTracking else { return }
        rewindCount += 1
        logEvent(
            type: "rewind_event",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "count": rewindCount,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    func recordAchievementTrigger(achievementId: UUID) {
        guard isTracking else { return }

        logEvent(
            type: "achievement_trigger",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "achievement_id": achievementId.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    func recordAchievementTrigger(_ trigger: AchievementTrigger) {
        guard isTracking else { return }
        achievementTriggers.append(trigger)
        logEvent(
            type: "achievement_trigger",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "achievement_id": trigger.achievementId.uuidString,
                "timestamp": ISO8601DateFormatter().string(from: trigger.triggeredAt)
            ]
        )
    }

    func recordError(error: Error, context: String) {
        guard isTracking else { return }

        logEvent(
            type: "error",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "error_type": String(describing: type(of: error)),
                "error_message": error.localizedDescription,
                "context": context,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    func recordCoreCrash(coreType: String, message: String?) {
        guard isTracking else { return }

        logEvent(
            type: "core_crash",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "core_type": coreType,
                "message": message ?? "Unknown",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    func recordMultiplayerLag(rttMs: Int, packetLoss: Double) {
        guard isTracking else { return }

        logEvent(
            type: "multiplayer_lag",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "rtt_ms": rttMs,
                "packet_loss": packetLoss,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    func recordConnectionState(state: ConnectionState) {
        guard isTracking else { return }

        logEvent(
            type: "connection_state",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "state": state.rawValue,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        )
    }

    func getSessionMetrics() -> SessionMetrics? {
        guard let sessionId = sessionId,
              let startTime = sessionStartTime else {
            return nil
        }

        return SessionMetrics(
            sessionId: sessionId,
            startTime: startTime,
            duration: Date().timeIntervalSince(startTime),
            heartbeatCount: heartbeatCount
        )
    }

    func setSessionMode(_ mode: SessionMode) {
        currentMode = mode
    }

    func setEntryId(_ entryId: UUID) {
        currentEntryId = entryId
    }

    func getLogEntries() -> [LogEntry] {
        return logs
    }

    func clearLogs() {
        logs.removeAll()
    }

    func exportLogs(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(logs)
        try data.write(to: url)
    }

    private func startHeartbeat(intervalMs: Int) {
        let timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(intervalMs) / 1000.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isTracking else { return }

            self.recordHeartbeat()
        }

        RunLoop.current.add(timer, forMode: .common)
        self.timer = timer
    }

    func startHeartbeat(intervalMs: Int = 5000) {
        guard isTracking else { return }
        heartbeatIntervalMs = intervalMs
        isHeartbeatRunning = true
        startHeartbeat(intervalMs: intervalMs)
    }

    func stopHeartbeat() {
        timer?.invalidate()
        timer = nil
        isHeartbeatRunning = false
    }

    private func recordHeartbeat() {
        heartbeatCount += 1
        lastHeartbeat = Date()

        logEvent(
            type: "heartbeat",
            data: [
                "session_id": sessionId?.uuidString ?? "",
                "count": heartbeatCount,
                "timestamp": ISO8601DateFormatter().string(from: lastHeartbeat!)
            ]
        )
    }

    private func logEvent(type: String, data: [String: Any]) {
        logger.info("Event: \(type, privacy: .public)")

        guard let sessionId = sessionId else { return }

        let entry = LogEntry(
            sessionId: sessionId,
            userId: userId,
            deviceId: deviceId,
            type: type,
            timestamp: Date(),
            metadata: data
        )
        logs.append(entry)

        if let jsonData = try? JSONSerialization.data(withJSONObject: data),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            logger.debug("\(jsonString, privacy: .public)")
        }
    }

    private func buttonName(for button: ControllerButton) -> String {
        switch button {
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
        case .l: return "L"
        case .r: return "R"
        case .dpadUp: return "D-Up"
        case .dpadDown: return "D-Down"
        case .dpadLeft: return "D-Left"
        case .dpadRight: return "D-Right"
        case .start: return "Start"
        case .select: return "Select"
        case .menu: return "Menu"
        case .triggerLeft: return "L-Trigger"
        case .triggerRight: return "R-Trigger"
        }
    }
}

struct SessionMetrics {
    let sessionId: UUID
    let startTime: Date
    let duration: TimeInterval
    let heartbeatCount: Int

    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var heartbeatRate: Double {
        guard duration > 0 else { return 0 }
        return Double(heartbeatCount) / duration
    }
}

enum ConnectionState: String {
    case connecting
    case connected
    case disconnected
    case reconnecting
}

final class SessionReliabilityMonitor {
    static let shared = SessionReliabilityMonitor()

    private let logger = Logger(subsystem: "com.xemu.app", category: "SessionReliability")
    private var crashCount = 0
    private var errorCount = 0
    private let maxCrashesBeforeWarning = 3
    private let maxErrorsBeforeWarning = 10

    private init() {}

    func recordCrash() {
        crashCount += 1

        if crashCount >= maxCrashesBeforeWarning {
            logger.error("Crash threshold exceeded: \(crashCount) crashes recorded")
            showReliabilityWarning(type: .crash, count: crashCount)
        }
    }

    func recordError() {
        errorCount += 1

        if errorCount >= maxErrorsBeforeWarning {
            logger.warning("Error threshold exceeded: \(errorCount) errors recorded")
            showReliabilityWarning(type: .error, count: errorCount)
        }
    }

    func resetCounters() {
        crashCount = 0
        errorCount = 0
    }

    private func showReliabilityWarning(type: ReliabilityIssue, count: Int) {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Session Reliability Issue Detected"
        content.body = "\(type.rawValue) count: \(count). Consider reporting this issue."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { error in
            if let error = error {
                self.logger.error("Failed to show reliability notification: \(error)")
            }
        }
    }
}

enum ReliabilityIssue: String {
    case crash = "Crash"
    case error = "Error"
}
