import SwiftUI
import GameController

struct TouchControlPad: View {
    let onButtonPress: (EmulatorButton, Bool) -> Void
    var hapticManager: HapticManager? = HapticManager.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                DPadControl(onButtonPress: onButtonPress, hapticManager: hapticManager)
                    .position(x: geometry.size.width * 0.25, y: geometry.size.height * 0.7)
                    .frame(width: geometry.size.width * 0.4, height: geometry.size.height * 0.3)

                ButtonControl(onButtonPress: onButtonPress, hapticManager: hapticManager)
                    .position(x: geometry.size.width * 0.75, y: geometry.size.height * 0.7)
                    .frame(width: geometry.size.width * 0.4, height: geometry.size.height * 0.3)
            }
        }
    }
}

struct DPadControl: View {
    let onButtonPress: (EmulatorButton, Bool) -> Void
    var hapticManager: HapticManager?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: 120, height: 120)

            Button(action: { onButtonPress(.dpadUp, true) }) {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
                if pressing { hapticManager?.buttonPressed() }
                onButtonPress(.dpadUp, pressing)
            }, perform: {})
            .position(x: 0, y: -35)

            Button(action: { onButtonPress(.dpadDown, true) }) {
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
                if pressing { hapticManager?.buttonPressed() }
                onButtonPress(.dpadDown, pressing)
            }, perform: {})
            .position(x: 0, y: 35)

            Button(action: { onButtonPress(.dpadLeft, true) }) {
                Image(systemName: "arrowtriangle.left.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
                if pressing { hapticManager?.buttonPressed() }
                onButtonPress(.dpadLeft, pressing)
            }, perform: {})
            .position(x: -35, y: 0)

            Button(action: { onButtonPress(.dpadRight, true) }) {
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
                if pressing { hapticManager?.buttonPressed() }
                onButtonPress(.dpadRight, pressing)
            }, perform: {})
            .position(x: 35, y: 0)
        }
    }
}

struct ButtonControl: View {
    let onButtonPress: (EmulatorButton, Bool) -> Void
    var hapticManager: HapticManager?

    var body: some View {
        ZStack {
            ABButton(button: .a, label: "A", position: (x: 35, y: -20), onButtonPress: onButtonPress, hapticManager: hapticManager)
            ABButton(button: .b, label: "B", position: (x: -35, y: 20), onButtonPress: onButtonPress, hapticManager: hapticManager)
            XYButton(button: .x, label: "X", position: (x: -35, y: -20), onButtonPress: onButtonPress, hapticManager: hapticManager)
            XYButton(button: .y, label: "Y", position: (x: 35, y: 20), onButtonPress: onButtonPress, hapticManager: hapticManager)
        }
    }
}

struct ABButton: View {
    let button: EmulatorButton
    let label: String
    let position: (x: CGFloat, y: CGFloat)
    let onButtonPress: (EmulatorButton, Bool) -> Void
    var hapticManager: HapticManager?

    var body: some View {
        Button(action: { onButtonPress(button, true) }) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.6))
                    .frame(width: 50, height: 50)

                Text(label)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            if pressing { hapticManager?.buttonPressed() }
            onButtonPress(button, pressing)
        }, perform: {})
        .position(x: position.x, y: position.y)
    }
}

struct XYButton: View {
    let button: EmulatorButton
    let label: String
    let position: (x: CGFloat, y: CGFloat)
    let onButtonPress: (EmulatorButton, Bool) -> Void
    var hapticManager: HapticManager?

    var body: some View {
        Button(action: { onButtonPress(button, true) }) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.6))
                    .frame(width: 50, height: 50)

                Text(label)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
        }
        .onLongPressGesture(minimumDuration: 0, pressing: { pressing in
            if pressing { hapticManager?.buttonPressed() }
            onButtonPress(button, pressing)
        }, perform: {})
        .position(x: position.x, y: position.y)
    }
}

#Preview {
    TouchControlPad { button, pressed in
        _ = button
        _ = pressed
    }
}
