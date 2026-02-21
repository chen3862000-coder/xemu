import Foundation

public enum EmulatorInput: String, Codable, Sendable {
    case a
    case b
    case x
    case y
    case start
    case select
    case up
    case down
    case left
    case right
    case l
    case r
    case z
    case cUp
    case cDown
    case cLeft
    case cRight
    case l2
    case r2
    case l3
    case r3
    case touch
    case microphone
}

public struct ButtonMapping: Codable, Sendable {
    public let controllerButton: ControllerButton
    public let emulatorInput: EmulatorInput
    
    public init(controllerButton: ControllerButton, emulatorInput: EmulatorInput) {
        self.controllerButton = controllerButton
        self.emulatorInput = emulatorInput
    }
}

public struct EmulatorControllerProfile: Codable, Sendable {
    public let platform: Platform
    public let controllerType: String
    public let mappings: [ButtonMapping]
    public let createdAt: Date
    
    public init(platform: Platform, controllerType: String, mappings: [ButtonMapping], createdAt: Date = Date()) {
        self.platform = platform
        self.controllerType = controllerType
        self.mappings = mappings
        self.createdAt = createdAt
    }
}

public enum DefaultControllerMappings {
    public static func mappings(for platform: Platform) -> [ButtonMapping] {
        switch platform {
        case .NES:
            return nesMappings
        case .GB, .GBC:
            return gbMappings
        case .GBA:
            return gbaMappings
        case .GENESIS:
            return genesisMappings
        case .NDS:
            return ndsMappings
        case .PS1:
            return ps1Mappings
        case .PS2:
            return ps1Mappings
        case ._3DS:
            return ndsMappings
        }
    }
    
    public static func profile(for platform: Platform, controllerType: String = "generic") -> EmulatorControllerProfile {
        EmulatorControllerProfile(
            platform: platform,
            controllerType: controllerType,
            mappings: mappings(for: platform)
        )
    }
    
    private static let nesMappings: [ButtonMapping] = [
        ButtonMapping(controllerButton: .a, emulatorInput: .a),
        ButtonMapping(controllerButton: .b, emulatorInput: .b),
        ButtonMapping(controllerButton: .start, emulatorInput: .start),
        ButtonMapping(controllerButton: .select, emulatorInput: .select),
        ButtonMapping(controllerButton: .dpadUp, emulatorInput: .up),
        ButtonMapping(controllerButton: .dpadDown, emulatorInput: .down),
        ButtonMapping(controllerButton: .dpadLeft, emulatorInput: .left),
        ButtonMapping(controllerButton: .dpadRight, emulatorInput: .right)
    ]
    
    private static let gbMappings: [ButtonMapping] = [
        ButtonMapping(controllerButton: .a, emulatorInput: .a),
        ButtonMapping(controllerButton: .b, emulatorInput: .b),
        ButtonMapping(controllerButton: .start, emulatorInput: .start),
        ButtonMapping(controllerButton: .select, emulatorInput: .select),
        ButtonMapping(controllerButton: .dpadUp, emulatorInput: .up),
        ButtonMapping(controllerButton: .dpadDown, emulatorInput: .down),
        ButtonMapping(controllerButton: .dpadLeft, emulatorInput: .left),
        ButtonMapping(controllerButton: .dpadRight, emulatorInput: .right)
    ]
    
    private static let gbaMappings: [ButtonMapping] = [
        ButtonMapping(controllerButton: .a, emulatorInput: .a),
        ButtonMapping(controllerButton: .b, emulatorInput: .b),
        ButtonMapping(controllerButton: .start, emulatorInput: .start),
        ButtonMapping(controllerButton: .select, emulatorInput: .select),
        ButtonMapping(controllerButton: .dpadUp, emulatorInput: .up),
        ButtonMapping(controllerButton: .dpadDown, emulatorInput: .down),
        ButtonMapping(controllerButton: .dpadLeft, emulatorInput: .left),
        ButtonMapping(controllerButton: .dpadRight, emulatorInput: .right),
        ButtonMapping(controllerButton: .leftShoulder, emulatorInput: .l),
        ButtonMapping(controllerButton: .rightShoulder, emulatorInput: .r)
    ]
    
