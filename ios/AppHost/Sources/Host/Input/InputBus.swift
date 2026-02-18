import Foundation
@preconcurrency import GameController

@MainActor
final class InputBus: InputRouting {
    static let shared = InputBus()
    
    private let queue = DispatchQueue(label: "com.xemu.inputbus", qos: .userInteractive)
    private var listeners: [UUID: @Sendable (InputEvent) -> Void] = [:]
    private var isTesting = false

    private init() {
        #if DEBUG
        isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #endif
        if !isTesting {
            setupControllerNotifications()
        }
    }

    // MARK: Listener Management

    nonisolated func addListener(_ listener: @escaping @Sendable (InputEvent) -> Void) -> UUID {
        let token = UUID()
        queue.async { [weak self] in
            self?.listeners[token] = listener
        }
        return token
    }

    func removeListener(_ token: UUID) {
        queue.async { [weak self] in
            self?.listeners[token] = nil
        }
    }

    func clearListeners() {
        queue.async { [weak self] in
            self?.listeners.removeAll()
        }
    }

    // MARK: InputRouting

    nonisolated func route(_ event: InputEvent) {
        queue.async { [weak self] in
            self?.listeners.values.forEach { $0(event) }
        }
    }

    func routeAnalog(x: Float, y: Float, timestamp: TimeInterval) {
        let horizontal: ControllerButton = x >= 0 ? .dpadRight : .dpadLeft
        let vertical: ControllerButton = y >= 0 ? .dpadUp : .dpadDown

        let horizontalEvent = InputEvent(button: horizontal, isPressed: abs(x) > 0.3, timestamp: Date(timeIntervalSince1970: timestamp))
        let verticalEvent = InputEvent(button: vertical, isPressed: abs(y) > 0.3, timestamp: Date(timeIntervalSince1970: timestamp))

        route(horizontalEvent)
        route(verticalEvent)
    }

    // MARK: GameController Wiring

    private func setupControllerNotifications() {
        NotificationCenter.default.addObserver(forName: .GCControllerDidBecomeCurrent, object: nil, queue: nil) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            Task { @MainActor [weak self] in
                self?.attach(controller: controller)
            }
        }

        for controller in GCController.controllers() {
            Task { @MainActor [weak self] in
                self?.attach(controller: controller)
            }
        }
    }

    private func attach(controller: GCController) {
        controller.extendedGamepad?.valueChangedHandler = { [weak self] gamepad, element in
            let timestamp = Date()

            if let button = self?.button(for: element, gamepad: gamepad) {
                let event = InputEvent(button: button, isPressed: true, timestamp: timestamp)
                self?.route(event)
            } else if element == gamepad.leftThumbstick {
                self?.routeAnalog(x: gamepad.leftThumbstick.xAxis.value, y: gamepad.leftThumbstick.yAxis.value, timestamp: timestamp.timeIntervalSince1970)
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
