import SwiftUI

struct TouchControlsView: View {
    let system: Platform
    
    @State private var showSettings = false
    @State private var opacity: Double = 0.7
    
    private let buttonSize: CGFloat = 60
    private let dpadSize: CGFloat = 120
    
    var body: some View {
        GeometryReader { _ in
            ZStack {
                VStack {
                    Spacer()
                    
                    HStack {
                        dpadView
                        
                        Spacer()
                        
                        actionButtons
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
                
                VStack {
                    HStack {
                        Spacer()
                        menuButton
                    }
                    Spacer()
                }
                .padding()
            }
        }
        .opacity(opacity)
    }
    
    private var menuButton: some View {
        Button(action: {
            // Menu button - pause game
        }) {
            Image(systemName: "line.3.horizontal")
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
        }
    }
    
    private var dpadView: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.3))
                .frame(width: dpadSize, height: dpadSize)
            
            VStack(spacing: 0) {
                dpadButton(systemName: "chevron.up", tag: 0)
                HStack(spacing: 0) {
                    dpadButton(systemName: "chevron.left", tag: 1)
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 40, height: 40)
                    dpadButton(systemName: "chevron.right", tag: 2)
                }
                dpadButton(systemName: "chevron.down", tag: 3)
            }
        }
    }
    
    private func dpadButton(systemName: String, tag: Int) -> some View {
        Button(action: {
            // D-pad input handling - to be connected to InputBus
        }) {
            Image(systemName: systemName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: buttonSize, height: buttonSize)
                .background(Color.white.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 15) {
            HStack(spacing: 20) {
                actionButton(systemName: "xmark", color: .red)
                actionButton(systemName: "checkmark", color: .green)
            }
            
            HStack(spacing: 20) {
                actionButton(systemName: "square", color: .blue)
                actionButton(systemName: "triangle", color: .yellow)
            }
            
            HStack(spacing: 20) {
                actionButton(systemName: "playpause.fill", color: .purple)
                actionButton(systemName: "pause.fill", color: .orange)
            }
        }
    }
    
    private func actionButton(systemName: String, color: Color) -> some View {
        Button(action: {
            // Action button input handling - to be connected to InputBus
        }) {
            Image(systemName: systemName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: buttonSize, height: buttonSize)
                .background(color.opacity(0.7))
                .clipShape(Circle())
        }
    }
}

#Preview {
    TouchControlsView(system: .NES)
}
