import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#endif

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = HomeViewModel()
    @State private var showingSettings = false
    @State private var showingImport = false
    @State private var showingGameLibrary = false
    @State private var showingRecentlyPlayed = false
    @State private var selectedPlatform: EmulatorPlatform?
    @State private var selectedGame: Game?
    
    var body: some View {
        ZStack {
            backgroundGradients

            VStack(spacing: 0) {
                headerSection

                ScrollView {
                    VStack(spacing: 24) {
                        statsGrid
                        recentGamesSection
                        emulatorsSection
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingImport) {
            RomImportView()
        }
        .sheet(isPresented: $showingGameLibrary) {
            GameLibraryView()
        }
        .sheet(isPresented: $showingRecentlyPlayed) {
            RecentlyPlayedView()
        }
        .sheet(item: $selectedPlatform) { platform in
            GameListView(platform: platform)
        }
        #if os(iOS)
        .fullScreenCover(item: $selectedGame) { game in
            GamePlayView(game: game, onExit: {
                selectedGame = nil
            })
        }
        #endif
        .onAppear {
            refreshHome()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshHome() }
        }
        .onChange(of: showingImport) { _, shown in if !shown { refreshHome() } }
        .onChange(of: showingGameLibrary) { _, shown in if !shown { refreshHome() } }
        .onChange(of: showingRecentlyPlayed) { _, shown in if !shown { refreshHome() } }
        .onChange(of: showingSettings) { _, shown in if !shown { refreshHome() } }
        .onChange(of: selectedPlatform) { _, platform in if platform == nil { refreshHome() } }
    }
    
    private var backgroundGradients: some View {
        ZStack {
            AppColors.background
            .ignoresSafeArea()

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.20), AppColors.accent.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 120)
                .frame(width: 380, height: 380)
                .offset(x: 140, y: -220)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.16), AppColors.primary.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 140)
                .frame(width: 420, height: 420)
                .offset(x: -160, y: 320)
        }
    }
    
    private var headerSection: some View {
        Header(
            onAddTapped: {
                showingImport = true
            },
            onSettingsTapped: {
                showingSettings = true
            }
        )
    }
    
    private var statsGrid: some View {
        HStack(spacing: 12) {
            Button(action: {
                showingGameLibrary = true
            }) {
                StatCard(
                    title: "Total Games",
                    value: "\(viewModel.totalGames)",
                    icon: "gamecontroller.fill",
                    gradient: [AppColors.primary, AppColors.accent]
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            StatCard(
                title: "Hours Played",
                value: viewModel.totalHours,
                icon: "clock.fill",
                gradient: [AppColors.info, AppColors.primary]
            )
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
                    selectedGame = nil
                    showingRecentlyPlayed = true
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundColor(AppColors.primary)
            }
            .contentShape(Rectangle())
            .zIndex(2)
            
            if viewModel.recentGames.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                    Text("No recent games")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(Array(viewModel.recentGames.prefix(2))) { game in
                        RecentGameCard(game: game) {
                            if let playable = game.playableGame {
                                selectedGame = playable
                            } else {
                                showingRecentlyPlayed = true
                            }
                        }
                    }
                }
                .zIndex(0)
            }
        }
    }
    
    private var emulatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                    Text("All Emulators")
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                Text("\(viewModel.emulators.count) systems")
                    .font(.caption)
                    .foregroundColor(AppColors.textMuted)
            }
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
                    selectedPlatform = platform(for: emulator.shortName)
                }
            }
        }
    }

    private func platform(for shortName: String) -> EmulatorPlatform? {
        if shortName == "GB/GBC" {
            return .gameBoy
        }
        return EmulatorPlatform.allCases.first { $0.shortName == shortName }
    }

    private func refreshHome() {
        viewModel.loadData(in: viewContext)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.primary)
                Spacer()
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.16))
                        .frame(width: 42, height: 42)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
            }

            Text(value)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(AppColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 92, alignment: .topLeading)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.surfaceLight.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: AppColors.primary.opacity(0.06), radius: 10, x: 0, y: 4)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct RecentGameCard: View {
    let game: RecentGame
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    recentCardArtwork

                    LinearGradient(
                        colors: [Color.clear, AppColors.surface.opacity(0.92)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text(game.console)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.primary.opacity(0.92))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .padding(8)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(game.title)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(2)
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .semibold))
                        Text(playedDateText)
                            .font(.system(size: 11, weight: .medium))
                        Text("•")
                            .font(.system(size: 11, weight: .medium))
                            .opacity(0.7)
                        Text(totalHoursText)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(AppColors.primary)
                }
                .padding(12)
            }
            .frame(maxWidth: .infinity)
            .background(AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.surfaceLight.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.05), radius: 10, x: 0, y: 4)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PlainButtonStyle())
    }

    @ViewBuilder
    private var recentCardArtwork: some View {
        #if os(iOS)
        if let screenshotData = game.screenshotData, let uiImage = UIImage(data: screenshotData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let imageUrl = game.image, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.textMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            fallbackArtwork
        }
        #else
        if let imageUrl = game.image, let url = URL(string: imageUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Image(systemName: "gamecontroller")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.textMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            fallbackArtwork
        }
        #endif
    }

    private var fallbackArtwork: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.surfaceLight, AppColors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 28))
                .foregroundColor(AppColors.textMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var playedDateText: String {
        guard let date = game.lastPlayed else { return "Never" }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var totalHoursText: String {
        let hours = max(0, game.totalPlaySeconds / 3600)
        return "\(hours)h"
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

    private var consoleAssetName: String? {
        switch shortName {
        case "GB/GBC": return "ConsoleGBGBC"
        case "GBA": return "ConsoleGBA"
        case "NDS": return "ConsoleNDS"
        default: return nil
        }
    }
    
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

                        if let consoleAssetName {
                            Image(consoleAssetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Text(icon)
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
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
    @StateObject private var coordinator: RomImportCoordinator
    @State private var isHovered = false
    
    init() {
        let persistence = PersistenceController.shared
        let romsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ROMs", isDirectory: true)
        _coordinator = StateObject(wrappedValue: RomImportCoordinator(persistence: persistence, romsDirectory: romsDir))
    }
    
    // presentDocumentPicker() moved to private func with full implementation below
    
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
                    #if os(iOS)
                    presentDocumentPicker()
                    #endif
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
        #if os(iOS)
        .sheet(isPresented: $coordinator.isImporting) {
            ImportingProgressView(progress: coordinator.importProgress)
        }
        #endif
    }
    
    #if os(iOS)
    private func presentDocumentPicker() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        
        coordinator.presentFilePicker(on: topVC) { urls in
            guard !urls.isEmpty else { return }
            Task {
                for url in urls {
                    do {
                        _ = try await self.coordinator.importROM(from: url)
                        await MainActor.run {
                            print("ROM imported successfully: \(url.lastPathComponent)")
                        }
                    } catch {
                        print("Import error for \(url.lastPathComponent): \(error.localizedDescription)")
                    }
                }
                await MainActor.run {
                    self.coordinator.isImporting = false
                    self.dismiss()
                }
            }
        }
    }
    #endif
}

#if os(iOS)
struct ImportingProgressView: View {
    let progress: Double
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .purple))
            
            Text("Importing ROM... \(Int(progress * 100))%")
                .font(.headline)
        }
        .padding(40)
    }
}
#endif

