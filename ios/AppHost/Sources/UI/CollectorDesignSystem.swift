import SwiftUI

enum RMSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let screenMargin: CGFloat = 20
    static let sectionGap: CGFloat = 24
}

enum RMRadius {
    static let chip: CGFloat = 12
    static let button: CGFloat = 16
    static let card: CGFloat = 20
}

enum RMTypeScale {
    static let largeTitle = Font.system(size: 28, weight: .bold)
    static let sectionTitle = Font.system(size: 20, weight: .bold)
    static let cardTitle = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 15, weight: .medium)
    static let meta = Font.system(size: 13, weight: .medium)
}

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
        case .gbc: return Color(hex: "14B8A6")
        case .gba: return Color(hex: "7C5CFF")
        case .nds: return Color(hex: "4A86FF")
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
                colors: [AppColors.Surface.cardElevated, AppColors.Surface.cardSecondary],
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
        case .standard: return 286
        case .compact: return 216
        }
    }

    static func artworkHeight(for variant: CollectorCardVariant) -> CGFloat {
        switch variant {
        case .featured: return 156
        case .standard: return 156
        case .compact: return 124
        }
    }

    static func titleFont(for variant: CollectorCardVariant) -> Font {
        switch variant {
        case .featured: return .system(size: 24, weight: .semibold)
        case .standard: return RMTypeScale.cardTitle
        case .compact: return .system(size: 16, weight: .semibold)
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
        case .standard: return 52
        case .compact: return 48
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
                    RMOverlayBadge(title: platformTag, backgroundColor: platformStyle.badgeColor)
                        .padding(RMSpacing.sm)
                }

                if let launchIssueIconName {
                    VStack {
                        HStack {
                            Image(systemName: launchIssueIconName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.orange)
                                .padding(6)
                                .background(AppColors.Surface.cardOverlay)
                                .clipShape(Circle())
                                .padding(8)
                            Spacer()
                        }
                        Spacer()
                    }
                }
            }

            VStack(alignment: .leading, spacing: RMSpacing.sm) {
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
                        Text("·")
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

                GeometryReader { _ in
                    RMProgressBar(value: progress ?? 0, height: 4)
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, RMSpacing.lg)
            .padding(.top, RMSpacing.lg)
            .padding(.bottom, RMSpacing.lg)
            .background(AppColors.Surface.cardPrimary)
        }
        .frame(maxWidth: .infinity)
        .background(AppColors.Surface.cardPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: RMRadius.card, style: .continuous)
                .stroke(AppColors.Border.subtle, lineWidth: 1)
        )
        .shadow(color: AppColors.Shadow.card, radius: 14, x: 0, y: 8)
        .shadow(color: AppColors.Shadow.ambientGlow.opacity(0.45), radius: 16, x: 0, y: 8)
        .frame(height: CollectorCardMetrics.cardHeight(for: variant))
        .clipShape(RoundedRectangle(cornerRadius: RMRadius.card, style: .continuous))
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
