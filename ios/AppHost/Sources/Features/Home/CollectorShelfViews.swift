import SwiftUI
#if os(iOS)
import UIKit
#endif

struct CollectorShelfSectionView<Content: View>: View {
    let title: String
    let subtitle: String?
    let entries: [ROMLibraryEntry]
    @ViewBuilder let content: (ROMLibraryEntry) -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.Text.tertiary)
                        .padding(.horizontal, 10)
                        .frame(height: 28)
                        .background(AppColors.Surface.cardElevated)
                        .overlay(Capsule().stroke(AppColors.Border.subtle, lineWidth: 1))
                        .clipShape(Capsule())
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .bottom, spacing: 18) {
                    ForEach(entries) { entry in
                        content(entry)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 6)
                .padding(.bottom, 2)
            }

            shelfRail
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 20)
        .background(AppColors.Surface.cardPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(AppColors.Border.subtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var shelfRail: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.Surface.cardElevated,
                            AppColors.Surface.cardPrimary
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 10)

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 1)
        }
        .shadow(color: Color.black.opacity(0.14), radius: 10, x: 0, y: 5)
    }
}

struct CollectorShelfBoxButton<Artwork: View>: View {
    let title: String
    let systemTag: String
    let metadata: String
    let progress: CGFloat?
    let showsMetadataByDefault: Bool
    let onTap: () -> Void
    @ViewBuilder let artwork: Artwork

    init(
        title: String,
        systemTag: String,
        metadata: String,
        progress: CGFloat? = nil,
        showsMetadataByDefault: Bool = false,
        onTap: @escaping () -> Void,
        @ViewBuilder artwork: () -> Artwork
    ) {
        self.title = title
        self.systemTag = systemTag
        self.metadata = metadata
        self.progress = progress
        self.showsMetadataByDefault = showsMetadataByDefault
        self.onTap = onTap
        self.artwork = artwork()
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                ZStack(alignment: .bottomLeading) {
                    artwork
                        .frame(width: 132, height: 176)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )

                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(showsMetadataByDefault ? 0.72 : 0.58)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(2)

                        HStack(spacing: 6) {
                            Text(systemTag)
                            Text(metadata)
                        }
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.84))

                        if let progress {
                            GeometryReader { proxy in
                                Capsule()
                                    .fill(Color.white.opacity(0.22))
                                    .overlay(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.92))
                                            .frame(width: max(10, proxy.size.width * max(0.05, min(1.0, progress))))
                                    }
                            }
                            .frame(height: 4)
                        }
                    }
                    .padding(12)
                }
                .frame(width: 132, height: 176)
            }
            .frame(width: 132, height: 196, alignment: .bottom)
        }
        .buttonStyle(CollectorShelfPressStyle())
        .accessibilityLabel("\(title), \(systemTag)")
        .accessibilityHint("Opens the game")
    }
}

private struct CollectorShelfPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion ? 1.0 : (configuration.isPressed ? 0.97 : 1.0))
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : (configuration.isPressed ? -3 : -1)),
                axis: (x: 0, y: 1, z: 0),
                anchor: .bottom,
                perspective: 0.8
            )
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.28 : 0.14),
                radius: configuration.isPressed ? 14 : 8,
                x: 0,
                y: configuration.isPressed ? 8 : 5
            )
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(Color.black.opacity(configuration.isPressed ? 0.16 : 0.10))
                    .frame(width: 92, height: 12)
                    .blur(radius: configuration.isPressed ? 10 : 6)
                    .offset(y: 14)
            }
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct CollectorShelfFilterRail: View {
    let selectedFilter: LibrarySystemFilter
    let counts: [LibrarySystemFilter: Int]
    let onSelect: (LibrarySystemFilter) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LibrarySystemFilter.allCases) { filter in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            onSelect(filter)
                        }
                    } label: {
                        RMChip(
                            title: filterLabel(filter),
                            count: "\(counts[filter, default: 0])",
                            selected: selectedFilter == filter,
                            style: .compact
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func filterLabel(_ filter: LibrarySystemFilter) -> String {
        switch filter {
        case .all: return "All Shelves"
        case .gb: return "Game Boy"
        case .gbc: return "Game Boy Color"
        case .gba: return "GBA"
        case .nds: return "NDS"
        }
    }
}
