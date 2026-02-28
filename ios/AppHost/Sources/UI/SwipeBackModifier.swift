import SwiftUI

struct SwipeBackModifier: ViewModifier {
    let action: () -> Void
    @State private var dragStartX: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(coordinateSpace: .global)
                    .onChanged { value in
                        // Only start tracking from left edge of screen (first 30 points)
                        if dragStartX == 0 && value.startLocation.x < 30 {
                            dragStartX = value.startLocation.x
                        }
                    }
                    .onEnded { value in
                        // Only trigger if started from left edge
                        if dragStartX < 30 {
                            // Swipe right: large horizontal + small vertical movement
                            if value.translation.width > 80 && abs(value.translation.height) < 80 {
                                action()
                            }
                        }
                        dragStartX = 0
                    }
            )
    }
}

extension View {
    func swipeBack(action: @escaping () -> Void) -> some View {
        modifier(SwipeBackModifier(action: action))
    }
}
