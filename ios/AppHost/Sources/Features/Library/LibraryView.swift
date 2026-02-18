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

                if let artworkUri = entry.artworkUri,
                   let url = URL(string: artworkUri) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        PlatformPlaceholder(platform: entry.platform)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
                    .cornerRadius(12)
                } else {
                    PlatformPlaceholder(platform: entry.platform)
                        .frame(maxWidth: .infinity)
                        .frame(height: 150)
                        .cornerRadius(12)
                }

                if entry.tier == "experimental" {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("EXP")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title ?? "Unknown")
                    .font(.headline)
                    .lineLimit(2)

                HStack {
                    Text(entry.platform ?? "Unknown")
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
                    if entry.completionState == "completed" {
                        Label("Completed", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    } else if entry.completionState == "inProgress" {
                        Label("In Progress", systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }

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
            GameView(rom: rom)
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

            if let artworkUri = rom.artworkUri,
               let url = URL(string: artworkUri) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    PlatformPlaceholder(platform: rom.platform)
                }
                .frame(maxWidth: .infinity)
                .cornerRadius(16)
            } else {
                PlatformPlaceholder(platform: rom.platform)
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
                Text(rom.platform ?? "Unknown Platform")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)

                Text(rom.tier?.capitalized ?? "Unknown")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(tierColor.opacity(0.2))
                    .foregroundColor(tierColor)
                    .cornerRadius(8)
            }
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Details")
                .font(.headline)

            DetailRow(label: "Platform", value: rom.platform ?? "Unknown")
            DetailRow(label: "ROM Hash", value: String(rom.romHash?.prefix(16) ?? "Unknown"))
            DetailRow(label: "Last Played", value: rom.lastPlayedAt?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
            DetailRow(label: "Completion", value: formatCompletionState(rom.completionState))
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
            DetailRow(label: "Eligible for Leaderboard", value: rom.eligibleForLeaderboard ? "Yes" : "No")
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

            if rom.eligibleForLeaderboard {
                Button(action: launchLegitMode) {
                    HStack {
                        Image(systemName: "shield.fill")
                        Text("Legit Mode")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .disabled(isLaunching)
            }
        }
    }

    private func launchGame() {
        isLaunching = true
        updateLastPlayed()
    }

    private func launchLegitMode() {
        adShouldShow = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isLaunching = true
            updateLastPlayed()
        }
    }

    private func updateLastPlayed() {
        rom.lastPlayedAt = Date()

        do {
            try viewContext.save()
        } catch {
            print("Failed to update last played: \(error)")
        }
    }

    private var tierColor: Color {
        switch rom.tier?.lowercased() {
        case "stable": return .green
        case "experimental": return .orange
        default: return .gray
        }
    }

    private func formatCompletionState(_ state: String?) -> String {
        guard let state = state else { return "Not Started" }
        let result = state.replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
        return result.capitalized
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

struct GameView: View {
    let rom: ROMLibraryEntry

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack {
                Text("Emulating: \(rom.title ?? "Unknown")")
                    .foregroundColor(.white)
                    .padding()

                Text("Gameplay here...")
                    .foregroundColor(.gray)
            }
        }
    }
}

@objc(ROMLibraryEntry)
class ROMLibraryEntry: NSManagedObject {
    @NSManaged var entryId: UUID?
    @NSManaged var userId: UUID?
    @NSManaged var romHash: String?
    @NSManaged var perGameSettings: String?
    @NSManaged var title: String?
    @NSManaged var platform: String?
    @NSManaged var tier: String?
    @NSManaged var artworkUri: String?
    @NSManaged var lastPlayedAt: Date?
    @NSManaged var completionState: String?
    @NSManaged var eligibleForLeaderboard: Bool
    @NSManaged var playtimeTotal: Int64
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
                entry.completionState == "Completed"
            }
        case .stable:
            filteredEntries = allEntries.filter { entry in
                entry.tier?.lowercased() == "stable"
            }
        case .experimental:
            filteredEntries = allEntries.filter { entry in
                entry.tier?.lowercased() == "experimental"
            }
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
    var id: UUID {
        return value(forKey: "objectID") as! UUID
    }

    static func fetchRequest() -> NSFetchRequest<ROMLibraryEntry> {
        return NSFetchRequest<ROMLibraryEntry>(entityName: "ROMLibraryEntry")
    }
}
