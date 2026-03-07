import Foundation

struct TouchPressTracker {
    enum Transition: Equatable {
        case none
        case pressed
        case released
    }

    private(set) var isPressed = false

    mutating func transition(for pressing: Bool) -> Transition {
        guard pressing != isPressed else {
            return .none
        }
        isPressed = pressing
        return pressing ? .pressed : .released
    }

    mutating func reset() -> Bool {
        let wasPressed = isPressed
        isPressed = false
        return wasPressed
    }
}
