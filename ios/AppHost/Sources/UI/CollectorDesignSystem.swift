import SwiftUI

enum CollectorCardVariant {
    case featured
    case standard
    case compact
}

enum CollectorPlatformStyle {
    case gb
    case gbc
    case gba
    case nds
    case neutral

    init(systemTag: String?) {
        switch ConsoleIdentity.resolve(systemRaw: systemTag) {
        case .gb: self = .gb
        case .gbc: self = .gbc
        case .gba: self = .gba
        case .nds: self = .nds
        default: self = .neutral
        }
    }

    var badgeColor: Color {
        switch self {
        case .gb: return Color(hex: "7D9A52")
        case .gbc: return Color(red: 0.52, green: 0.31, blue: 0.88)
        case .gba: return Color(red: 0.49, green: 0.28, blue: 0.88)
        case .nds: return Color(red: 0.37, green: 0.52, blue: 0.88)
        case .neutral: return AppColors.primary
        }
    }

    var shelfGradient: LinearGradient {
        switch self {
        case .gb:
            return LinearGradient(
                colors: [Color(red: 0.84, green: 0.90, blue: 0.78), Color(red: 0.76, green: 0.84, blue: 0.66)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gbc:
            return LinearGradient(
                colors: [Color(red: 0.86, green: 0.82, blue: 0.96), Color(red: 0.75, green: 0.67, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gba:
            return LinearGradient(
                colors: [Color(red: 0.80, green: 0.74, blue: 0.93), Color(red: 0.88, green: 0.84, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .nds:
            return LinearGradient(
                colors: [Color(red: 0.80, green: 0.87, blue: 0.93), Color(red: 0.88, green: 0.92, blue: 0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .neutral:
            return LinearGradient(
                colors: [AppColors.surfaceLight.opacity(0.66), AppColors.surface.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

private enum CollectorCardMetrics {
    static func cardHeight(for variant: CollectorCardVariant) -> CGFloat {
        switch variant {
        case .featured: return 280
        case .standard: return 292
        case .compact: return 224
        }
    }

    static func artworkHeight(for variant: CollectorCardVariant) -> CGFloat {
        switch variant {
        case .featured: return 156
        case .standard: return 160
        case .compact: return 132
        }
    }

    static func titleFont(for variant: CollectorCardVariant) -> Font {
        switch variant {
        case .featured: return .system(size: 24, weight: .semibold)
        case .standard: return .system(size: 20, weight: .semibold)
        case .compact: return .system(size: 18, weight: .semibold)
        }
    }

    static func metadataFont(for variant: CollectorCardVariant) -> Font {
        switch variant {
        case .featured: return .system(size: 16, weight: .medium)
        case .standard: return .system(size: 15, weight: .medium)
        case .compact: return .system(size: 14, weight: .medium)
        }
    }

    static func titleBlockHeight(for variant: CollectorCardVariant) -> CGFloat {
        switch variant {
        case .featured: return 74
        case .standard: return 62
        case .compact: return 52
        }
    }

    static func metadataRowHeight(for variant: CollectorCardVariant) -> CGFloat {
        switch variant {
        case .featured: return 24
        case .standard: return 22
        case .compact: return 20
        }
    }
}

struct CollectorGameCard<Artwork: View>: View {
    let variant: CollectorCardVariant
    let title: String
    let metadataPrimary: String
    let metadataSecondary: String?
    let platformTag: String?
    let launchIssueIconName: String?
    let progress: CGFloat?
    @ViewBuilder let artwork: Artwork

    init(
        variant: CollectorCardVariant,
        title: String,
        metadataPrimary: String,
        metadataSecondary: String? = nil,
        platformTag: String? = nil,
        launchIssueIconName: String? = nil,
        progress: CGFloat? = nil,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.variant = variant
        self.title = title
        self.metadataPrimary = metadataPrimary
        self.metadataSecondary = metadataSecondary
        self.platformTag = platformTag
        self.launchIssueIconName = launchIssueIconName
        self.progress = progress
        self.artwork = artwork()
    }

    private var platformStyle: CollectorPlatformStyle {
        CollectorPlatformStyle(systemTag: platformTag)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                artwork
                    .frame(maxWidth: .infinity, minHeight: CollectorCardMetrics.artworkHeight(for: variant), maxHeight: CollectorCardMetrics.artworkHeight(for: variant))
                    .clipped()

                if let platformTag, !platformTag.isEmpty {
                    Text(platformTag)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background(platformStyle.badgeColor.opacity(0.86))
                        .clipShape(Capsule())
                        .padding(8)
                }

                if let launchIssueIconName {
                    VStack {
                        HStack {
                            Image(systemName: launchIssueIconName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(6)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Circle())
                                .padding(8)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                Text(title)
                    .font(CollectorCardMetrics.titleFont(for: variant))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .foregroundColor(AppColors.textPrimary)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: CollectorCardMetrics.titleBlockHeight(for: variant),
                        maxHeight: CollectorCardMetrics.titleBlockHeight(for: variant),
                        alignment: .topLeading
                    )

                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                    Text(metadataPrimary)
                        .font(CollectorCardMetrics.metadataFont(for: variant))
                    if let metadataSecondary, !metadataSecondary.isEmpty {
                        Text("•")
                            .font(.system(size: 13, weight: .medium))
                            .opacity(0.55)
                        Text(metadataSecondary)
                            .font(CollectorCardMetrics.metadataFont(for: variant))
                            .foregroundColor(AppColors.textMuted)
                    }
                }
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .frame(
                    maxWidth: .infinity,
                    minHeight: CollectorCardMetrics.metadataRowHeight(for: variant),
                    maxHeight: CollectorCardMetrics.metadataRowHeight(for: variant),
                    alignment: .leading
                )

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColors.surfaceLight.opacity(0.58))
                        if let progress {
                            Capsule()
                                .fill(AppColors.primary.opacity(0.62))
                                .frame(width: max(8, geo.size.width * max(0.05, min(1.0, progress))))
                        }
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.96))
        }
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.88))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.70), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.07), radius: 10, x: 0, y: 4)
        .frame(height: CollectorCardMetrics.cardHeight(for: variant))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct CollectorConsoleTile: View {
    let title: String
    let subtitle: String
    let systemTag: String
    let icon: String
    let consoleAssetName: String?
    let onTap: () -> Void

    private var style: CollectorPlatformStyle {
        CollectorPlatformStyle(systemTag: systemTag)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(style.shelfGradient)
                        .frame(width: 250, height: 156)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.65), lineWidth: 1)
                        )

                    if let consoleAssetName {
                        Image(consoleAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 88)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text(icon)
                            .font(.system(size: 30))
                    }
                }

                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textMuted)
            }
            .frame(width: 250, alignment: .leading)
        }
        .buttonStyle(CollectorCardPressStyle())
    }
}
