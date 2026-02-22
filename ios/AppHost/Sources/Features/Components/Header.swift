import SwiftUI

struct Header: View {
    let onSearchTapped: () -> Void
    let onSettingsTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .shadow(color: AppColors.primary.opacity(0.5), radius: 8, x: 0, y: 4)

                        XemuBrandIconGlyph()
                            .frame(width: 26, height: 26)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        Text("XEmu")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)

                        Text("Classic Gaming Hub")
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textMuted)
                    }
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: onSearchTapped) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppColors.surfaceLight.opacity(0.5))
                            .clipShape(Circle())
                    }

                    Button(action: onSettingsTapped) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 32, height: 32)
                            .background(AppColors.surfaceLight.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(AppColors.background.opacity(0.8))
        .overlay(
            Rectangle()
                .fill(AppColors.surfaceLight.opacity(0.5))
                .frame(height: 1),
            alignment: .bottom
        )
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
        onSearchTapped: {},
        onSettingsTapped: {}
    )
    .background(AppColors.background)
}
