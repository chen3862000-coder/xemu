import SwiftUI

struct Header: View {
    let onAddTapped: () -> Void
    let onSettingsTapped: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Circle()
                .fill(AppColors.Shadow.ambientGlow)
                .frame(width: 84, height: 84)
                .blur(radius: 28)
                .offset(x: 8, y: 2)

            HStack(alignment: .center) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 38, height: 38)
                            .shadow(color: AppColors.Shadow.ambientGlow.opacity(0.8), radius: 8, x: 0, y: 4)

                        XemuBrandIconGlyph()
                            .frame(width: 26, height: 26)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("RetroMind")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppColors.Text.primary)

                        Text("Classic Gaming Hub")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.Text.tertiary)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onAddTapped) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .buttonStyle(RMIconCircleButtonStyle())

                    Button(action: onSettingsTapped) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .buttonStyle(RMIconCircleButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
        }
        .background(AppColors.Background.appPrimary)
    }
}

private struct XemuBrandIconGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.18))

            // D-pad (left)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.white.opacity(0.95))
                .frame(width: 3.5, height: 10)
                .offset(x: -7, y: 1)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.white.opacity(0.95))
                .frame(width: 10, height: 3.5)
                .offset(x: -7, y: 1)

            // Buttons (right)
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 3.2, height: 3.2)
                .offset(x: -1.5, y: -4)
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 3.2, height: 3.2)
                .offset(x: 4.5, y: -4)
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 3.2, height: 3.2)
                .offset(x: -1.5, y: 2)
            Circle()
                .fill(Color.white.opacity(0.95))
                .frame(width: 3.2, height: 3.2)
                .offset(x: 4.5, y: 2)

            // Lightning bolt
            Path { path in
                path.move(to: CGPoint(x: 13.8, y: 2.5))
                path.addLine(to: CGPoint(x: 10.8, y: 9.2))
                path.addLine(to: CGPoint(x: 13.2, y: 9.2))
                path.addLine(to: CGPoint(x: 11.4, y: 15.8))
                path.addLine(to: CGPoint(x: 15.6, y: 8.2))
                path.addLine(to: CGPoint(x: 13.0, y: 8.2))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color(hex: "FBBF24"), Color(hex: "F59E0B")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 26, height: 26)
        }
    }
}

#Preview {
    Header(
        onAddTapped: {},
        onSettingsTapped: {}
    )
    .background(AppColors.background)
}
