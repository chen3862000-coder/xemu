import SwiftUI

struct SettingsHeader: View {
    let onBackTapped: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button(action: onBackTapped) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.surfaceLight.opacity(0.5))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Settings")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.primary)

                    Text("Manage your preferences")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.primary.opacity(0.9))
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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
    SettingsHeader(onBackTapped: {})
        .background(AppColors.background)
}
