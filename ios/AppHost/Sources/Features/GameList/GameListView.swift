import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct GameListView: View {
    let platform: EmulatorPlatform
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = GameListViewModel()
    @State private var searchText = ""
    @State private var selectedGame: Game?
    @State private var showingGameDetail = false
    
    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                headerSection

                ScrollView {
                    VStack(spacing: 16) {
                        platformBanner
                        gamesSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .sheet(isPresented: $showingGameDetail) {
            if let game = selectedGame {
                GameDetailView(game: game)
            }
        }
        .onAppear {
            viewModel.loadGames(for: platform)
        }
    }
    
    private var backgroundLayer: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.18), AppColors.accent.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 120)
                .frame(width: 360, height: 360)
                .offset(x: 140, y: -210)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.12), AppColors.primary.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 140)
                .frame(width: 420, height: 420)
                .offset(x: -170, y: 320)
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
                    Text(platform.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text("\(viewModel.filteredGames(searchText: searchText).count) games available")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.textMuted)
                }

                Spacer()

                Text(platformEmoji)
                    .font(.system(size: 28))
            }

            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textMuted)

                    TextField("Search games...", text: $searchText)
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

                Button(action: {}) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 38, height: 38)
                        .background(AppColors.surfaceLight.opacity(0.45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 19)
                                .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 19))
                }
            }
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
    
    private var platformBanner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(platform.gradient.opacity(0.16))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                        Text("Quick Stats")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Spacer()
                    Text(platform.shortName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                }

                HStack(spacing: 16) {
                    platformIcon

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(platform.displayName) Games")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                        Text("Browse and launch your \(platform.shortName) library")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textMuted)
                            .lineLimit(2)
                    }
                }

                HStack(spacing: 10) {
                    StatBadge(value: "\(viewModel.totalGames)", label: "Games")
                    StatBadge(value: "\(viewModel.playedGames)", label: "Played")
                    StatBadge(value: "\(viewModel.favoriteGames)", label: "Favorites")
                }
            }
            .padding(16)
        }
    }
    
    private var platformIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(platform.gradient)
                .frame(width: 56, height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            
            Image(systemName: platform.iconName)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("All Games")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Button("Sort by: Recent") { }
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.primary)
            }

            let games = viewModel.filteredGames(searchText: searchText)

            if games.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                    Text(searchText.isEmpty ? "No games available" : "No matching games")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    if !searchText.isEmpty {
                        Text("Try a different search term")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textMuted)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .background(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(games) { game in
                        GameCardRow(game: game)
                            .onTapGesture {
                                selectedGame = game
                                showingGameDetail = true
                            }
                    }
                }
            }
        }
    }

    private var platformEmoji: String {
        switch platform {
        case .gameBoy: return "🎮"
        case .gameBoyColor: return "🎨"
        case .gameBoyAdvance: return "⚡"
        case .nintendoDS: return "📱"
        case .playStation1: return "💿"
        case .nintendo3DS: return "🔺"
        case .psp: return "🎯"
        }
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppColors.background.opacity(0.35))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.surfaceLight.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct GameCardRow: View {
    let game: Game
    
    var body: some View {
        HStack(spacing: 12) {
            gameCover

            VStack(alignment: .leading, spacing: 6) {
                Text(game.title ?? "Unknown")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < Int(game.rating.rounded(.down)) ? "star.fill" : "star")
                            .font(.system(size: 10))
                            .foregroundColor(index < Int(game.rating.rounded(.down)) ? .yellow : AppColors.textMuted.opacity(0.4))
                    }
                }

                HStack(spacing: 8) {
                    if game.totalPlayTime > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                            Text(formatPlayTime(game.totalPlayTime))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(AppColors.textMuted)
                    }

                    if let lastPlayed = game.lastPlayedDate {
                        Text(formatDate(lastPlayed))
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textMuted)
                    }
                }
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primary.opacity(0.20), AppColors.accent.opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    .offset(x: 1)
            }
        }
        .padding(12)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var gameCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surfaceLight, AppColors.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
            
            gameCoverImage
        }
    }
    
    @ViewBuilder
    private var gameCoverImage: some View {
        #if canImport(AppKit)
        if let coverData = game.coverImage, let nsImage = NSImage(data: coverData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            placeholderGlyph
        }
        #elseif canImport(UIKit)
        if let coverData = game.coverImage, let uiImage = UIImage(data: coverData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            placeholderGlyph
        }
        #else
        placeholderGlyph
        #endif
    }

    private var placeholderGlyph: some View {
        Image(systemName: "gamecontroller.fill")
            .font(.system(size: 22))
            .foregroundColor(AppColors.textMuted)
    }
    
    private func formatPlayTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

class GameListViewModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var isLoading = false
    
    var totalGames: Int { games.count }
    var playedGames: Int { games.filter { $0.totalPlayTime > 0 }.count }
    var favoriteGames: Int { games.filter { $0.isFavorite }.count }
    
    func loadGames(for platform: EmulatorPlatform) {
        isLoading = true
        
        games = [
            Game(title: "Pokemon Emerald", platform: platform.displayName, rating: 4.5, totalPlayTime: 3600, isFavorite: true, releaseYear: 2004, genre: "RPG", fileSize: 8388608),
            Game(title: "Mario Kart", platform: platform.displayName, rating: 4.8, totalPlayTime: 7200, isFavorite: false, releaseYear: 2003, genre: "Racing", fileSize: 4194304),
            Game(title: "Zelda OOT", platform: platform.displayName, rating: 5.0, totalPlayTime: 14400, isFavorite: true, releaseYear: 1998, genre: "Adventure", fileSize: 16777216)
        ].filter { $0.platform == platform.displayName }
        
        isLoading = false
    }
    
    func filteredGames(searchText: String) -> [Game] {
        if searchText.isEmpty {
            return games
        }
        return games.filter { ($0.title ?? "").localizedCaseInsensitiveContains(searchText) }
    }
}

#Preview {
    GameListView(platform: .gameBoyAdvance)
}
