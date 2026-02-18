import SwiftUI

struct IPhoneMockup<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "0F172A"),
                    Color(hex: "4C1D95"),
                    Color(hex: "0F172A")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 60)
                        .fill(Color.black)
                        .frame(width: 390, height: 844)
                        .overlay(
                            RoundedRectangle(cornerRadius: 60)
                                .stroke(Color(hex: "1E293B"), lineWidth: 14)
                        )

                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.black)
                            .frame(width: 150, height: 30)
                            .position(x: 195, y: 17)

                        content
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 60))
                }
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 20)

                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color(hex: "1E293B"))
                        .frame(width: 3, height: 30)
                        .position(x: 9, y: 120)

                    Rectangle()
                        .fill(Color(hex: "1E293B"))
                        .frame(width: 3, height: 60)
                        .position(x: 9, y: 170)

                    Rectangle()
                        .fill(Color(hex: "1E293B"))
                        .frame(width: 3, height: 60)
                        .position(x: 9, y: 240)

                    Rectangle()
                        .fill(Color(hex: "1E293B"))
                        .frame(width: 3, height: 80)
                        .position(x: 399, y: 200)
                }

                Spacer()
            }
            .padding(32)
        }
    }
}

struct IPhoneMockup_Previews: PreviewProvider {
    static var previews: some View {
        IPhoneMockup {
            VStack {
                Text("Hello, XEmu!")
                    .font(.title)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.blue)
        }
    }
}