    private static let genesisMappings: [ButtonMapping] = [
        ButtonMapping(controllerButton: .a, emulatorInput: .a),
        ButtonMapping(controllerButton: .b, emulatorInput: .b),
        ButtonMapping(controllerButton: .x, emulatorInput: .x),
        ButtonMapping(controllerButton: .y, emulatorInput: .y),
        ButtonMapping(controllerButton: .start, emulatorInput: .start),
        ButtonMapping(controllerButton: .dpadUp, emulatorInput: .up),
        ButtonMapping(controllerButton: .dpadDown, emulatorInput: .down),
        ButtonMapping(controllerButton: .dpadLeft, emulatorInput: .left),
        ButtonMapping(controllerButton: .dpadRight, emulatorInput: .right),
        ButtonMapping(controllerButton: .leftShoulder, emulatorInput: .l),
        ButtonMapping(controllerButton: .rightShoulder, emulatorInput: .r)
    ]
    
    private static let ndsMappings: [ButtonMapping] = [
        ButtonMapping(controllerButton: .a, emulatorInput: .a),
        ButtonMapping(controllerButton: .b, emulatorInput: .b),
        ButtonMapping(controllerButton: .x, emulatorInput: .x),
        ButtonMapping(controllerButton: .y, emulatorInput: .y),
        ButtonMapping(controllerButton: .start, emulatorInput: .start),
        ButtonMapping(controllerButton: .select, emulatorInput: .select),
        ButtonMapping(controllerButton: .dpadUp, emulatorInput: .up),
        ButtonMapping(controllerButton: .dpadDown, emulatorInput: .down),
        ButtonMapping(controllerButton: .dpadLeft, emulatorInput: .left),
        ButtonMapping(controllerButton: .dpadRight, emulatorInput: .right),
        ButtonMapping(controllerButton: .leftShoulder, emulatorInput: .l),
        ButtonMapping(controllerButton: .rightShoulder, emulatorInput: .r),
        ButtonMapping(controllerButton: .leftStick, emulatorInput: .touch)
    ]
    
    private static let ps1Mappings: [ButtonMapping] = [
        ButtonMapping(controllerButton: .a, emulatorInput: .a),
        ButtonMapping(controllerButton: .b, emulatorInput: .b),
        ButtonMapping(controllerButton: .x, emulatorInput: .x),
        ButtonMapping(controllerButton: .y, emulatorInput: .y),
        ButtonMapping(controllerButton: .start, emulatorInput: .start),
        ButtonMapping(controllerButton: .select, emulatorInput: .select),
        ButtonMapping(controllerButton: .dpadUp, emulatorInput: .up),
        ButtonMapping(controllerButton: .dpadDown, emulatorInput: .down),
        ButtonMapping(controllerButton: .dpadLeft, emulatorInput: .left),
        ButtonMapping(controllerButton: .dpadRight, emulatorInput: .right),
        ButtonMapping(controllerButton: .leftShoulder, emulatorInput: .l),
        ButtonMapping(controllerButton: .rightShoulder, emulatorInput: .r),
        ButtonMapping(controllerButton: .leftTrigger, emulatorInput: .l2),
        ButtonMapping(controllerButton: .rightTrigger, emulatorInput: .r2),
        ButtonMapping(controllerButton: .leftStick, emulatorInput: .l3),
        ButtonMapping(controllerButton: .rightStick, emulatorInput: .r3)
    ]
    
    public static func toData(_ mappings: [ButtonMapping]) -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(mappings) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    public static func fromData(_ data: String) -> [ButtonMapping]? {
        guard let jsonData = data.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode([ButtonMapping].self, from: jsonData)
    }
}
