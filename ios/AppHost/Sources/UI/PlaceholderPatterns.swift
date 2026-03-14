import SwiftUI

struct PixelGridPattern: View {
    let gridSize: CGFloat = 16
    
    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, to: size.width, by: gridSize) {
                for y in stride(from: 0, to: size.height, by: gridSize) {
                    if Int(x / gridSize) % 2 == Int(y / gridSize) % 2 {
                        let rect = CGRect(x: x, y: y, width: gridSize, height: gridSize)
                        context.fill(Path(rect), with: .color(.white))
                    }
                }
            }
        }
    }
}

struct DiagonalPattern: View {
    let stripeWidth: CGFloat = 24
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                var x: CGFloat = -size.height
                while x < size.width + size.height {
                    let path = Path { p in
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x + stripeWidth, y: 0))
                        p.addLine(to: CGPoint(x: x + stripeWidth + size.height, y: size.height))
                        p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                        p.closeSubpath()
                    }
                    context.fill(path, with: .color(.white))
                    x += stripeWidth * 2
                }
            }
        }
    }
}

struct RectangleOutlinePattern: View {
    let rectWidth: CGFloat = 40
    let rectHeight: CGFloat = 28
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                var x: CGFloat = 16
                while x < size.width - rectWidth {
                    var y: CGFloat = 16
                    while y < size.height - rectHeight {
                        let rect = CGRect(x: x, y: y, width: rectWidth, height: rectHeight)
                        context.stroke(Path(rect), with: .color(.white), lineWidth: 1)
                        y += rectHeight + 8
                    }
                    x += rectWidth + 8
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PixelGridPattern()
            .frame(width: 100, height: 150)
            .background(Color.gray.opacity(0.3))
        
        DiagonalPattern()
            .frame(width: 100, height: 150)
            .background(Color.gray.opacity(0.3))
        
        RectangleOutlinePattern()
            .frame(width: 100, height: 150)
            .background(Color.gray.opacity(0.3))
    }
}
