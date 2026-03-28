import SwiftUI

struct InsightsSectionHeaderView: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 22, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InsightChipView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .allowsTightening(true)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(AppColors.primary.opacity(0.10))
            .clipShape(Capsule())
    }
}

struct PlayStyleBadgeView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 23, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.textPrimary)
    }
}

struct InsightsMetricCardView: View {
    let icon: String
    let title: String
    let primaryValue: String
    let secondaryLine1: String?
    let secondaryLine2: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.88))
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                        .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(primaryValue)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(primaryValue == "0" ? AppColors.textPrimary.opacity(0.94) : AppColors.textPrimary)
                .contentTransition(.numericText())

            VStack(alignment: .leading, spacing: 4) {
                if let secondaryLine1 {
                    Text(secondaryLine1)
                        .lineLimit(1)
                }
                if let secondaryLine2 {
                    Text(secondaryLine2)
                        .lineLimit(1)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 104, maxHeight: 104, alignment: .topLeading)
        .playInsightsCardStyle(padding: 16)
        .modifier(InsightsAppearModifier(delay: 0.02))
    }
}

struct InsightsNarrativeCardView: View {
    let title: String
    let bodyText: String
    let icon: String
    var emphasized = false
    var tinted = false

    var body: some View {
        Group {
            if emphasized {
                content(
                    titleColor: Color.white.opacity(0.88),
                    bodyColor: Color.white.opacity(0.92),
                    bodyLineSpacing: 3
                )
                .modifier(HeroNarrativeCardModifier())
                .modifier(InsightsAppearModifier(delay: 0.10, initialScale: 0.98))
            } else {
                content(
                    titleColor: AppColors.textPrimary,
                    bodyColor: AppColors.textPrimary,
                    bodyLineSpacing: 1
                )
                .playInsightsCardStyle(
                    padding: 16,
                    background: tinted ? AppColors.primary.opacity(0.045) : AppColors.surface,
                    border: tinted ? AppColors.textSecondary.opacity(0.08) : AppColors.Border.subtle
                )
                .modifier(InsightsAppearModifier(delay: 0.06))
            }
        }
        .frame(maxWidth: .infinity, minHeight: emphasized ? 148 : 136, alignment: .topLeading)
    }

    private func content(
        titleColor: Color,
        bodyColor: Color,
        bodyLineSpacing: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(titleColor.opacity(0.88))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(titleColor)
            }

            if tinted {
                let lines = bodyText.components(separatedBy: "\n")
                VStack(alignment: .leading, spacing: 4) {
                    Text(lines.first ?? bodyText)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(bodyColor)
                    if lines.count > 1 {
                        Text(lines.dropFirst().joined(separator: "\n"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.98))
                            .lineSpacing(1)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(bodyText)
                    .font(.system(size: emphasized ? 18 : 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(bodyColor)
                    .lineSpacing(bodyLineSpacing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CurrentRunCardView: View {
    let primary: String
    let secondary: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary.opacity(0.88))
                    Text(PlayInsightsL10n.string("playinsights.current_run.section_title", "Current Run"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
            }

            Text(primary)
                .font(.system(size: 21, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.92)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(secondary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                Circle()
                    .fill(AppColors.primary.opacity(0.72))
                    .frame(width: 6, height: 6)
                    .padding(.horizontal, 1)
                Text(PlayInsightsL10n.string("playinsights.status.active", "Active"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.primary.opacity(0.94))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .playInsightsCardStyle(
            padding: 15,
            shadowColor: AppColors.primary.opacity(0.12),
            shadowRadius: 18,
            shadowY: 10
        )
        .modifier(InsightsAppearModifier(delay: 0.16))
    }
}

struct SummaryStatCardView: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.primary.opacity(0.88))
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .playInsightsCardStyle()
    }
}

struct ActiveRunRowView: View {
    let entry: ROMLibraryEntry
    let item: ActiveRunItem

    var body: some View {
        HStack(spacing: 14) {
            PlayInsightsCoverView(entry: entry, size: CGSize(width: 54, height: 72))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.gameTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(item.primaryText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(2)
                Text(item.secondaryText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
            if let badge = item.badgeText, !badge.isEmpty {
                InsightChipView(text: badge)
            }
        }
        .playInsightsCardStyle()
    }
}

struct HardestGameRowView: View {
    let entry: ROMLibraryEntry
    let item: HardestGameItem

    var body: some View {
        HStack(spacing: 14) {
            PlayInsightsCoverView(entry: entry, size: CGSize(width: 54, height: 72))
            VStack(alignment: .leading, spacing: 5) {
                Text(item.gameTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(item.primaryMetricText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(item.badgeText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
        }
        .playInsightsCardStyle()
    }
}

struct SupportedGameInsightCardView: View {
    let entry: ROMLibraryEntry
    let item: SupportedGameCardItem

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            PlayInsightsCoverView(entry: entry, size: CGSize(width: 62, height: 82))
            VStack(alignment: .leading, spacing: 6) {
                Text(item.gameTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text(item.progressLine)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(item.performanceLine)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
                Text(item.insightLine)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .playInsightsCardStyle()
    }
}

struct InsightsEmptyStateView: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text(bodyText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .playInsightsCardStyle()
    }
}

private struct PlayInsightsCoverView: View {
    let entry: ROMLibraryEntry
    let size: CGSize

    var body: some View {
        Group {
            if let data = CoverArtService.shared.resolve(for: entry)?.data,
               let image = Image(data: data) {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        AppColors.gradients[SubpageUI.CollectorIdentity.normalizedSystemCode(entry.system)]
                        ?? AppColors.accentGradient
                    )
                    .overlay(
                        PlatformPlaceholder(platform: entry.system)
                            .padding(10)
                            .opacity(0.28)
                    )
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension View {
    func playInsightsCardStyle(
        padding: CGFloat = 18,
        background: Color? = nil,
        border: Color? = nil,
        shadowColor: Color? = nil,
        shadowRadius: CGFloat = 12,
        shadowY: CGFloat = 8
    ) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill((background ?? AppColors.surface).opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(border ?? AppColors.Border.subtle, lineWidth: 1)
            )
            .shadow(color: shadowColor ?? AppColors.Shadow.card, radius: shadowRadius, x: 0, y: shadowY)
    }
}

private struct NarrativeCardModifier: ViewModifier {
    let padding: CGFloat
    let background: Color
    let border: Color
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowY: CGFloat

    func body(content: Content) -> some View {
        content.playInsightsCardStyle(
            padding: padding,
            background: background,
            border: border,
            shadowColor: shadowColor,
            shadowRadius: shadowRadius,
            shadowY: shadowY
        )
    }
}

private struct HeroNarrativeCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.primary.opacity(0.74),
                                AppColors.accent.opacity(0.60)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.28), radius: 22, x: 0, y: 12)
    }
}

private struct InsightsAppearModifier: ViewModifier {
    let delay: Double
    var initialScale: CGFloat = 1
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 8)
            .scaleEffect(isVisible ? 1 : initialScale, anchor: .center)
            .animation(.spring(response: 0.42, dampingFraction: 0.88).delay(delay), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}
