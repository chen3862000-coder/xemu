import XCTest
import Combine
@testable import AppHost

final class InputBusTests: XCTestCase {

    var inputBus: InputBus!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        inputBus = InputBus()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        inputBus = nil
        cancellables = nil
        super.tearDown()
    }

    func testInputEventInitialization() {
        let event = InputEvent(
            type: .buttonA,
            player: 0,
            value: 1.0,
            timestamp: Date()
        )

        XCTAssertEqual(event.type, .buttonA)
        XCTAssertEqual(event.player, 0)
        XCTAssertEqual(event.value, 1.0)
        XCTAssertNotNil(event.timestamp)
    }

    func testButtonTypeValues() {
        let buttonDown = InputEvent(type: .buttonA, player: 0, value: 1.0, timestamp: Date())
        let buttonUp = InputEvent(type: .buttonA, player: 0, value: 0.0, timestamp: Date())

        XCTAssertEqual(buttonDown.value, 1.0)
        XCTAssertEqual(buttonUp.value, 0.0)
    }

    func testButtonTypeCases() {
        let types: [InputType] = [
            .buttonA, .buttonB, .buttonX, .buttonY,
            .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
            .start, .select, .shoulderL, .shoulderR,
            .triggerL, .triggerR
        ]

        XCTAssertEqual(types.count, 14)
    }

    func testInputBusPublishesEvents() {
        var receivedEvents: [InputEvent] = []
        let expectation = XCTestExpectation(description: "Input event published")

        inputBus.events.sink { event in
            receivedEvents.append(event)
            if receivedEvents.count == 3 {
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        let testEvent = InputEvent(type: .buttonA, player: 0, value: 1.0, timestamp: Date())
        inputBus.send(testEvent)
        inputBus.send(testEvent)
        inputBus.send(testEvent)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedEvents.count, 3)
    }

    func testInputBusMultiplePlayers() {
        var eventsByPlayer: [Int: [InputEvent]] = [:]
        let expectation = XCTestExpectation(description: "Multiple players events")

        inputBus.events.sink { event in
            if eventsByPlayer[event.player] == nil {
                eventsByPlayer[event.player] = []
            }
            eventsByPlayer[event.player]?.append(event)

            if eventsByPlayer.values.allSatisfy({ $0.count >= 2 }) {
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        inputBus.send(InputEvent(type: .buttonA, player: 0, value: 1.0, timestamp: Date()))
        inputBus.send(InputEvent(type: .buttonB, player: 0, value: 1.0, timestamp: Date()))
        inputBus.send(InputEvent(type: .buttonA, player: 1, value: 1.0, timestamp: Date()))
        inputBus.send(InputEvent(type: .buttonB, player: 1, value: 1.0, timestamp: Date()))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(eventsByPlayer[0]?.count, 2)
        XCTAssertEqual(eventsByPlayer[1]?.count, 2)
    }

    func testInputEventCodable() {
        let originalEvent = InputEvent(
            type: .buttonA,
            player: 1,
            value: 0.5,
            timestamp: Date()
        )

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(originalEvent),
              let decodedEvent = try? JSONDecoder().decode(InputEvent.self, from: data) else {
            XCTFail("Encoding/decoding failed")
            return
        }

        XCTAssertEqual(originalEvent.type, decodedEvent.type)
        XCTAssertEqual(originalEvent.player, decodedEvent.player)
        XCTAssertEqual(originalEvent.value, decodedEvent.value)
    }

    func testInputEventEquatable() {
        let event1 = InputEvent(type: .buttonA, player: 0, value: 1.0, timestamp: Date())
        let event2 = InputEvent(type: .buttonA, player: 0, value: 1.0, timestamp: event1.timestamp)
        let event3 = InputEvent(type: .buttonB, player: 0, value: 1.0, timestamp: Date())

        XCTAssertEqual(event1, event2)
        XCTAssertNotEqual(event1, event3)
    }

    func testInputBusClear() {
        var receivedEvents: [InputEvent] = []
        let expectation = XCTestExpectation(description: "Events cleared")

        inputBus.events.sink { event in
            receivedEvents.append(event)
        }.store(in: &cancellables)

        inputBus.send(InputEvent(type: .buttonA, player: 0, value: 1.0, timestamp: Date()))
        inputBus.send(InputEvent(type: .buttonB, player: 0, value: 1.0, timestamp: Date()))
        inputBus.clear()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 0.5)
        XCTAssertEqual(receivedEvents.count, 2)
    }

    func testDPadInputType() {
        let dpadUp = InputEvent(type: .dpadUp, player: 0, value: 1.0, timestamp: Date())
        let dpadDown = InputEvent(type: .dpadDown, player: 0, value: 1.0, timestamp: Date())
        let dpadLeft = InputEvent(type: .dpadLeft, player: 0, value: 1.0, timestamp: Date())
        let dpadRight = InputEvent(type: .dpadRight, player: 0, value: 1.0, timestamp: Date())

        XCTAssertEqual(dpadUp.type, .dpadUp)
        XCTAssertEqual(dpadDown.type, .dpadDown)
        XCTAssertEqual(dpadLeft.type, .dpadLeft)
        XCTAssertEqual(dpadRight.type, .dpadRight)
    }

    func testShoulderTriggerButtons() {
        let shoulderL = InputEvent(type: .shoulderL, player: 0, value: 1.0, timestamp: Date())
        let shoulderR = InputEvent(type: .shoulderR, player: 0, value: 1.0, timestamp: Date())
        let triggerL = InputEvent(type: .triggerL, player: 0, value: 0.7, timestamp: Date())
        let triggerR = InputEvent(type: .triggerR, player: 0, value: 0.5, timestamp: Date())

        XCTAssertEqual(shoulderL.type, .shoulderL)
        XCTAssertEqual(shoulderR.type, .shoulderR)
        XCTAssertEqual(triggerL.type, .triggerL)
        XCTAssertEqual(triggerL.value, 0.7)
        XCTAssertEqual(triggerR.type, .triggerR)
        XCTAssertEqual(triggerR.value, 0.5)
    }

    func testInputEventTimestampAccuracy() {
        let beforeDate = Date()
        let event = InputEvent(type: .buttonA, player: 0, value: 1.0, timestamp: Date())
        let afterDate = Date()

        XCTAssertGreaterThanOrEqual(event.timestamp, beforeDate)
        XCTAssertLessThanOrEqual(event.timestamp, afterDate)
    }

    func testInputBusSequentialEvents() {
        var receivedEvents: [InputEvent] = []
        let expectation = XCTestExpectation(description: "Sequential events")

        inputBus.events.sink { event in
            receivedEvents.append(event)
            if receivedEvents.count == 5 {
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        for i in 0..<5 {
            let type: InputType = [InputType.buttonA, .buttonB, .buttonX, .buttonY, .start][i]
            inputBus.send(InputEvent(type: type, player: 0, value: 1.0, timestamp: Date()))
        }

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedEvents.count, 5)

        for i in 1..<5 {
            XCTAssertLessThanOrEqual(receivedEvents[i-1].timestamp, receivedEvents[i].timestamp)
        }
    }

    func testInputBusWithAnalogValues() {
        var lastValue: Double = -1.0
        let expectation = XCTestExpectation(description: "Analog values")

        inputBus.events.sink { event in
            lastValue = event.value
            if lastValue == 0.75 {
                expectation.fulfill()
            }
        }.store(in: &cancellables)

        inputBus.send(InputEvent(type: .triggerL, player: 0, value: 0.0, timestamp: Date()))
        inputBus.send(InputEvent(type: .triggerL, player: 0, value: 0.25, timestamp: Date()))
        inputBus.send(InputEvent(type: .triggerL, player: 0, value: 0.5, timestamp: Date()))
        inputBus.send(InputEvent(type: .triggerL, player: 0, value: 0.75, timestamp: Date()))

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(lastValue, 0.75)
    }
}
