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

                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
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

#Preview {
    Header(
        onSearchTapped: {},
        onSettingsTapped: {}
    )
    .background(AppColors.background)
}
