import Foundation
import CoreData
@preconcurrency import GameController

@MainActor
final class InputBus: InputRouting {
    static let shared = InputBus()
    
    private let queue = DispatchQueue(label: "com.xemu.inputbus", qos: .userInteractive)
    private var listeners: [UUID: @Sendable (InputEvent) -> Void] = [:]
    private var isTesting = false
    private weak var targetCore: EmulatorCore?
    private var activeController: GCController?
    private var controllerMappings: [Platform: EmulatorControllerProfile] = [:]
    private var lastInputTimestamp: Date?
    private var inputLatencySamples: [TimeInterval] = []
    private let maxLatencySamples = 100
    var onControllerConnected: ((String) -> Void)?
    var onControllerDisconnected: (() -> Void)?
    var onUnsupportedController: ((String) -> Void)?

    private init() {
        #if DEBUG
        isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #endif
        if !isTesting {
            setupControllerNotifications()
            loadDefaultMappings()
        }
    }
    
    private func loadDefaultMappings() {
        for platform in Platform.allCases {
            controllerMappings[platform] = DefaultControllerMappings.profile(for: platform)
        }
        // Load custom mappings after defaults to override them
        loadCustomMappings()
    }

    private func loadCustomMappings() {
        let context = PersistenceController.shared.container.viewContext

        for platform in Platform.allCases {
            // Try to load custom mappings for this platform
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ControllerMapping")
            fetchRequest.predicate = NSPredicate(
                format: "platformRaw == %@ AND controllerType == %@",
                platform.rawValue,
                "default"  // Controller type - currently using "default" for all
            )
            fetchRequest.fetchLimit = 1

            do {
                let results = try context.fetch(fetchRequest)
                if let mapping = results.first,
                   let mappingData = mapping.value(forKey: "mappingData") as? String,
                   let data = mappingData.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode([String: String].self, from: data) {

                    // Convert the decoded dictionary to ButtonMapping array
                    var customMappings: [ButtonMapping] = []
                    for (key, value) in decoded {
                        if let button = ControllerButton(rawValue: key),
                           let input = EmulatorInput(rawValue: value) {
                            customMappings.append(ButtonMapping(
                                controllerButton: button,
                                emulatorInput: input
                            ))
                        }
                    }

                    // Override the default mappings with custom ones
                    if !customMappings.isEmpty {
                        controllerMappings[platform] = EmulatorControllerProfile(
                            platform: platform,
                            controllerType: "default",
                            mappings: customMappings,
                            createdAt: Date()
                        )
                    }
                }
            } catch {
                // If loading custom mappings fails, just use defaults
                // No error handling needed as defaults are already loaded
            }
        }
    }

    func setPlatform(_ platform: Platform) {
        self.currentPlatform = platform
    }
    
    func getActiveControllerName() -> String? {
        return activeController?.vendorName ?? activeController?.productCategory
    }
    
    func isControllerConnected() -> Bool {
        return activeController != nil
    }
    
    func getAverageInputLatency() -> TimeInterval? {
        guard !inputLatencySamples.isEmpty else { return nil }
        return inputLatencySamples.reduce(0, +) / Double(inputLatencySamples.count)
    }
    
    func resetLatencySamples() {
        inputLatencySamples.removeAll()
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
        Task { @MainActor [weak self] in
            self?.routeToCore(event: event)
        }
    }

    private func routeToCore(event: InputEvent) {
        guard let core = targetCore else { return }
        let inputType = mapButtonToInputType(event.button)
        guard inputType >= 0 else { return }
        let value: Float = event.isPressed ? 1.0 : 0.0
        core.setInput(inputType, value: value)
    }

    func routeAnalog(x: Float, y: Float, timestamp: TimeInterval) {
        let horizontal: ControllerButton = x >= 0 ? .dpadRight : .dpadLeft
        let vertical: ControllerButton = y >= 0 ? .dpadUp : .dpadDown

        let horizontalEvent = InputEvent(button: horizontal, isPressed: abs(x) > 0.3, timestamp: Date(timeIntervalSince1970: timestamp))
        let verticalEvent = InputEvent(button: vertical, isPressed: abs(y) > 0.3, timestamp: Date(timeIntervalSince1970: timestamp))

        route(horizontalEvent)
        route(verticalEvent)
    }

    // MARK: Emulator Core Integration

    func setTarget(_ core: EmulatorCore) {
        self.targetCore = core
    }

    func clearTarget() {
        self.targetCore = nil
    }

