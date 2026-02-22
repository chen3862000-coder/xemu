import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif

struct RecentlyPlayedView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var games: [ROMLibraryEntry] = []
    @State private var searchText = ""
    @State private var selectedGame: Game?

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                headerSection

                ScrollView {
                    VStack(spacing: 14) {
                        if filteredGames.isEmpty {
                            emptyState
                        } else {
                            gamesGrid
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        #if os(iOS)
        .fullScreenCover(item: $selectedGame) { game in
            GamePlayView(game: game, onExit: {
                selectedGame = nil
            })
        }
        #endif
        .onAppear(perform: loadGames)
    }

    private var filteredGames: [ROMLibraryEntry] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return games
        }
        return games.filter { entry in
            (entry.title ?? "").localizedCaseInsensitiveContains(searchText) ||
            (entry.system ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.16), AppColors.accent.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 120)
                .frame(width: 360, height: 360)
                .offset(x: 150, y: -230)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.10), AppColors.primary.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 140)
                .frame(width: 430, height: 430)
                .offset(x: -190, y: 320)
        }
    }

    private var headerSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.surfaceLight.opacity(0.5))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Recently Played")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("\(games.count) games")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                Button(action: {}) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.surfaceLight.opacity(0.5))
                        .clipShape(Circle())
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textMuted)

                TextField("Search recently played...", text: $searchText)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
#endif
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(AppColors.surfaceLight.opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: 19)
                    .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 19))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.background.opacity(0.85))
        .overlay(
            Rectangle()
                .fill(AppColors.surfaceLight.opacity(0.5))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var gamesGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            ForEach(filteredGames) { entry in
                RecentlyPlayedCard(entry: entry) {
                    launchGame(entry)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(AppColors.textMuted)

            Text(searchText.isEmpty ? "No Recently Played Games" : "No Matching Games")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Text(searchText.isEmpty ? "Start playing games to see them here." : "Try a different search term.")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func loadGames() {
        let request = NSFetchRequest<ROMLibraryEntry>(entityName: "ROMLibraryEntry")
        request.sortDescriptors = [NSSortDescriptor(key: "lastPlayedAt", ascending: false)]
        request.predicate = NSPredicate(format: "lastPlayedAt != nil")

        do {
            games = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch recent games: \(error)")
            games = []
        }
    }

    private func launchGame(_ entry: ROMLibraryEntry) {
        guard let game = entry.toGame() else { return }
        selectedGame = game
    }
}

struct RecentlyPlayedCard: View {
    let entry: ROMLibraryEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    coverArt
                        .frame(height: 112)

                    LinearGradient(
                        colors: [Color.clear, AppColors.background.opacity(0.9)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 112)

                    HStack {
                        Text(playtimeBadge)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.background.opacity(0.8))
                            .clipShape(Capsule())

                        Spacer()

                        Text((entry.system ?? "UNK").uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppColors.primary.opacity(0.9))
                            .clipShape(Capsule())
                    }
                    .padding(8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title ?? "Unknown Game")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 9))
                        Text(lastPlayedLabel)
                            .font(.system(size: 10))
                    }
                    .foregroundColor(AppColors.textMuted)
                }
                .padding(10)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private var coverArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surfaceLight, AppColors.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
#if os(iOS)
            if let imageData = entry.coverImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.textMuted)
            }
#else
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 28))
                .foregroundColor(AppColors.textMuted)
#endif
        }
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var playtimeBadge: String {
        let minutes = Int(entry.playtimeTotal) / 60
        if minutes <= 0 { return "0m" }
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h"
    }

    private var lastPlayedLabel: String {
        guard let lastPlayed = entry.lastPlayedAt else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastPlayed, relativeTo: Date())
    }
}

#if DEBUG
struct RecentlyPlayedView_Previews: PreviewProvider {
    static var previews: some View {
        RecentlyPlayedView()
    }
}
#endif
