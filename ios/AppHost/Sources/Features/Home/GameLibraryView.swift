import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif

struct GameLibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var games: [ROMLibraryEntry] = []
    @State private var selectedGame: Game?
    @State private var isPlaying = false
    
    var body: some View {
        NavigationView {
            List {
                if games.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Image(systemName: "gamecontroller")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("No Games Yet")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Import some ROMs to get started!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    }
                } else {
                    Section(header: Text("\(games.count) Games")) {
                        ForEach(games) { entry in
                            GameRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    launchGame(entry)
                                }
                        }
                    }
                }
            }
            #if os(iOS)
            .listStyle(InsetGroupedListStyle())
            #else
            .listStyle(DefaultListStyle())
            #endif
            .navigationTitle("Game Library")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .fullScreenCover(item: $selectedGame) { game in
                return GamePlayView(game: game, onExit: {
                    selectedGame = nil
                })
            }
            #endif
            .onAppear {
                loadGames()
            }
        }
    }
    
    private func loadGames() {
        let request = NSFetchRequest<ROMLibraryEntry>(entityName: "ROMLibraryEntry")
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            games = try viewContext.fetch(request)
        } catch {
            print("Failed to fetch games: \(error)")
            games = []
        }
    }
    
    private func launchGame(_ entry: ROMLibraryEntry) {
        guard let game = entry.toGame() else {
            return
        }
        selectedGame = game
        isPlaying = true
    }
}

struct GameRow: View {
    let entry: ROMLibraryEntry
    
    var body: some View {
        HStack(spacing: 16) {
            // Game cover image
            #if os(iOS)
            if let imageData = entry.coverImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "gamecontroller")
                            .font(.title2)
                            .foregroundColor(.gray)
                    )
            }
            #else
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .frame(width: 60, height: 60)
                .overlay(
                    Image(systemName: "gamecontroller")
                        .font(.title2)
                        .foregroundColor(.gray)
                )
            #endif
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title ?? "Unknown Game")
                    .font(.headline)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text(entry.system?.uppercased() ?? "Unknown")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .foregroundColor(.purple)
                        .cornerRadius(4)
                    
                    if let lastPlayed = entry.lastPlayedAt {
                        Text("Last played: \(lastPlayed, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if entry.playtimeTotal > 0 {
                    Text("\(entry.playtimeTotal) min played")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
struct GameLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        GameLibraryView()
    }
}
#endif
