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
                        .frame(width: 56, height: 56)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)

                    Text(description)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.primary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .opacity(0.5)
            }
            .padding(18)
            .background(cardBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardStrokeColor, lineWidth: 1)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowYOffset)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var isUpgrade: Bool {
        title == "Upgrade"
    }

    @ViewBuilder
    private var cardBackground: some View {
        if isUpgrade {
            LinearGradient(
                colors: [AppColors.primary.opacity(0.10), AppColors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            AppColors.surface
        }
    }

    private var cardStrokeColor: Color {
        isUpgrade ? AppColors.primary.opacity(0.28) : AppColors.surfaceLight.opacity(0.5)
    }

    private var shadowColor: Color {
        isUpgrade ? AppColors.primary.opacity(0.16) : AppColors.primary.opacity(0.05)
    }

    private var shadowRadius: CGFloat {
        isUpgrade ? 14 : 8
    }

    private var shadowYOffset: CGFloat {
        isUpgrade ? 8 : 4
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
