import SwiftUI
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct GameDetailView: View {
    let game: Game
    @Environment(\.dismiss) private var dismiss
    @State private var showGamePlay = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                titleSection
                statsSection
                playButton
                infoSection
            }
            .padding()
        }
        .background(backgroundColor)
    }
    
    private var backgroundColor: Color {
        #if canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(.systemBackground)
        #endif
    }
    
    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            if let coverImage = game.coverImage, !coverImage.isEmpty {
                #if canImport(AppKit)
                if let nsImage = NSImage(data: coverImage) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 250)
                        .clipped()
                } else {
                    headerPlaceholder
                }
                #elseif canImport(UIKit)
                if let uiImage = UIImage(data: coverImage) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 250)
                        .clipped()
                } else {
                    headerPlaceholder
                }
                #else
                headerPlaceholder
                #endif
            } else {
                headerPlaceholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var headerPlaceholder: some View {
        Rectangle()
            .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(height: 250)
    }
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(game.title ?? "Unknown Title")
                    .font(.title2)
                    .fontWeight(.bold)
                if let console = game.consoleIdentity {
                    Text(console.systemCode)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(console.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
            }

            Text(game.consoleIdentity?.displayName ?? game.platform)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            StatBox(icon: "clock", title: "Play Time", value: "\(game.totalPlayTime)h")
            StatBox(icon: "internaldrive", title: "Size", value: formatFileSize(game.fileSize))
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private var playButton: some View {
        Button(action: { showGamePlay = true }) {
            HStack {
                Image(systemName: "play.fill")
                Text("Play Now")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .sheet(isPresented: $showGamePlay) {
            GamePlayView(game: game, onExit: {
                showGamePlay = false
            })
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game Info")
                .font(.headline)
            
            GameInfoRow(label: "Platform", value: game.platform)
            GameInfoRow(label: "Console", value: game.consoleIdentity?.displayName ?? game.platform)
            GameInfoRow(label: "Genre", value: game.genre ?? "Unknown")
        }
    }
}

struct StatBox: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.purple)
            
            Text(value)
                .font(.headline)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(statBoxBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var statBoxBackground: Color {
        #if canImport(AppKit)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(.secondarySystemBackground)
        #endif
    }
}

struct GameInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    GameDetailView(game: Game(
        title: "Pokemon Emerald",
        platform: "Game Boy Advance",
        coverImage: nil,
        rating: 4.5,
        lastPlayedDate: Date(),
        totalPlayTime: 25,
        isFavorite: false,
        releaseYear: 2004,
        genre: "RPG",
        fileSize: 8388608
    ))
}
