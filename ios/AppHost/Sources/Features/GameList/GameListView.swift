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
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                
                platformBanner
                
                gamesList
            }
        }
        .searchable(text: $searchText, prompt: "Search \(platform.displayName) games...")
        .sheet(isPresented: $showingGameDetail) {
            if let game = selectedGame {
                GameDetailView(game: game)
            }
        }
        .onAppear {
            viewModel.loadGames(for: platform)
        }
    }
    
    private var backgroundColor: Color {
        #if canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    private var headerSection: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(buttonBackgroundColor)
                    .clipShape(Circle())
            }
            
            Text(platform.displayName)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: {}) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(buttonBackgroundColor)
                    .clipShape(Circle())
            }
            
            Button(action: {}) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(buttonBackgroundColor)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(headerBackgroundColor)
    }
    
    private var buttonBackgroundColor: Color {
        #if canImport(AppKit)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }
    
    private var headerBackgroundColor: Color {
        #if canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    private var platformBanner: some View {
        HStack(spacing: 16) {
            platformIcon
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(platform.displayName) Games")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    StatBadge(value: "\(viewModel.totalGames)", label: "Games")
                    StatBadge(value: "\(viewModel.playedGames)", label: "Played")
                    StatBadge(value: "\(viewModel.favoriteGames)", label: "Favorites")
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(platform.gradient.opacity(0.15))
    }
    
    private var platformIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(platform.gradient)
                .frame(width: 64, height: 64)
            
            Image(systemName: platform.iconName)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
        }
    }
    
    private var gamesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredGames(searchText: searchText)) { game in
                    GameCardRow(game: game)
                        .onTapGesture {
                            selectedGame = game
                            showingGameDetail = true
                        }
                }
            }
            .padding(16)
        }
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct GameCardRow: View {
    let game: Game
    
    var body: some View {
        HStack(spacing: 12) {
            gameCover
            
            VStack(alignment: .leading, spacing: 6) {
                Text(game.title ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)
                
                if game.rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(game.rating) ? "star.fill" : "star")
                                .font(.system(size: 10))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                if game.totalPlayTime > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 12))
                        Text(formatPlayTime(game.totalPlayTime))
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if let lastPlayed = game.lastPlayedDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDate(lastPlayed))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(12)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var cardBackgroundColor: Color {
        #if canImport(AppKit)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }
    
    private var gameCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
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
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: "gamecontroller")
                .font(.system(size: 24))
                .foregroundColor(.gray)
        }
        #elseif canImport(UIKit)
        if let coverData = game.coverImage, let uiImage = UIImage(data: coverData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: "gamecontroller")
                .font(.system(size: 24))
                .foregroundColor(.gray)
        }
        #else
        Image(systemName: "gamecontroller")
            .font(.system(size: 24))
            .foregroundColor(.gray)
        #endif
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
