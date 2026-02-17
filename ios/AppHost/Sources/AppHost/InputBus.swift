import Foundation
import Combine

public enum InputType: String, Codable, Equatable {
    case buttonA = "buttonA"
    case buttonB = "buttonB"
    case buttonX = "buttonX"
    case buttonY = "buttonY"
    case dpadUp = "dpadUp"
    case dpadDown = "dpadDown"
    case dpadLeft = "dpadLeft"
    case dpadRight = "dpadRight"
    case start = "start"
    case select = "select"
    case shoulderL = "shoulderL"
    case shoulderR = "shoulderR"
    case triggerL = "triggerL"
    case triggerR = "triggerR"
}

public struct InputEvent: Codable, Equatable {
    public let type: InputType
    public let player: Int
    public let value: Double
    public let timestamp: Date
    
    public init(type: InputType, player: Int, value: Double, timestamp: Date) {
        self.type = type
        self.player = player
        self.value = value
        self.timestamp = timestamp
    }
}

public final class InputBus: @unchecked Sendable {
    public let events = PassthroughSubject<InputEvent, Never>()
    
    public init() {}
    
    public func send(_ event: InputEvent) {
        events.send(event)
    }
    
    public func clear() {
        events.send(completion: .finished)
    }
}
