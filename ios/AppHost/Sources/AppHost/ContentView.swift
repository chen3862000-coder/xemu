import SwiftUI
import CoreData
import UniformTypeIdentifiers
import Foundation

struct RomItem: Identifiable {
    let id: UUID
    let title: String
    let platform: String
    let tier: String
    let artworkUri: URL?
    let playtimeTotal: Int
    let completionState: String
    let lastPlayedAt: Date?
    
    init(from entry: ROMLibraryEntry) {
        self.id = entry.entryId ?? UUID()
        self.title = entry.title
        self.platform = entry.platform
        self.tier = entry.tier
        self.artworkUri = entry.artworkUri
        self.playtimeTotal = Int(entry.playtimeTotal)
        self.completionState = entry.completionState
        self.lastPlayedAt = entry.lastPlayedAt
    }
}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var roms: [RomItem] = []
    @State private var selectedPlatform: Platform?
    @State private var isImporting = false
    @State private var importProgress: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let platforms: [Platform?] = [nil, .NES, .GB, .GBA, .GENESIS, .NDS, .PS1, .PS2, ._3DS]
    
    var filteredRoms: [RomItem] {
        if let selected = selectedPlatform {
            return roms.filter { $0.platform == selected.rawValue }
        }
        return roms
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                platformFilterBar
                
                if filteredRoms.isEmpty {
                    emptyStateView
                } else {
                    romGridView
                }
            }
            .navigationTitle("ROM Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { isImporting = true }) {
                        Label("Import ROM", systemImage: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.archive, .zip, .data],
                allowsMultipleSelection: true
            ) { result in
                handleImport(result)
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadRoms()
            }
        }
    }
    
    private var platformFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(platforms, id: \.self) { platform in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPlatform = platform
                        }
                    }) {
                        Text(platform?.rawValue.uppercased() ?? "All")
                            .font(.subheadline)
                            .fontWeight(selectedPlatform == platform ? .semibold : .regular)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedPlatform == platform ? Color.blue : Color.gray.opacity(0.15))
                            .foregroundStyle(selectedPlatform == platform ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.gray.opacity(0.05))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "gamecontroller")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            
            Text("No ROMs Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Import ROMs to start playing")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Button(action: { isImporting = true }) {
                Label("Import ROM", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            
            Spacer()
        }
        .padding()
    }
    
    private var romGridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 16) {
                ForEach(filteredRoms) { rom in
                    romCard(rom: rom)
                }
            }
            .padding(16)
        }
    }
    
    private func romCard(rom: RomItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 120)
                
                Image(systemName: platformIconName(for: rom.platform))
                    .font(.system(size: 40))
                    .foregroundStyle(platformColor(for: rom.platform))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(rom.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                HStack {
                    Text(rom.platform)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    tierBadge(tier: rom.tier)
                }
                
                if rom.playtimeTotal > 0 {
                    Text("\(rom.playtimeTotal / 3600)h played")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
    
    private func tierBadge(tier: String) -> some View {
        Text(tier)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tierColor(for: tier))
            .foregroundStyle(.white)
            .clipShape(Capsule())
    }
    
    private func platformIconName(for platform: String) -> String {
        switch platform {
        case "NES": return "tv"
        case "GB", "GBC": return "gameboy"
        case "GBA": return "gamecontroller"
        case "SNES": return "tv"
        case "GENESIS": return "gamecontroller.fill"
        case "NDS", "_3DS": return "hand.raised"
        case "PS1", "PS2": return "playstation"
        default: return "questionmark.circle"
        }
    }
    
    private func platformColor(for platform: String) -> Color {
        switch platform {
        case "NES": return .red
        case "GB", "GBC": return .green
        case "GBA": return .purple
        case "SNES": return .orange
        case "GENESIS": return .blue
        case "NDS", "_3DS": return .cyan
        case "PS1", "PS2": return .indigo
        default: return .gray
        }
    }
    
    private func tierColor(for tier: String) -> Color {
        switch tier {
        case "Stable": return .green
        case "Beta": return .orange
        case "Alpha": return .red
        default: return .gray
        }
    }
    
    private func loadRoms() {
        let request: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ROMLibraryEntry.lastPlayedAt, ascending: false)]
        
        do {
            let entries = try viewContext.fetch(request)
            roms = entries.map { RomItem(from: $0) }
        } catch {
            errorMessage = "Failed to load ROMs: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                importRom(from: url)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func importRom(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Cannot access file"
            showingError = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        importProgress = "Importing \(url.lastPathComponent)..."
        
        let romsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let coordinator = RomImportCoordinator(persistenceController: PersistenceController.shared, romsDirectory: romsDir)
        
        do {
            try coordinator.importROM(from: url)
            try viewContext.save()
            loadRoms()
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
            showingError = true
        }
    }
}
