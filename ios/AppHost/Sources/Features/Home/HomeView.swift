import SwiftUI
import CoreData

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = HomeViewModel()
    @State private var showingSettings = false
    @State private var showingImport = false
    @State private var searchText = ""
    
    var body: some View {
        ZStack {
            backgroundGradients
            
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    statsGrid
                    importSection
                    recentGamesSection
                    emulatorsSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .searchable(text: $searchText, prompt: "Search games...")
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingImport) {
            RomImportView()
        }
        .onAppear {
            viewModel.loadData(in: viewContext)
        }
    }
    
    private var backgroundGradients: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Circle()
                .fill(LinearGradient(
                    colors: [Color.pink.opacity(0.3), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .blur(radius: 100)
                .frame(width: 400, height: 400)
                .offset(x: -100, y: -200)
            
            Circle()
                .fill(LinearGradient(
                    colors: [Color.cyan.opacity(0.3), Color.blue.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .blur(radius: 80)
                .frame(width: 300, height: 300)
                .offset(x: 150, y: 300)
        }
    }
    
    private var headerSection: some View {
        HStack {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(
                            colors: [Color.pink, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("XEmu")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Classic Gaming Hub")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: { showingSettings = true }) {
                Image(systemName: "gear")
                    .font(.system(size: 20))
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(Color.primary.opacity(0.1))
                    .clipShape(Circle())
            }
        }
        .padding(.top, 8)
    }
    
    private var statsGrid: some View {
        HStack(spacing: 12) {
            StatCard(
                title: "Total Games",
                value: "\(viewModel.totalGames)",
                icon: "gamecontroller.fill",
                gradient: [Color.pink, Color.purple]
            )
            
            StatCard(
                title: "Hours Played",
                value: viewModel.totalHours,
                icon: "clock.fill",
                gradient: [Color.cyan, Color.blue]
            )
        }
    }
    
    private var importSection: some View {
        ImportRomsButton {
            showingImport = true
        }
    }
    
    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.purple)
                    Text("Continue Playing")
                        .font(.headline)
                }
                
                Spacer()
                
                Button("View All") {
                    // Navigate to recent games
                }
                .font(.subheadline)
                .foregroundColor(.purple)
            }
            
            if viewModel.recentGames.isEmpty {
                Text("No recent games")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.recentGames) { game in
                            RecentGameCard(game: game) {
                                viewModel.playGame(game)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var emulatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Emulators")
                .font(.headline)
                .padding(.top, 8)
            
            ForEach(Array(viewModel.emulators.enumerated()), id: \.element.name) { index, emulator in
                EmulatorCard(
                    name: emulator.name,
                    shortName: emulator.shortName,
                    gamesCount: emulator.gamesCount,
                    gradient: emulator.gradient,
                    icon: emulator.icon,
                    index: index
                ) {
                    viewModel.selectEmulator(emulator)
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.05))
        .cornerRadius(16)
    }
}

struct RecentGameCard: View {
    let game: RecentGame
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 120, height: 160)
                    
                    if let imageUrl = game.image, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "gamecontroller")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        }
                        .frame(width: 120, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        Image(systemName: "gamecontroller")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(game.console)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        .padding(6)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    if let lastPlayed = game.lastPlayed {
                        Text(lastPlayed, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 120)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EmulatorCard: View {
    let name: String
    let shortName: String
    let gamesCount: Int
    let gradient: [Color]
    let icon: String
    let index: Int
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: gradient.map { $0.opacity(0.2) },
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
                    )

                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 48, height: 48)

                        Text(icon)
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)

                        HStack(spacing: 4) {
                            Text(shortName)
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textMuted)

                            Text("•")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textMuted)

                            Text("\(gamesCount) games")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.primary)
                        }
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 40, height: 40)
                            .shadow(color: AppColors.primary.opacity(0.5), radius: isHovered ? 12 : 8, x: 0, y: 4)

                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    }
                }
                .padding(16)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct ImportRomsButton: View {
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var iconOffset: CGFloat = 0
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                    .offset(y: 1)

                RoundedRectangle(cornerRadius: 16)
                    .fill(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                LinearGradient(
                                    colors: [AppColors.primary.opacity(0.5), AppColors.accent.opacity(0.5)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: 1
                            )
                    )

                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.accent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                            .shadow(color: AppColors.primary.opacity(0.5), radius: 8, x: 0, y: 4)

                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .offset(y: iconOffset)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import ROMs")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)

                        Text("Add your game files")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textMuted)
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(AppColors.primary.opacity(0.2))
                            .frame(width: 32, height: 32)

                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.primary)
                    }
                }
                .padding(16)
            }
            .frame(height: 80)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

