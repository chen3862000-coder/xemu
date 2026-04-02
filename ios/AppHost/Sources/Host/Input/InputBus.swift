import Foundation
import CoreData
@preconcurrency import GameController

@MainActor
final class InputBus: InputRouting {
    static let shared = InputBus()

    private let queue = DispatchQueue(label: "com.xemu.inputbus", qos: .userInteractive)
    private var listeners: [UUID: @Sendable (InputEvent) -> Void] = [:]
    private var controllerConnectedObservers: [UUID: @MainActor (String) -> Void] = [:]
    private var controllerDisconnectedObservers: [UUID: @MainActor () -> Void] = [:]
    private var unsupportedControllerObservers: [UUID: @MainActor (String) -> Void] = [:]
    private var isTesting = false
    private weak var targetCore: EmulatorCore?
    private var activeController: GCController?
    private var controllerMappings: [Platform: EmulatorControllerProfile] = [:]
    private var lastInputTimestamp: Date?
    private var inputLatencySamples: [TimeInterval] = []
    private let maxLatencySamples = 100

    // Controller settings
    private var stickSensitivity: StickSensitivity {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: "settings.controller.stickSensitivity"),
                  let sensitivity = StickSensitivity(rawValue: rawValue) else {
                return .medium
            }
            return sensitivity
        }
    }

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
            reloadMappings(for: platform, controllerType: "default", in: context)
        }
    }

    func setPlatform(_ platform: Platform) {
        self.currentPlatform = platform
    }

    func reloadMappings(for platform: Platform, controllerType: String = "default") {
        reloadMappings(for: platform, controllerType: controllerType, in: PersistenceController.shared.container.viewContext)
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

    func addControllerObserver(
        onConnected: (@MainActor (String) -> Void)? = nil,
        onDisconnected: (@MainActor () -> Void)? = nil,
        onUnsupported: (@MainActor (String) -> Void)? = nil
    ) -> UUID {
        let token = UUID()
        if let onConnected {
            controllerConnectedObservers[token] = onConnected
        }
        if let onDisconnected {
            controllerDisconnectedObservers[token] = onDisconnected
        }
        if let onUnsupported {
            unsupportedControllerObservers[token] = onUnsupported
        }
        return token
    }

    func removeControllerObserver(_ token: UUID) {
        controllerConnectedObservers[token] = nil
        controllerDisconnectedObservers[token] = nil
        unsupportedControllerObservers[token] = nil
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
        let threshold = stickSensitivity.threshold
        let horizontal: ControllerButton = x >= 0 ? .dpadRight : .dpadLeft
        let vertical: ControllerButton = y >= 0 ? .dpadUp : .dpadDown

        let horizontalEvent = InputEvent(button: horizontal, isPressed: abs(x) > threshold, timestamp: Date(timeIntervalSince1970: timestamp))
        let verticalEvent = InputEvent(button: vertical, isPressed: abs(y) > threshold, timestamp: Date(timeIntervalSince1970: timestamp))

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
                currentMappingProfile = controllerMappings[platform] ?? DefaultControllerMappings.profile(for: platform)
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
            notifyControllerDisconnected()
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
            notifyUnsupportedController(name)
            return
        }
        
        activeController = controller
        let name = controller.vendorName ?? controller.productCategory ?? "Controller"
        notifyControllerConnected(name)
        
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
        case gamepad.leftShoulder: return .leftShoulder
        case gamepad.rightShoulder: return .rightShoulder
        case gamepad.leftTrigger: return .leftTrigger
        case gamepad.rightTrigger: return .rightTrigger
        case gamepad.buttonMenu: return .menu
        case gamepad.buttonOptions: return .start
        default: return nil
        }
    }

    private func reloadMappings(for platform: Platform, controllerType: String, in context: NSManagedObjectContext) {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ControllerMapping")
        fetchRequest.predicate = NSPredicate(
            format: "platformRaw == %@ AND controllerType == %@",
            platform.rawValue,
            controllerType
        )
        fetchRequest.fetchLimit = 1

        do {
            let results = try context.fetch(fetchRequest)
            guard
                let mapping = results.first,
                let mappingData = mapping.value(forKey: "mappingData") as? String,
                let customMappings = decodeMappings(from: mappingData),
                !customMappings.isEmpty
            else {
                controllerMappings[platform] = DefaultControllerMappings.profile(for: platform, controllerType: controllerType)
                refreshCurrentProfileIfNeeded(for: platform)
                return
            }

            controllerMappings[platform] = EmulatorControllerProfile(
                platform: platform,
                controllerType: controllerType,
                mappings: customMappings,
                createdAt: Date()
            )
            refreshCurrentProfileIfNeeded(for: platform)
        } catch {
            controllerMappings[platform] = DefaultControllerMappings.profile(for: platform, controllerType: controllerType)
            refreshCurrentProfileIfNeeded(for: platform)
        }
    }

    private func refreshCurrentProfileIfNeeded(for platform: Platform) {
        guard currentPlatform == platform else { return }
        currentMappingProfile = controllerMappings[platform] ?? DefaultControllerMappings.profile(for: platform)
    }

    private func decodeMappings(from rawValue: String) -> [ButtonMapping]? {
        if let decoded = DefaultControllerMappings.fromData(rawValue) {
            return decoded
        }

        guard
            let data = rawValue.data(using: .utf8),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return nil
        }

        return decoded.compactMap { key, value in
            guard let button = ControllerButton(rawValue: key),
                  let input = EmulatorInput(rawValue: value) else {
                return nil
            }

            return ButtonMapping(controllerButton: button, emulatorInput: input)
        }
    }

    private func notifyControllerConnected(_ name: String) {
        for observer in controllerConnectedObservers.values {
            observer(name)
        }
    }

    private func notifyControllerDisconnected() {
        for observer in controllerDisconnectedObservers.values {
            observer()
        }
    }

    private func notifyUnsupportedController(_ name: String) {
        for observer in unsupportedControllerObservers.values {
            observer(name)
        }
    }
}

// MARK: - Stick Sensitivity
private enum StickSensitivity: String {
    case low
    case medium
    case high

    var threshold: Float {
        switch self {
        case .low: return 0.2    // More sensitive - easier to trigger
        case .medium: return 0.3  // Default sensitivity
        case .high: return 0.45   // Less sensitive - harder to trigger
        }
    }
}
