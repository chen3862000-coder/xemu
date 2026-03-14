import SwiftUI

enum RMChipStyle {
    case regular
    case compact

    var titleFont: Font {
        switch self {
        case .regular: return .system(size: 13, weight: .semibold)
        case .compact: return .system(size: 12, weight: .semibold)
        }
    }

    var countFont: Font {
        switch self {
        case .regular: return .system(size: 11, weight: .semibold)
        case .compact: return .system(size: 10, weight: .semibold)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .regular: return 14
        case .compact: return 12
        }
    }

    var height: CGFloat {
        switch self {
        case .regular: return 38
        case .compact: return 34
        }
    }

    var badgeHeight: CGFloat {
        switch self {
        case .regular: return 20
        case .compact: return 18
        }
    }

    var interItemSpacing: CGFloat {
        switch self {
        case .regular: return 8
        case .compact: return 6
        }
    }
}

enum RMCardElevation {
    case level1
    case level2
    case level3

    var fill: Color {
        switch self {
        case .level1: return AppColors.Surface.cardPrimary
        case .level2: return AppColors.Surface.cardSecondary
        case .level3: return AppColors.Surface.cardElevated
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .level1: return 10
        case .level2: return 14
        case .level3: return 18
        }
    }

    var shadowYOffset: CGFloat {
        switch self {
        case .level1: return 5
        case .level2: return 8
        case .level3: return 10
        }
    }
}

struct RMCardContainer<Content: View>: View {
    let cornerRadius: CGFloat
    let elevation: RMCardElevation
    let selected: Bool
    let glow: Bool
    let content: Content

    init(
        cornerRadius: CGFloat = 24,
        elevation: RMCardElevation = .level1,
        selected: Bool = false,
        glow: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.elevation = elevation
        self.selected = selected
        self.glow = glow
        self.content = content()
    }

    var body: some View {
        content
            .background(elevation.fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(selected ? AppColors.Border.active : AppColors.Border.subtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(
                color: AppColors.Shadow.card,
                radius: elevation.shadowRadius,
                x: 0,
                y: elevation.shadowYOffset
            )
            .shadow(
                color: glow ? AppColors.Shadow.ambientGlow : .clear,
                radius: glow ? 16 : 0,
                x: 0,
                y: glow ? 8 : 0
            )
    }
}

struct RMProgressBar: View {
    let value: CGFloat
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppColors.Surface.cardElevated)

                Capsule()
                    .fill(AppColors.primary)
                    .frame(width: max(height, proxy.size.width * max(0.04, min(1.0, value))))
                    .shadow(color: AppColors.Shadow.ambientGlow, radius: 8, x: 0, y: 2)
            }
        }
        .frame(height: height)
    }
}

struct RMChip: View {
    let title: String
    var count: String? = nil
    var selected: Bool = false
    var style: RMChipStyle = .regular

    var body: some View {
        HStack(spacing: style.interItemSpacing) {
            Text(title)
                .font(style.titleFont)

            if let count {
                Text(count)
                    .font(style.countFont)
                    .padding(.horizontal, style == .compact ? 6 : 7)
                    .frame(height: style.badgeHeight)
                    .background(selected ? Color.white.opacity(0.12) : AppColors.Surface.cardPrimary)
                    .clipShape(Capsule())
            }
        }
        .foregroundStyle(selected ? AppColors.Text.primary : AppColors.Text.secondary)
        .padding(.horizontal, style.horizontalPadding)
        .frame(height: style.height)
        .background(selected ? AppColors.Surface.accentTintStrong : AppColors.Surface.cardElevated)
        .overlay(
            Capsule()
                .stroke(selected ? AppColors.Border.active : AppColors.Border.subtle, lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

struct RMIconCircleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppColors.Text.primary)
            .frame(width: 40, height: 40)
            .background(AppColors.Surface.cardElevated)
            .overlay(
                Circle()
                    .stroke(AppColors.Border.subtle, lineWidth: 1)
            )
            .clipShape(Circle())
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct RMIconBadge: View {
    enum ShapeStyle {
        case roundedRect
        case circle
    }

    let systemName: String?
    let assetName: String?
    var emoji: String? = nil
    var size: CGFloat = 44
    var shape: ShapeStyle = .roundedRect
    var accent: Bool = false
    var imageInset: CGFloat = 8

    var body: some View {
        ZStack {
            backgroundShape

            if let assetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size - imageInset * 2, height: size - imageInset * 2)
                    .clipShape(RoundedRectangle(cornerRadius: max(8, size * 0.22), style: .continuous))
            } else if let systemName {
                Image(systemName: systemName)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(accent ? AppColors.primary : AppColors.Text.secondary)
            } else if let emoji {
                Text(emoji)
                    .font(.system(size: size * 0.42))
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var backgroundShape: some View {
        switch shape {
        case .roundedRect:
            RoundedRectangle(cornerRadius: max(12, size * 0.28), style: .continuous)
                .fill(accent ? AppColors.Surface.accentTint : AppColors.Surface.cardElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: max(12, size * 0.28), style: .continuous)
                        .stroke(accent ? AppColors.Border.active : AppColors.Border.subtle, lineWidth: 1)
                )
                .shadow(color: AppColors.Shadow.card, radius: size * 0.16, x: 0, y: size * 0.10)
        case .circle:
            Circle()
                .fill(accent ? AppColors.Surface.accentTint : AppColors.Surface.cardElevated)
                .overlay(
                    Circle()
                        .stroke(accent ? AppColors.Border.active : AppColors.Border.subtle, lineWidth: 1)
                )
                .shadow(color: AppColors.Shadow.card, radius: size * 0.16, x: 0, y: size * 0.10)
        }
    }
}

struct RMOverlayBadge: View {
    let title: String
    var systemName: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemName {
                Image(systemName: systemName)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(title)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(AppColors.Text.primary)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(AppColors.Surface.cardOverlay.opacity(0.92))
        .overlay(
            Capsule()
                .stroke(AppColors.Border.subtle, lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}