struct RomImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.purple)
                
                Text("Import ROMs")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Select ROM files from your device to add them to your library.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                Button(action: {
                    isImporting = true
                }) {
                    Text("Select Files")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [Color.pink, Color.purple], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
            .navigationTitle("Import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

final class HomeViewModel: ObservableObject {
    @Published var totalGames: Int = 0
    @Published var totalHours: String = "0h"
    @Published var recentGames: [RecentGame] = []
    @Published var emulators: [EmulatorInfo] = []
    
    private var fetchedResultsController: NSFetchedResultsController<ROMLibraryEntry>?
    private weak var viewContext: NSManagedObjectContext?
    
    func loadData(in context: NSManagedObjectContext) {
        viewContext = context
        
        let fetchRequest: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \ROMLibraryEntry.lastPlayedAt, ascending: false)
        ]
        
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: context,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        
        do {
            try fetchedResultsController?.performFetch()
            let entries = fetchedResultsController?.fetchedObjects ?? []
            updateStats(from: entries)
            loadEmulators()
        } catch {
            print("Failed to fetch: \(error)")
        }
    }
    
    private func updateStats(from entries: [ROMLibraryEntry]) {
        totalGames = entries.count
        
        let totalSeconds = entries.reduce(0) { $0 + $1.playtimeTotal }
        let hours = totalSeconds / 3600
        totalHours = hours > 0 ? "\(hours)h" : "0h"
        
        let recentEntries = entries.filter { $0.lastPlayedAt != nil }.prefix(5)
        recentGames = recentEntries.map { entry in
            RecentGame(
                id: entry.objectID.uriRepresentation().absoluteString,
                title: entry.title ?? "Unknown",
                console: entry.platform ?? "Unknown",
                lastPlayed: entry.lastPlayedAt,
                progress: 0,
                image: entry.artworkUri,
                gameId: entry.entryId ?? UUID()
            )
        }
    }
    
    private func loadEmulators() {
        emulators = [
            EmulatorInfo(name: "Game Boy", shortName: "GB", gamesCount: 0, gradient: [Color.green, Color.mint], icon: "gameboy"),
            EmulatorInfo(name: "Game Boy Color", shortName: "GBC", gamesCount: 0, gradient: [Color.purple, Color.pink], icon: "gameboy"),
            EmulatorInfo(name: "Game Boy Advance", shortName: "GBA", gamesCount: 0, gradient: [Color.purple, Color.indigo], icon: "gamecontroller"),
            EmulatorInfo(name: "Nintendo DS", shortName: "NDS", gamesCount: 0, gradient: [Color.cyan, Color.blue], icon: "hand.raised"),
            EmulatorInfo(name: "PlayStation", shortName: "PS1", gamesCount: 0, gradient: [Color.gray, Color.blue], icon: "playstation"),
            EmulatorInfo(name: "Nintendo 3DS", shortName: "3DS", gamesCount: 0, gradient: [Color.red, Color.orange], icon: "hand.raised"),
            EmulatorInfo(name: "PSP", shortName: "PSP", gamesCount: 0, gradient: [Color.gray, Color.black], icon: "gamecontroller"),
        ]
    }
    
    func playGame(_ game: RecentGame) {
        // Handle play action
    }
    
    func selectEmulator(_ emulator: EmulatorInfo) {
        // Handle emulator selection
    }
}

struct RecentGame: Identifiable {
    let id: String
    let title: String
    let console: String
    let lastPlayed: Date?
    let progress: Int
    let image: String?
    let gameId: UUID
}

struct EmulatorInfo: Identifiable {
    let id = UUID()
    let name: String
    let shortName: String
    var gamesCount: Int
    let gradient: [Color]
    let icon: String
}
