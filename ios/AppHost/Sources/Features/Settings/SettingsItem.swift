import SwiftUI

struct SettingsItem: View {
    let icon: String
    let title: String
    let description: String
    let iconColor: Color
    let iconBackground: Color
    let index: Int
    let onTap: () -> Void

    init(
        icon: String,
        title: String,
        description: String,
        iconColor: Color,
        iconBackground: Color,
        index: Int = 0,
        onTap: @escaping () -> Void
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.iconColor = iconColor
        self.iconBackground = iconBackground
        self.index = index
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(iconBackground)
                        .frame(width: 48, height: 48)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)

                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
                    .opacity(0.5)
            }
            .padding(16)
            .background(AppColors.surface)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsItem_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            SettingsItem(
                icon: "gamecontroller.fill",
                title: "Controllers",
                description: "Configure game controllers",
                iconColor: AppColors.primary,
                iconBackground: AppColors.primary.opacity(0.2),
                index: 0,
                onTap: {}
            )

            SettingsItem(
                icon: "paintbrush.fill",
                title: "Display",
                description: "Screen and video settings",
                iconColor: AppColors.accent,
                iconBackground: AppColors.accent.opacity(0.2),
                index: 1,
                onTap: {}
            )

            SettingsItem(
                icon: "speaker.wave.2.fill",
                title: "Audio",
                description: "Sound and volume settings",
                iconColor: AppColors.success,
                iconBackground: AppColors.success.opacity(0.2),
                index: 2,
                onTap: {}
            )
        }
        .padding()
        .background(AppColors.background)
    }
}
