import SwiftUI
import CoreData

struct LibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = LibraryViewModel()
    @State private var selectedFilter: LibraryFilter = .all
    @State private var searchText = ""
    @State private var selectedRom: ROMLibraryEntry?

    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading library...")
            } else {
                mainContent
            }
        }
        .searchable(text: $searchText, prompt: "Search ROMs...")
        .onAppear {
            viewModel.loadEntries(in: viewContext)
        }
        .sheet(item: $selectedRom) { rom in
            RomDetailView(rom: rom) {
                viewModel.loadEntries(in: viewContext)
            }
        }
    }

    private var mainContent: some View {
        VStack {
            filterSection
            romGrid
        }
    }

    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(LibraryFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                        viewModel.applyFilter(filter)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    private var romGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 120), spacing: 16)
            ], spacing: 16) {
                ForEach(filteredRomEntries) { entry in
                    RomCard(entry: entry) {
                        selectedRom = entry
                    }
                }
            }
            .padding()
        }
    }

    private var filteredRomEntries: [ROMLibraryEntry] {
        var entries = viewModel.filteredEntries

        if !searchText.isEmpty {
            entries = entries.filter { entry in
                (entry.title ?? "").localizedCaseInsensitiveContains(searchText)
            }
        }

        return entries
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct RomCard: View {
    let entry: ROMLibraryEntry
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(3/4, contentMode: .fit)
                    .cornerRadius(12)

                if let coverData = entry.coverImageData,
                   let coverImage = Image(data: coverData) {
                    coverImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .cornerRadius(12)
                } else {
                    PlatformPlaceholder(platform: entry.system)
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .cornerRadius(12)
                }


            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title ?? "Unknown")
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    Text(entry.system ?? "Unknown")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let lastPlayed = entry.lastPlayedAt {
                        Text(lastPlayed, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                HStack {
                    Spacer()

                    if entry.playtimeTotal > 0 {
                        Text("\(formatPlaytime(entry.playtimeTotal))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .onTapGesture(perform: onTap)
    }

    private func formatPlaytime(_ seconds: Int64) -> String {
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        return "\(hours)h"
    }
}

struct PlatformPlaceholder: View {
    let platform: String?

    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)

            Text(platformIcon)
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var platformIcon: String {
        switch platform?.lowercased() {
        case "nes": return "🕹️"
        case "gba": return "🎮"
        case "gb": return "📱"
        case "genesis": return "🎯"
        case "nds": return "📊"
        case "ps1": return "📀"
        case "ps2": return "💿"
        case "3ds": return "🪧"
        default: return "🎲"
        }
    }
}

struct RomDetailView: View {
    let rom: ROMLibraryEntry
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isLaunching = false
    @State private var adShouldShow = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                artworkSection
                titleSection
                metadataSection
                statsSection
                actionsSection
            }
            .padding()
        }
        .navigationTitle(rom.title ?? "ROM Details")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                    onDismiss()
                }
            }
        }
        .sheet(isPresented: $isLaunching) {
            Group {
                let _ = print("[DEBUG] Sheet presented, calling toGame()")
                if let game = rom.toGame() {
                    let _ = print("[DEBUG] Sheet: toGame() returned game: \(game.title)")
                    GamePlayView(game: game) {
                        isLaunching = false
                    }
                } else {
                    let _ = print("[DEBUG] Sheet: toGame() returned nil!")
                    VStack {
                        Text("Failed to load game")
                        Text("Check console for details")
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            isLaunching = false
                        }
                    }
                }
            }
        }
        .alert(isPresented: $adShouldShow) {
            Alert(
                title: Text("Sponsor Message"),
                message: Text("Watch this ad to continue playing"),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var artworkSection: some View {
        ZStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(3/4, contentMode: .fit)
                .cornerRadius(16)

            if let coverData = rom.coverImageData,
               let coverImage = Image(data: coverData) {
                coverImage
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(16)
            } else {
                PlatformPlaceholder(platform: rom.system)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(16)
            }
        }
        .frame(height: 300)
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rom.title ?? "Unknown Title")
                .font(.title2)
                .fontWeight(.bold)

            HStack(spacing: 12) {
                Text(rom.system ?? "Unknown Platform")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            DetailRow(label: "System", value: rom.system ?? "Unknown")
            DetailRow(label: "Checksum", value: String(rom.checksum?.prefix(16) ?? "Unknown"))
            DetailRow(label: "Last Played", value: rom.lastPlayedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics")
                .font(.headline)

            DetailRow(label: "Play Time", value: formatPlaytime(rom.playtimeTotal))
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button(action: launchGame) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Play")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(isLaunching)
        }
    }

    private func launchGame() {
        isLaunching = true
        updateLastPlayed()
    }

    private func updateLastPlayed() {
        rom.lastPlayedAt = Date()

        do {
            try viewContext.save()
        } catch {
            print("Failed to update last played: \(error)")
        }
    }

    private func formatPlaytime(_ seconds: Int64) -> String {
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        return "\(hours)h"
    }

    private let camelCaseToWords = try! NSRegularExpression(pattern: "([a-z])([A-Z])")
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

extension ROMLibraryEntry {
    @MainActor
    var romPath: String? {
        guard let checksum = checksum,
              let fileName = fileName else { return nil }
        
        let fileExtension = (fileName as NSString).pathExtension
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDir.appendingPathComponent("ROMs/\(checksum).\(fileExtension)").path
    }
    
    @MainActor
    func toGame() -> Game? {
        print("[DEBUG] toGame() called for: \(title ?? "nil")")
        
        guard let title = title,
              let checksum = checksum else {
            print("[DEBUG] toGame() failed: title: \(title as Optional), checksum: \(checksum as Optional)")
            return nil
        }
        
        // Use the object's id
        let gameUUID = id
        print("[DEBUG] toGame() using id: \(gameUUID)")
        print("[DEBUG] toGame() passed first guard, checksum: \(checksum), system: \(system ?? "nil")")
        
        let normalizedSystem = (system ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Extract extension from imported filename and normalize case
        let primaryExtension: String
        if let fileName = self.fileName {
            let ext = (fileName as NSString).pathExtension.lowercased()
            primaryExtension = ext.isEmpty ? "rom" : ext
        } else {
            // Fallback to system-based extension if fileName is not available
            switch normalizedSystem {
            case "nes": primaryExtension = "nes"
            case "gb", "gameboy", "game boy": primaryExtension = "gb"
            case "gbc", "gameboycolor", "game boy color", "cgb": primaryExtension = "gbc"
            case "gba", "game boy advance", "gameboyadvance": primaryExtension = "gba"
            case "genesis": primaryExtension = "md"
            case "nds", "nintendo ds": primaryExtension = "nds"
            case "ps1", "playstation 1": primaryExtension = "bin"
            default: primaryExtension = "rom"
            }
        }

        var extensionCandidates: [String] = [primaryExtension]
        if normalizedSystem == "gbc" || normalizedSystem == "cgb" || normalizedSystem.contains("game boy color") {
            extensionCandidates.append(contentsOf: ["gbc", "gb"])
        } else if normalizedSystem == "gb" || normalizedSystem.contains("game boy") {
            extensionCandidates.append(contentsOf: ["gb", "gbc"])
        }
        extensionCandidates = Array(Set(extensionCandidates.map { $0.lowercased() }))
        
        let platformString: String
        switch normalizedSystem {
        case "nes": platformString = "NES"
        case "gb", "gameboy", "game boy": platformString = "Game Boy"
        case "gbc", "gameboycolor", "game boy color", "cgb": platformString = "Game Boy Color"
        case "gba", "gameboyadvance", "game boy advance": platformString = "Game Boy Advance"
        case "genesis": platformString = "Genesis"
        case "nds", "nintendo ds": platformString = "Nintendo DS"
        case "ps1", "playstation 1": platformString = "PlayStation 1"
        default: platformString = system ?? "Unknown"
        }

        var romLocation: ROMStorageLocation?
        for ext in extensionCandidates {
            if let found = ROMStorage.shared.getROMLocation(checksum: checksum, fileExtension: ext) {
                romLocation = found
                break
            }
        }

        if romLocation == nil {
            // Last-resort fallback: scan by checksum prefix regardless of extension/casing.
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let romDir = documentsDir.appendingPathComponent("ROMs")
            if let files = try? FileManager.default.contentsOfDirectory(at: romDir, includingPropertiesForKeys: nil),
               let match = files.first(where: { $0.lastPathComponent.lowercased().hasPrefix("\(checksum.lowercased()).") }) {
                let attrs = try? FileManager.default.attributesOfItem(atPath: match.path)
                let size = attrs?[.size] as? Int64 ?? 0
                romLocation = ROMStorageLocation(url: match, fileSize: size, checksum: checksum)
            }
        }

        guard let romLocation else {
            print("[DEBUG] toGame() failed: ROM location not found for checksum: \(checksum), extensions: \(extensionCandidates)")
            return nil
        }
        print("[DEBUG] toGame() ROM location: \(romLocation.url.path)")
        print("[DEBUG] toGame() creating Game with platform: \(platformString)")
        
        let game = Game(
            id: gameUUID,
            title: title,
            platform: platformString,
            coverImage: nil,
            rating: 0.0,
            lastPlayedDate: lastPlayedAt,
            totalPlayTime: Int(playtimeTotal),
            isFavorite: isFavorite,
            releaseYear: 2000,
            genre: nil,
            fileSize: Int64(fileSize),
            gameDescription: nil,
            romPath: romLocation.url.path
        )
        print("[DEBUG] toGame() returning game: \(game.title)")
        return game
    }
}

@objc(ROMLibraryEntry)
class ROMLibraryEntry: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var title: String?
    @NSManaged var fileName: String?
    @NSManaged var fileSize: Int64
    @NSManaged var coverImageData: Data?
    @NSManaged var system: String?
    @NSManaged var lastPlayedAt: Date?
    @NSManaged var playtimeTotal: Int64
    @NSManaged var isFavorite: Bool
    @NSManaged var dateAdded: Date?
    @NSManaged var checksum: String?
}

final class LibraryViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var filteredEntries: [ROMLibraryEntry] = []

    private var allEntries: [ROMLibraryEntry] = []
    private var fetchedResultsController: NSFetchedResultsController<ROMLibraryEntry>?
    private weak var viewContext: NSManagedObjectContext?

    func loadEntries(in context: NSManagedObjectContext) {
        isLoading = true
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
            allEntries = fetchedResultsController?.fetchedObjects ?? []
            filteredEntries = allEntries
        } catch {
            print("Failed to fetch ROMs: \(error)")
            filteredEntries = []
        }

        isLoading = false
    }

    func refreshEntries() {
        guard let fetchedObjects = fetchedResultsController?.fetchedObjects else { return }
        allEntries = fetchedObjects
    }

    func applyFilter(_ filter: LibraryFilter) {
        switch filter {
        case .all:
            filteredEntries = allEntries
        case .recent:
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            filteredEntries = allEntries.filter { entry in
                guard let lastPlayed = entry.lastPlayedAt else { return false }
                return lastPlayed >= oneWeekAgo
            }
        case .favorites:
            filteredEntries = allEntries.filter { entry in
                entry.isFavorite
            }
        case .stable, .experimental:
            // Tier filtering not implemented - show all games
            filteredEntries = allEntries
        }
    }
}

enum LibraryFilter: CaseIterable {
    case all
    case recent
    case favorites
    case stable
    case experimental

    var displayName: String {
        switch self {
        case .all: return "All"
        case .recent: return "Recent"
        case .favorites: return "Favorites"
        case .stable: return "Stable"
        case .experimental: return "Experimental"
        }
    }
}

extension ROMLibraryEntry: Identifiable {
    static func fetchRequest() -> NSFetchRequest<ROMLibraryEntry> {
        return NSFetchRequest<ROMLibraryEntry>(entityName: "ROMLibraryEntry")
    }
}

extension Image {
    init?(data: Data) {
        #if canImport(UIKit)
        if let uiImage = UIImage(data: data) {
            self.init(uiImage: uiImage)
        } else {
            return nil
        }
        #elseif canImport(AppKit)
        if let nsImage = NSImage(data: data) {
            self.init(nsImage: nsImage)
        } else {
            return nil
        }
        #else
        return nil
        #endif
    }
}
