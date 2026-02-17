import XCTest
import Combine
@testable import AppHost

final class StableSessionTrackerTests: XCTestCase {

    var tracker: StableSessionTracker!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()

        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        tracker = StableSessionTracker(
            userId: UUID(),
            deviceId: UUID(),
            logDirectory: tempDirectory
        )
    }

    override func tearDown() {
        tracker.stopSession()
        tracker = nil
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }

    func testSessionStart() {
        XCTAssertNoThrow(tracker.startSession())

        XCTAssertNotNil(tracker.currentSessionId)
        XCTAssertNotNil(tracker.sessionStartTime)
    }

    func testSessionStop() throws {
        tracker.startSession()

        try Thread.sleep(forTimeInterval: 0.1)

        XCTAssertNoThrow(try tracker.stopSession(completionState: .Completed))

        XCTAssertNil(tracker.currentSessionId)
        XCTAssertGreaterThan(tracker.totalSessionDuration, 0)
    }

    func testSessionDuration() throws {
        tracker.startSession()

        try Thread.sleep(forTimeInterval: 0.2)

        try tracker.stopSession(completionState: .Completed)

        XCTAssertGreaterThanOrEqual(tracker.totalSessionDuration, 0.2)
    }

    func testStartHeartbeat() {
        tracker.startSession()

        XCTAssertNoThrow(tracker.startHeartbeat(intervalMs: 5000))

        XCTAssertTrue(tracker.isHeartbeatRunning)
    }

    func testStopHeartbeat() {
        tracker.startSession()
        tracker.startHeartbeat(intervalMs: 5000)

        tracker.stopHeartbeat()

        XCTAssertFalse(tracker.isHeartbeatRunning)
    }

    func testHeartbeatDefaultInterval() {
        tracker.startSession()
        tracker.startHeartbeat()

        XCTAssertEqual(tracker.heartbeatIntervalMs, 5000)
    }

    func testCustomHeartbeatInterval() {
        tracker.startSession()
        tracker.startHeartbeat(intervalMs: 10000)

        XCTAssertEqual(tracker.heartbeatIntervalMs, 10000)
    }

    func testRecordRewindEvent() throws {
        tracker.startSession()

        XCTAssertNoThrow(tracker.recordRewindEvent())

        XCTAssertEqual(tracker.rewindCount, 1)
    }

    func testRecordMultipleRewindEvents() throws {
        tracker.startSession()

        tracker.recordRewindEvent()
        tracker.recordRewindEvent()
        tracker.recordRewindEvent()

        XCTAssertEqual(tracker.rewindCount, 3)
    }

    func testRecordRewindEventWithoutSession() {
        XCTAssertEqual(tracker.rewindCount, 0)
        tracker.recordRewindEvent()
        XCTAssertEqual(tracker.rewindCount, 0)
    }

    func testRecordAchievementTrigger() throws {
        tracker.startSession()

        let achievementId = UUID()
        let trigger = AchievementTrigger(
            achievementId: achievementId,
            triggeredAt: Date(),
            metadata: ["score": 100]
        )

        XCTAssertNoThrow(try tracker.recordAchievementTrigger(trigger))

        XCTAssertEqual(tracker.achievementTriggers.count, 1)
    }

    func testRecordMultipleAchievementTriggers() throws {
        tracker.startSession()

        let trigger1 = AchievementTrigger(
            achievementId: UUID(),
            triggeredAt: Date(),
            metadata: ["score": 100]
        )

        let trigger2 = AchievementTrigger(
            achievementId: UUID(),
            triggeredAt: Date(),
            metadata: ["level": 5]
        )

        try tracker.recordAchievementTrigger(trigger1)
        try tracker.recordAchievementTrigger(trigger2)

        XCTAssertEqual(tracker.achievementTriggers.count, 2)
    }

    func testRecordAchievementTriggerWithoutSession() {
        let trigger = AchievementTrigger(
            achievementId: UUID(),
            triggeredAt: Date(),
            metadata: [:]
        )

        XCTAssertEqual(tracker.achievementTriggers.count, 0)
        tracker.recordAchievementTrigger(trigger)
        XCTAssertEqual(tracker.achievementTriggers.count, 0)
    }

    func testSetSessionMode() {
        tracker.startSession()

        tracker.setSessionMode(.Legit)

        XCTAssertEqual(tracker.currentMode, .Legit)
    }

    func testSetEntryId() {
        tracker.startSession()

        let entryId = UUID()
        tracker.setEntryId(entryId)

        XCTAssertEqual(tracker.currentEntryId, entryId)
    }

    func testAllSessionModes() {
        tracker.startSession()

        let modes: [SessionMode] = [.SinglePlayer, .Legit, .MultiplayerHost, .MultiplayerGuest]

        for mode in modes {
            tracker.setSessionMode(mode)
            XCTAssertEqual(tracker.currentMode, mode)
        }
    }

    func testAllCompletionStates() throws {
        let states: [CompletionState] = [.NotStarted, .InProgress, .Completed, .Mastered]

        for state in states {
            tracker.startSession()

            try tracker.stopSession(completionState: state)
        }
    }

    func testSessionVerdictPending() throws {
        tracker.startSession()

        try tracker.stopSession(completionState: .InProgress)

        XCTAssertEqual(tracker.sessionVerdict, .Pending)
    }

    func testSessionVerdictValid() throws {
        tracker.startSession()
        tracker.setSessionMode(.Legit)

        tracker.stopSession(completionState: .Completed)

        XCTAssertEqual(tracker.sessionVerdict, .Pending)
    }

    func testLogEventTypeSessionStart() {
        tracker.startSession()

        let logs = tracker.getLogEntries()
        let startEvents = logs.filter { $0.type == "session_start" }

        XCTAssertEqual(startEvents.count, 1)
    }

    func testLogEventTypeSessionEnd() throws {
        tracker.startSession()

        try tracker.stopSession(completionState: .Completed)

        let logs = tracker.getLogEntries()
        let endEvents = logs.filter { $0.type == "session_end" }

        XCTAssertEqual(endEvents.count, 1)
    }

    func testLogEventTypeHeartbeat() throws {
        tracker.startSession()
        tracker.startHeartbeat(intervalMs: 100)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))

        let logs = tracker.getLogEntries()
        let heartbeatEvents = logs.filter { $0.type == "heartbeat" }

        XCTAssertGreaterThan(heartbeatEvents.count, 1)
    }

    func testLogEventTypeRewindEvent() throws {
        tracker.startSession()

        tracker.recordRewindEvent()

        let logs = tracker.getLogEntries()
        let rewindEvents = logs.filter { $0.type == "rewind" }

        XCTAssertEqual(rewindEvents.count, 1)
    }

    func testLogEventTypeAchievementTrigger() throws {
        tracker.startSession()

        let trigger = AchievementTrigger(
            achievementId: UUID(),
            triggeredAt: Date(),
            metadata: [:]
        )

        try tracker.recordAchievementTrigger(trigger)

        let logs = tracker.getLogEntries()
        let achievementEvents = logs.filter { $0.type == "achievement" }

        XCTAssertEqual(achievementEvents.count, 1)
    }

    func testLogEntryContainsSessionId() throws {
        tracker.startSession()

        let sessionId = tracker.currentSessionId!
        let logs = tracker.getLogEntries()

        XCTAssertTrue(logs.allSatisfy { $0.sessionId == sessionId })
    }

    func testLogEntryContainsUserId() {
        tracker.startSession()

        let userId = tracker.userId
        let logs = tracker.getLogEntries()

        XCTAssertTrue(logs.allSatisfy { $0.userId == userId })
    }

    func testLogEntryContainsDeviceId() {
        tracker.startSession()

        let deviceId = tracker.deviceId
        let logs = tracker.getLogEntries()

        XCTAssertTrue(logs.allSatisfy { $0.deviceId == deviceId })
    }

    func testLogEntryTimestamps() throws {
        tracker.startSession()

        let logs = tracker.getLogEntries()

        for log in logs {
            XCTAssertNotNil(log.timestamp)
        }
    }

    func testGetLogEntries() {
        tracker.startSession()

        let logs = tracker.getLogEntries()

        XCTAssertGreaterThan(logs.count, 0)
    }

    func testClearLogs() throws {
        tracker.startSession()

        try tracker.stopSession(completionState: .Completed)

        XCTAssertGreaterThan(tracker.getLogEntries().count, 0)

        tracker.clearLogs()

        XCTAssertEqual(tracker.getLogEntries().count, 0)
    }

    func testExportLogs() throws {
        tracker.startSession()

        try tracker.stopSession(completionState: .Completed)

        let exportURL = tempDirectory.appendingPathComponent("session_logs.json")

        XCTAssertNoThrow(try tracker.exportLogs(to: exportURL))

        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
    }

    func testSessionIdGeneration() {
        tracker.startSession()
        let sessionId1 = tracker.currentSessionId!

        tracker.stopSession(completionState: .Completed)
        tracker.startSession()
        let sessionId2 = tracker.currentSessionId!

        XCTAssertNotEqual(sessionId1, sessionId2)
    }

    func testHeartbeatAccuracy() throws {
        tracker.startSession()
        tracker.startHeartbeat(intervalMs: 100)

        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.35))

        let logs = tracker.getLogEntries()
        let heartbeatEvents = logs.filter { $0.type == "heartbeat" }

        XCTAssertGreaterThanOrEqual(heartbeatEvents.count, 2)
        XCTAssertLessThanOrEqual(heartbeatEvents.count, 4)
    }

    func testSessionMetadata() throws {
        tracker.startSession()
        tracker.setSessionMode(.Legit)
        tracker.setEntryId(UUID())

        tracker.stopSession(completionState: .Completed)

        let logs = tracker.getLogEntries()
        let endEvent = logs.first { $0.type == "session_end" }

        XCTAssertNotNil(endEvent?.metadata)
        let modeLog = logs.first { $0.type == "mode_change" }
        XCTAssertEqual(modeLog?.metadata["mode"] as? String, "Legit")
    }

    func testRewindCountResetOnNewSession() throws {
        tracker.startSession()
        tracker.recordRewindEvent()
        tracker.recordRewindEvent()

        tracker.stopSession(completionState: .Completed)

        tracker.startSession()

        XCTAssertEqual(tracker.rewindCount, 0)
    }

    func testAchievementTriggersResetOnNewSession() throws {
        tracker.startSession()

        let trigger = AchievementTrigger(
            achievementId: UUID(),
            triggeredAt: Date(),
            metadata: [:]
        )

        tracker.recordAchievementTrigger(trigger)

        tracker.stopSession(completionState: .Completed)

        tracker.startSession()

        XCTAssertEqual(tracker.achievementTriggers.count, 0)
    }

    func testStopSessionWithoutStart() {
        XCTAssertNotNil(tracker)
        tracker.stopSession(completionState: .Completed)
        XCTAssertNil(tracker.currentSessionId)
    }

    func testStartHeartbeatWithoutSession() {
        tracker.startHeartbeat()
        XCTAssertTrue(tracker.isHeartbeatRunning)
        tracker.stopHeartbeat()
        XCTAssertFalse(tracker.isHeartbeatRunning)
    }

    func testMultipleSessions() throws {
        for i in 0..<3 {
            tracker.startSession()
            try Thread.sleep(forTimeInterval: 0.05)
            try tracker.stopSession(completionState: .Completed)
        }

        XCTAssertGreaterThan(tracker.totalSessionDuration, 0)
    }

    func testLogEntryCount() {
        tracker.startSession()

        let logs = tracker.getLogEntries()
        XCTAssertEqual(logs.count, 1)
    }
}