@MainActor
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
            loadEmulators(from: entries)
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
                console: entry.system?.uppercased() ?? "Unknown",
                lastPlayed: entry.lastPlayedAt,
                progress: 0,
                image: nil,
                screenshotData: SaveStateStorage.shared.latestScreenshot(for: entry.checksum ?? ""),
                totalPlaySeconds: Int(entry.playtimeTotal),
                playableGame: entry.toGame(),
                gameId: entry.id
            )
        }
    }
    
    private func loadEmulators(from entries: [ROMLibraryEntry]) {
        let countsBySystem = Dictionary(grouping: entries) {
            ($0.system ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }.mapValues(\.count)

        emulators = [
            EmulatorInfo(name: "Game Boy + Color", shortName: "GB/GBC", gamesCount: countsBySystem["gb", default: 0] + countsBySystem["gbc", default: 0], gradient: [Color.purple, Color.blue], icon: "🎮"),
            EmulatorInfo(name: "Game Boy Advance", shortName: "GBA", gamesCount: countsBySystem["gba", default: 0], gradient: [Color.purple, Color.indigo], icon: "⚡"),
            EmulatorInfo(name: "Nintendo DS", shortName: "NDS", gamesCount: countsBySystem["nds", default: 0], gradient: [Color.cyan, Color.blue], icon: "📱"),
        ].filter { $0.gamesCount > 0 || ["GB/GBC", "GBA", "NDS"].contains($0.shortName) }
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
    let screenshotData: Data?
    let totalPlaySeconds: Int
    let playableGame: Game?
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
