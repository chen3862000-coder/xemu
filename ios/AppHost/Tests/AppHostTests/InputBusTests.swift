import XCTest
import Combine
@testable import Xemu

final class InputBusTests: XCTestCase {

    func testInputEventInitialization() {
        let event = InputEvent(
            button: .a,
            isPressed: true,
            timestamp: Date()
        )

        XCTAssertEqual(event.button, .a)
        XCTAssertEqual(event.isPressed, true)
        XCTAssertNotNil(event.timestamp)
    }

    func testButtonTypeValues() {
        let buttonDown = InputEvent(button: .a, isPressed: true, timestamp: Date())
        let buttonUp = InputEvent(button: .a, isPressed: false, timestamp: Date())

        XCTAssertEqual(buttonDown.isPressed, true)
        XCTAssertEqual(buttonUp.isPressed, false)
    }

    func testButtonTypeCases() {
        let buttons: [ControllerButton] = [
            .a, .b, .x, .y,
            .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
            .start, .menu, .l, .r,
            .triggerLeft, .triggerRight
        ]

        XCTAssertEqual(buttons.count, 14)
    }

    func testInputEventCodable() throws {
        let originalEvent = InputEvent(
            button: .a,
            isPressed: true,
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(originalEvent)
        let decodedEvent = try JSONDecoder().decode(InputEvent.self, from: data)

        XCTAssertEqual(originalEvent.button, decodedEvent.button)
        XCTAssertEqual(originalEvent.isPressed, decodedEvent.isPressed)
    }

    func testInputEventEquatable() {
        let timestamp = Date()
        let event1 = InputEvent(button: .a, isPressed: true, timestamp: timestamp)
        let event2 = InputEvent(button: .a, isPressed: true, timestamp: timestamp)
        let event3 = InputEvent(button: .b, isPressed: true, timestamp: timestamp)

        XCTAssertEqual(event1, event2)
        XCTAssertNotEqual(event1, event3)
    }

    func testDPadButtonTypes() {
        let dpadUp = InputEvent(button: .dpadUp, isPressed: true, timestamp: Date())
        let dpadDown = InputEvent(button: .dpadDown, isPressed: true, timestamp: Date())
        let dpadLeft = InputEvent(button: .dpadLeft, isPressed: true, timestamp: Date())
        let dpadRight = InputEvent(button: .dpadRight, isPressed: true, timestamp: Date())

        XCTAssertEqual(dpadUp.button, .dpadUp)
        XCTAssertEqual(dpadDown.button, .dpadDown)
        XCTAssertEqual(dpadLeft.button, .dpadLeft)
        XCTAssertEqual(dpadRight.button, .dpadRight)
    }

    func testShoulderTriggerButtons() {
        let shoulderL = InputEvent(button: .l, isPressed: true, timestamp: Date())
        let shoulderR = InputEvent(button: .r, isPressed: true, timestamp: Date())
        let triggerL = InputEvent(button: .triggerLeft, isPressed: true, timestamp: Date())
        let triggerR = InputEvent(button: .triggerRight, isPressed: true, timestamp: Date())

        XCTAssertEqual(shoulderL.button, .l)
        XCTAssertEqual(shoulderR.button, .r)
        XCTAssertEqual(triggerL.button, .triggerLeft)
        XCTAssertEqual(triggerR.button, .triggerRight)
    }

    func testInputEventTimestampAccuracy() {
        let beforeDate = Date()
        let event = InputEvent(button: .a, isPressed: true, timestamp: Date())
        let afterDate = Date()

        XCTAssertGreaterThanOrEqual(event.timestamp, beforeDate)
        XCTAssertLessThanOrEqual(event.timestamp, afterDate)
    }

    func testAllControllerButtons() {
        let allButtons: [ControllerButton] = [
            .a, .b, .x, .y,
            .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
            .start, .menu,
            .l, .r,
            .triggerLeft, .triggerRight
        ]

        XCTAssertEqual(allButtons.count, 14)

        for button in allButtons {
            let event = InputEvent(button: button, isPressed: true, timestamp: Date())
            XCTAssertEqual(event.button, button)
            XCTAssertTrue(event.isPressed)
        }
    }
}