    public var currentPlatform: Platform? {
        didSet {
            if let platform = currentPlatform {
                currentMappingProfile = DefaultControllerMappings.profile(for: platform)
            }
        }
    }
    
    private var currentMappingProfile: EmulatorControllerProfile?
    
    private func mapButtonToInputType(_ button: ControllerButton) -> Int {
        guard let profile = currentMappingProfile,
              let mapping = profile.mappings.first(where: { $0.controllerButton == button }) else {
            return mapButtonToInputTypeDefault(button)
        }
        return emulatorInputToInt(mapping.emulatorInput)
    }
    
    private func mapButtonToInputTypeDefault(_ button: ControllerButton) -> Int {
        switch button {
        case .a: return 0
        case .b: return 1
        case .x: return 2
        case .y: return 3
        case .l, .leftShoulder: return 4
        case .r, .rightShoulder: return 5
        case .select: return 6
        case .start: return 7
        case .menu, .home: return 8
        case .triggerLeft, .leftTrigger: return 9
        case .triggerRight, .rightTrigger: return 10
        case .dpadUp: return 11
        case .dpadDown: return 12
        case .dpadLeft: return 13
        case .dpadRight: return 14
        default: return -1
        }
    }
    
    private func emulatorInputToInt(_ input: EmulatorInput) -> Int {
        switch input {
        case .a: return 0
        case .b: return 1
        case .x: return 2
        case .y: return 3
        case .l: return 4
        case .r: return 5
        case .select: return 6
        case .start: return 7
        case .l2: return 9
        case .r2: return 10
        case .up: return 11
        case .down: return 12
        case .left: return 13
        case .right: return 14
        case .l3: return 15
        case .r3: return 16
        case .z: return 17
        case .cUp: return 18
        case .cDown: return 19
        case .cLeft: return 20
        case .cRight: return 21
        case .touch: return 22
        case .microphone: return 23
        }
    }

    // MARK: GameController Wiring

    private func setupControllerNotifications() {
        NotificationCenter.default.addObserver(forName: .GCControllerDidBecomeCurrent, object: nil, queue: nil) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            Task { @MainActor [weak self] in
                self?.attach(controller: controller)
            }
        }
        
        NotificationCenter.default.addObserver(forName: .GCControllerDidStopBeingCurrent, object: nil, queue: nil) { [weak self] notification in
            guard let controller = notification.object as? GCController else { return }
            Task { @MainActor [weak self] in
                self?.handleControllerDisconnect(controller: controller)
            }
        }

        for controller in GCController.controllers() {
            Task { @MainActor [weak self] in
                self?.attach(controller: controller)
            }
        }
    }

    private func handleControllerDisconnect(controller: GCController) {
        if controller == activeController {
            activeController = nil
            onControllerDisconnected?()
        }
    }
    
    private func isControllerSupported(_ controller: GCController) -> Bool {
        let productCategory = controller.productCategory
        let supportedCategories = [
            "DualSense", "DualShock4", "XboxOne", "Xbox Series", 
            "MFi", "Xbox", "PlayStation"
        ]
        return supportedCategories.contains { productCategory.contains($0) }
    }

    private func attach(controller: GCController) {
        if !isControllerSupported(controller) {
            let name = controller.vendorName ?? controller.productCategory ?? "Unknown Controller"
            onUnsupportedController?(name)
            return
        }
        
        activeController = controller
        let name = controller.vendorName ?? controller.productCategory ?? "Controller"
        onControllerConnected?(name)
        
        controller.extendedGamepad?.valueChangedHandler = { [weak self] gamepad, element in
            let timestamp = Date()

            if let button = self?.button(for: element, gamepad: gamepad) {
                self?.recordLatency(timestamp: timestamp)
                let isPressed = (element as? GCControllerButtonInput)?.isPressed ?? true
                let event = InputEvent(button: button, isPressed: isPressed, timestamp: timestamp)
                self?.route(event)
            } else if element == gamepad.leftThumbstick {
                self?.routeAnalog(x: gamepad.leftThumbstick.xAxis.value, y: gamepad.leftThumbstick.yAxis.value, timestamp: timestamp.timeIntervalSince1970)
            }
        }
    }
    
    private func recordLatency(timestamp: Date) {
        if let lastTimestamp = lastInputTimestamp {
            let latency = timestamp.timeIntervalSince(lastTimestamp)
            inputLatencySamples.append(latency)
            if inputLatencySamples.count > maxLatencySamples {
                inputLatencySamples.removeFirst()
            }
        }
        lastInputTimestamp = timestamp
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
