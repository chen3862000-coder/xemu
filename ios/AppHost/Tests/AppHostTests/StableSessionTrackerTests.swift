import XCTest
@testable import Xemu

@MainActor
final class StableSessionTrackerTests: XCTestCase {

    var tracker: StableSessionTracker!

    override func setUp() {
        super.setUp()
        tracker = StableSessionTracker()
    }

    override func tearDown() {
        tracker = nil
        super.tearDown()
    }

    func testSharedInstance() {
        XCTAssertNotNil(StableSessionTracker.shared)
    }

    func testRecordCrash() {
        tracker.recordCrash()
        tracker.recordCrash()
        tracker.recordCrash()
        tracker.recordCrash()
        tracker.recordCrash()
    }

    func testRecordError() {
        tracker.recordError()
        tracker.recordError()
    }

    func testResetCounters() {
        tracker.recordCrash()
        tracker.recordError()
        tracker.resetCounters()
    }

    func testSessionMode() {
        XCTAssertEqual(tracker.currentMode, .singlePlayer)
    }

    func testCompletionState() {
        XCTAssertEqual(tracker.completionState, .completed)
    }

    func testLogEntryCreation() {
        let entry = LogEntry(
            sessionId: UUID(),
            userId: UUID(),
            deviceId: UUID(),
            type: "test",
            timestamp: Date(),
            metadata: ["key": "value"]
        )

        XCTAssertEqual(entry.type, "test")
    }

    func testLogEntryCodable() throws {
        let original = LogEntry(
            sessionId: UUID(),
            userId: UUID(),
            deviceId: UUID(),
            type: "test",
            timestamp: Date(),
            metadata: ["key": "value"]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LogEntry.self, from: data)

        XCTAssertEqual(original.type, decoded.type)
    }
}
