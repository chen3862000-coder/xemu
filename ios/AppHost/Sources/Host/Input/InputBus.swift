import Foundation
import GameController

final class InputBus: InputRouting {
    static let shared = InputBus()

    private let queue = DispatchQueue(label: "com.xemu.inputbus", qos: .userInteractive)
    private var listeners: [UUID: (InputEvent) -> Void] = [:]

    private init() {
        setupControllerNotifications()
    }

    // MARK: Listener Management

    @discardableResult
    func addListener(_ listener: @escaping (InputEvent) -> Void) -> UUID {
        let token = UUID()
        queue.async {
            self.listeners[token] = listener
        }
        return token
    }

    func removeListener(_ token: UUID) {
        queue.async {
            self.listeners[token] = nil
        }
    }

    // MARK: InputRouting

    func route(event: InputEvent) {
        queue.async {
            self.listeners.values.forEach { $0(event) }
        }
    }

    func routeAnalog(x: Float, y: Float, timestamp: TimeInterval) {
        // Map analog movements into synthetic events for downstream consumers.
        let horizontal: ControllerButton = x >= 0 ? .dpadRight : .dpadLeft
        let vertical: ControllerButton = y >= 0 ? .dpadUp : .dpadDown

        let horizontalEvent = InputEvent(button: horizontal, isPressed: abs(x) > 0.3, timestamp: timestamp)
        let verticalEvent = InputEvent(button: vertical, isPressed: abs(y) > 0.3, timestamp: timestamp)

        route(event: horizontalEvent)
        route(event: verticalEvent)
    }

    // MARK: GameController Wiring

    private func setupControllerNotifications() {
        NotificationCenter.default.addObserver(forName: .GCControllerDidBecomeCurrent, object: nil, queue: nil) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            self?.attach(controller: controller)
        }

        GCController.controllers().forEach { attach(controller: $0) }
    }

    private func attach(controller: GCController) {
        controller.extendedGamepad?.valueChangedHandler = { [weak self] gamepad, element in
            let timestamp = Date().timeIntervalSince1970

            if let button = self?.button(for: element, gamepad: gamepad) {
                let event = InputEvent(button: button, isPressed: element.isPressed, timestamp: timestamp)
                self?.route(event: event)
            } else if element == gamepad.leftThumbstick {
                self?.routeAnalog(x: gamepad.leftThumbstick.xAxis.value, y: gamepad.leftThumbstick.yAxis.value, timestamp: timestamp)
            }
        }
    }

    private func button(for element: GCControllerElement, gamepad: GCExtendedGamepad) -> ControllerButton? {
        switch element {
        case gamepad.buttonA: return .a
        case gamepad.buttonB: return .b
        case gamepad.buttonX: return .x
        case gamepad.buttonY: return .y
        case gamepad.leftShoulder: return .l
        case gamepad.rightShoulder: return .r
        case gamepad.leftTrigger: return .triggerLeft
        case gamepad.rightTrigger: return .triggerRight
        case gamepad.buttonMenu: return .menu
        case gamepad.buttonOptions: return .start
        default: return nil
        }
    }
}
