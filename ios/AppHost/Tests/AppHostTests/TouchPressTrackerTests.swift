import XCTest
@testable import Xemu

final class TouchPressTrackerTests: XCTestCase {
    func testTransitionsDoNotDuplicateEvents() {
        var tracker = TouchPressTracker()

        XCTAssertEqual(tracker.transition(for: false), .none)
        XCTAssertEqual(tracker.transition(for: true), .pressed)
        XCTAssertEqual(tracker.transition(for: true), .none)
        XCTAssertEqual(tracker.transition(for: false), .released)
        XCTAssertEqual(tracker.transition(for: false), .none)
    }

    func testTwoTrackersSupportIndependentSimultaneousPresses() {
        var dpad = TouchPressTracker()
        var face = TouchPressTracker()

        XCTAssertEqual(dpad.transition(for: true), .pressed)
        XCTAssertEqual(face.transition(for: true), .pressed)
        XCTAssertTrue(dpad.isPressed)
        XCTAssertTrue(face.isPressed)

        XCTAssertEqual(face.transition(for: false), .released)
        XCTAssertTrue(dpad.isPressed)
        XCTAssertFalse(face.isPressed)
    }

    func testResetReleasesPressedState() {
        var tracker = TouchPressTracker()
        XCTAssertEqual(tracker.transition(for: true), .pressed)
        XCTAssertTrue(tracker.reset())
        XCTAssertFalse(tracker.isPressed)
        XCTAssertFalse(tracker.reset())
    }
}
