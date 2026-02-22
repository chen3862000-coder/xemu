import SwiftUI

public struct VirtualPadView: View {
    let platform: Platform
    let onButtonPress: (EmulatorButton, Bool) -> Void
    
    public init(platform: Platform, onButtonPress: @escaping (EmulatorButton, Bool) -> Void) {
        self.platform = platform
        self.onButtonPress = onButtonPress
    }
    
    public var body: some View {
        HStack {
            dPad
            Spacer()
            rightControls
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
    }
    
    private var rightControls: some View {
        VStack(spacing: 12) {
            if hasShoulderButtons {
                shoulderButtons
                Spacer().frame(height: 30)
            }
            faceButtons
            Spacer().frame(height: 16)
            menuButtons
        }
    }
    
    private var hasShoulderButtons: Bool {
        switch platform {
        case .GBA, .NDS:
            return true
        default:
            return false
        }
    }
    
    private var dPad: some View {
        DPadButtonGridView { button, pressed in
            sendButton(button, pressed: pressed)
        }
    }

    private func sendButton(_ button: EmulatorButton, pressed: Bool) {
        onButtonPress(button, pressed)
    }
    
    private var shoulderButtons: some View {
        HStack(spacing: 50) {
            shoulderButton(.l1, label: "L")
            shoulderButton(.r1, label: "R")
        }
    }
    
    private func shoulderButton(_ button: EmulatorButton, label: String) -> some View {
        ButtonActionView(
            onPress: { sendButton(button, pressed: true) },
            onRelease: { sendButton(button, pressed: false) }
        ) { isPressed in
            Text(label)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white.opacity(isPressed ? 1.0 : 0.8))
                .frame(width: 50, height: 30)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(isPressed ? 0.4 : 0.2))
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
    }
    
    private var faceButtons: some View {
        let buttonSize: CGFloat = 50
        let spacing: CGFloat = 6
        
        return Group {
            if platform == .GB || platform == .GBC {
                HStack(spacing: spacing) {
                    faceButton(.b, label: "B", size: buttonSize)
                    faceButton(.a, label: "A", size: buttonSize)
                }
            } else {
                VStack(spacing: spacing) {
                    faceButton(.x, label: "X", size: buttonSize)
                    HStack(spacing: spacing) {
                        faceButton(.y, label: "Y", size: buttonSize)
                        Color.clear.frame(width: buttonSize, height: buttonSize)
                        faceButton(.a, label: "A", size: buttonSize)
                    }
                    faceButton(.b, label: "B", size: buttonSize)
                }
            }
        }
    }
    
    private func faceButton(_ button: EmulatorButton, label: String, size: CGFloat) -> some View {
        ButtonActionView(
            onPress: { sendButton(button, pressed: true) },
            onRelease: { sendButton(button, pressed: false) }
        ) { isPressed in
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isPressed ? 0.5 : 0.2))
                    .frame(width: size, height: size)
                Text(label)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white.opacity(isPressed ? 1.0 : 0.9))
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
    }
    
    private var menuButtons: some View {
        HStack(spacing: 24) {
            menuButton(.select, label: "SELECT")
            menuButton(.start, label: "START")
        }
    }
    
    private func menuButton(_ button: EmulatorButton, label: String) -> some View {
        ButtonActionView(
            onPress: { sendButton(button, pressed: true) },
            onRelease: { sendButton(button, pressed: false) }
        ) { isPressed in
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(.white.opacity(isPressed ? 1.0 : 0.7))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(isPressed ? 0.3 : 0.15))
                )
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
    }
}

private struct DPadButtonGridView: View {
    let onButtonPress: (EmulatorButton, Bool) -> Void

    var body: some View {
        VStack(spacing: 8) {
            directionalButton(.dpadUp, icon: "chevron.up")
            HStack(spacing: 8) {
                directionalButton(.dpadLeft, icon: "chevron.left")
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 52, height: 52)
                directionalButton(.dpadRight, icon: "chevron.right")
            }
            directionalButton(.dpadDown, icon: "chevron.down")
        }
        .frame(width: 170, height: 170)
    }

    private func directionalButton(_ button: EmulatorButton, icon: String) -> some View {
        ButtonActionView(
            onPress: { onButtonPress(button, true) },
            onRelease: { onButtonPress(button, false) }
        ) { isPressed in
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isPressed ? 0.45 : 0.18))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white.opacity(isPressed ? 1.0 : 0.82))
                )
                .contentShape(Rectangle())
                .scaleEffect(isPressed ? 0.92 : 1.0)
                .animation(.easeInOut(duration: 0.08), value: isPressed)
        }
    }
}

private struct ButtonActionView<Label: View>: View {
    let onPress: () -> Void
    let onRelease: () -> Void
    let label: (Bool) -> Label
    @State private var isPressed = false
    
    init(
        onPress: @escaping () -> Void,
        onRelease: @escaping () -> Void,
        @ViewBuilder label: @escaping (Bool) -> Label
    ) {
        self.onPress = onPress
        self.onRelease = onRelease
        self.label = label
    }
    
    var body: some View {
        label(isPressed)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        if isPressed {
                            isPressed = false
                            onRelease()
                        }
                    }
            )
            .onDisappear {
                if isPressed {
                    isPressed = false
                    onRelease()
                }
            }
    }
}
