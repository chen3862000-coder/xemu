import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif

struct GameLibraryView: View {
    private enum LibrarySortOption: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case alphabetical = "A-Z"
        case mostPlayed = "Most Played"

        var id: String { rawValue }
    }

    private enum LibrarySystemFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case gbc = "GB/GBC"
        case gba = "GBA"
        case nds = "NDS"

        var id: String { rawValue }
    }

    private enum LibraryViewMode: String {
        case grid
        case list
    }

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @State private var games: [ROMLibraryEntry] = []
    @State private var selectedGame: Game?
    @State private var searchText = ""
    @State private var selectedSort: LibrarySortOption = .recent
    @State private var selectedSystemFilter: LibrarySystemFilter = .all
    @State private var viewMode: LibraryViewMode = .grid
    @State private var showConsoleFilters: Bool = true
    @State private var activeAlert: LibraryAlertState?
    
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
                            if viewMode == .grid {
                                gamesGrid
                            } else {
                                gamesList
                            }
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
        .alert(item: $activeAlert) { state in
            switch state.kind {
            case .launchError(let message):
                return Alert(
                    title: Text("Unable to Open Game"),
                    message: Text(message),
                    dismissButton: .cancel(Text("OK"))
                )
            case .confirmDelete(let candidate):
                return Alert(
                    title: Text(candidate.mode.displayName),
                    message: Text(candidate.mode.firstConfirmation),
                    primaryButton: .default(Text("Continue")) {
                        activeAlert = LibraryAlertState(kind: .confirmFinalDelete(candidate))
                    },
                    secondaryButton: .cancel()
                )
            case .confirmFinalDelete(let candidate):
                return Alert(
                    title: Text("Final Confirmation"),
                    message: Text(candidate.mode.secondConfirmation),
                    primaryButton: .destructive(Text("Delete")) {
                        performDeletion(candidate)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .onAppear {
            loadGames()
        }
        .onReceive(NotificationCenter.default.publisher(for: .romLibraryDidChange)) { _ in
            loadGames()
        }
    }

    private var filteredGames: [ROMLibraryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filteredBySystem = games.filter { entry in
            guard selectedSystemFilter != .all else { return true }
            let system = (entry.system ?? "").uppercased()
            switch selectedSystemFilter {
            case .all:
                return true
            case .gbc:
                return system == "GB" || system == "GBC" || system == "GB/GBC"
            case .gba:
                return system == "GBA"
            case .nds:
                return system == "NDS"
            }
        }

        let filteredBySearch = filteredBySystem.filter { entry in
            guard !query.isEmpty else { return true }
            return (entry.title ?? "").localizedCaseInsensitiveContains(query) ||
            (entry.system ?? "").localizedCaseInsensitiveContains(query)
        }

        switch selectedSort {
        case .recent:
            return filteredBySearch.sorted(by: { lhs, rhs in
                let leftDate = lhs.lastPlayedAt ?? lhs.dateAdded ?? Date.distantPast
                let rightDate = rhs.lastPlayedAt ?? rhs.dateAdded ?? Date.distantPast
                return leftDate > rightDate
            })
        case .alphabetical:
            return filteredBySearch.sorted(by: {
                ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending
            })
        case .mostPlayed:
            return filteredBySearch.sorted(by: { $0.playtimeTotal > $1.playtimeTotal })
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.18), AppColors.accent.opacity(0.14)],
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
                        colors: [AppColors.accent.opacity(0.12), AppColors.primary.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 140)
                .frame(width: 420, height: 420)
                .offset(x: -180, y: 320)
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
                    Text("All Games")
                        .font(SubpageUI.Font.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .allowsTightening(true)
                        .foregroundColor(AppColors.textPrimary)
                    Text("\(games.count) games total")
                        .font(SubpageUI.Font.subtitle)
                        .foregroundColor(AppColors.primary)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundColor(AppColors.textMuted)

                TextField("Search games...", text: $searchText)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
#endif
                    .foregroundColor(AppColors.textPrimary)
            }
            .subpageSearchField(cornerRadius: 19, height: 38)

            HStack(spacing: 8) {
                Menu {
                    ForEach(LibrarySortOption.allCases) { option in
                        Button {
                            selectedSort = option
                        } label: {
                            HStack {
                                Text(option.rawValue)
                                if selectedSort == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.system(size: 12, weight: .semibold))
                        Text(selectedSort.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .background(AppColors.surfaceLight.opacity(0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(AppColors.surfaceLight.opacity(0.85), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 0) {
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            viewMode = .grid
                        }
                    } label: {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(viewMode == .grid ? .white : AppColors.textMuted)
                            .frame(width: 34, height: 30)
                            .background(viewMode == .grid ? AppColors.primary : Color.clear)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            viewMode = .list
                        }
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(viewMode == .list ? .white : AppColors.textMuted)
                            .frame(width: 34, height: 30)
                            .background(viewMode == .list ? AppColors.primary : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
                .background(AppColors.surfaceLight.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(AppColors.surfaceLight.opacity(0.85), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 15))

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        showConsoleFilters.toggle()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(showConsoleFilters ? .white : AppColors.textPrimary)
                        .frame(width: 34, height: 30)
                        .background(showConsoleFilters ? AppColors.primary : AppColors.surfaceLight.opacity(0.55))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(AppColors.surfaceLight.opacity(0.85), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
            }

            if showConsoleFilters {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(LibrarySystemFilter.allCases) { filter in
                            Button {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    selectedSystemFilter = filter
                                }
                            } label: {
                                Text(filter.rawValue)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(selectedSystemFilter == filter ? .white : AppColors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .frame(height: 30)
                                    .background(selectedSystemFilter == filter ? AppColors.primary : AppColors.surfaceLight.opacity(0.5))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 1)
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

    private var gamesGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ],
            spacing: 12
        ) {
            ForEach(filteredGames) { entry in
                AllGamesCard(entry: entry) {
                    launchGame(entry)
                }
                .buttonStyle(PressScaleButtonStyle())
                .contextMenu {
                    Button {
                        launchGame(entry)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    Button {
                        showComingSoon("Rename game")
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {
                        showComingSoon("Set cover")
                    } label: {
                        Label("Set Cover", systemImage: "photo")
                    }
                    Button {
                        showComingSoon("Game details")
                    } label: {
                        Label("Details", systemImage: "info.circle")
                    }
                    Button(role: .destructive) {
                        activeAlert = LibraryAlertState(kind: .confirmDelete(LibraryDeleteCandidate(entry: entry, mode: .removeROMOnly)))
                    } label: {
                        Label("Remove ROM Only", systemImage: "eject")
                    }
                    Button(role: .destructive) {
                        activeAlert = LibraryAlertState(kind: .confirmDelete(LibraryDeleteCandidate(entry: entry, mode: .removeAll)))
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var gamesList: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredGames) { entry in
                AllGamesListRow(entry: entry) {
                    launchGame(entry)
                }
                .buttonStyle(PressScaleButtonStyle())
                .contextMenu {
                    Button {
                        launchGame(entry)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    Button {
                        showComingSoon("Rename game")
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button {
                        showComingSoon("Set cover")
                    } label: {
                        Label("Set Cover", systemImage: "photo")
                    }
                    Button {
                        showComingSoon("Game details")
                    } label: {
                        Label("Details", systemImage: "info.circle")
                    }
                    Button(role: .destructive) {
                        activeAlert = LibraryAlertState(kind: .confirmDelete(LibraryDeleteCandidate(entry: entry, mode: .removeROMOnly)))
                    } label: {
                        Label("Remove ROM Only", systemImage: "eject")
                    }
                    Button(role: .destructive) {
                        activeAlert = LibraryAlertState(kind: .confirmDelete(LibraryDeleteCandidate(entry: entry, mode: .removeAll)))
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: searchText.isEmpty ? "gamecontroller" : "magnifyingglass")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(AppColors.textMuted)

            Text(searchText.isEmpty ? "No Games Yet" : "No Matching Games")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Text(searchText.isEmpty ? "Import some ROMs to get started!" : "Try a different search term.")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .subpageCard(cornerRadius: SubpageUI.Radius.sectionCard)
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
        let compatibility = ROMCompatibilityService.shared.compatibility(for: entry)
        if let issue = compatibility.issue {
            activeAlert = LibraryAlertState(kind: .launchError(issue.message))
            return
        }
        guard let game = entry.toGame() else {
            activeAlert = LibraryAlertState(kind: .launchError("ROM file could not be found. Try re-importing the game."))
            return
        }
        selectedGame = game
    }

    private func performDeletion(_ candidate: LibraryDeleteCandidate) {
        do {
            try GameDeletionService.shared.delete(entry: candidate.entry, mode: candidate.mode, in: viewContext)
            loadGames()
        } catch {
            activeAlert = LibraryAlertState(kind: .launchError("Could not delete game: \(error.localizedDescription)"))
        }
    }

    private func showComingSoon(_ feature: String) {
        activeAlert = LibraryAlertState(kind: .launchError("\(feature) is coming soon."))
    }
}

struct AllGamesCard: View {
    let entry: ROMLibraryEntry
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    coverArt
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    LinearGradient(
                        colors: [Color.clear, Color.black.opacity(0.33)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 140)

                    HStack {
                        if entry.playtimeTotal > 0 {
                            Text(playtimeBadge)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                                .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppColors.background.opacity(0.72))
                            .clipShape(Capsule())
                        }

                        Spacer()

                        Text((entry.system ?? "UNK").uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.95))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(AppColors.primary.opacity(0.68))
                            .clipShape(Capsule())
                    }
                    .padding(8)

                    if let issue = ROMCompatibilityService.shared.compatibility(for: entry).issue {
                        VStack {
                            HStack {
                                Image(systemName: issue.iconName)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.orange)
                                    .padding(6)
                                    .background(Color.black.opacity(0.55))
                                    .clipShape(Circle())
                                    .padding(8)
                                Spacer()
                            }
                            Spacer()
                        }
                    }

                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.title ?? "Unknown Game")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)

                    if ROMCompatibilityService.shared.compatibility(for: entry).issue != nil {
                        Label("Unsupported Mapper", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.orange)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                        Text(lastPlayedLabel)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(AppColors.primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.surface)
            }
            .frame(height: 220)
        }
        .buttonStyle(PlainButtonStyle())
        .subpageCard(cornerRadius: SubpageUI.Radius.gameCard)
    }

    @ViewBuilder
    private var coverArt: some View {
        ZStack {
            #if os(iOS)
            if let imageData = entry.coverImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let screenshot = SaveStateStorage.shared.latestScreenshot(for: entry.checksum ?? ""),
                      let uiImage = UIImage(data: screenshot) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                placeholderGlyph
            }
            #else
            placeholderGlyph
            #endif
        }
    }

    private var placeholderGlyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(consoleGradient)

            Text(String((entry.title ?? "?").prefix(1)).uppercased())
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundColor(.white.opacity(0.22))
                .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: consoleGlyph)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.25))
                        .padding(10)
                }
            }
        }
    }

    private var lastPlayedLabel: String {
        guard let lastPlayed = entry.lastPlayedAt else { return "Never played" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastPlayed, relativeTo: Date())
    }

    private var playtimeBadge: String {
        let minutes = Int(entry.playtimeTotal) / 60
        if minutes < 60 {
            return "\(max(minutes, 1))m"
        }
        let hours = minutes / 60
        return "\(hours)h"
    }

    private var consoleGradient: LinearGradient {
        switch (entry.system ?? "").uppercased() {
        case "GB", "GBC", "GB/GBC":
            return LinearGradient(colors: [Color(red: 0.66, green: 0.91, blue: 0.84), Color(red: 0.70, green: 0.82, blue: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "GBA":
            return LinearGradient(colors: [Color(red: 0.74, green: 0.67, blue: 0.98), Color(red: 0.55, green: 0.46, blue: 0.90)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "NDS":
            return LinearGradient(colors: [Color(red: 0.64, green: 0.75, blue: 0.98), Color(red: 0.57, green: 0.67, blue: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [AppColors.surfaceLight, AppColors.surface], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var consoleGlyph: String {
        switch (entry.system ?? "").uppercased() {
        case "GB", "GBC", "GB/GBC": return "rectangle.3.group.bubble"
        case "GBA": return "bolt.fill"
        case "NDS": return "rectangle.split.2x1"
        default: return "gamecontroller.fill"
        }
    }
}

private struct AllGamesListRow: View {
    let entry: ROMLibraryEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                rowThumbnail
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title ?? "Unknown Game")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text((entry.system ?? "UNK").uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppColors.primary.opacity(0.88))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(AppColors.primary.opacity(0.12))
                            .clipShape(Capsule())

                        Text(lastPlayedLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                    }
                }

                Spacer()

                if let issue = ROMCompatibilityService.shared.compatibility(for: entry).issue {
                    Image(systemName: issue.iconName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.orange)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textMuted)
            }
            .padding(10)
            .frame(minHeight: 92)
            .subpageCard(cornerRadius: 12, shadowOpacity: 0.04)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var rowThumbnail: some View {
        ZStack {
            #if os(iOS)
            if let imageData = entry.coverImageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let screenshotData = SaveStateStorage.shared.latestScreenshot(for: entry.checksum ?? ""),
                      let uiImage = UIImage(data: screenshotData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.surfaceLight, AppColors.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppColors.textMuted)
                    )
            }
            #else
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surfaceLight, AppColors.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.textMuted)
                )
            #endif
        }
        .clipped()
    }

    private var lastPlayedLabel: String {
        guard let lastPlayed = entry.lastPlayedAt else { return "Never played" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastPlayed, relativeTo: Date())
    }
}

private struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct LibraryDeleteCandidate: Identifiable {
    let id = UUID()
    let entry: ROMLibraryEntry
    let mode: GameDeletionMode
}

private struct LibraryAlertState: Identifiable {
    enum Kind {
        case launchError(String)
        case confirmDelete(LibraryDeleteCandidate)
        case confirmFinalDelete(LibraryDeleteCandidate)
    }

    let id = UUID()
    let kind: Kind
}

#if DEBUG
struct GameLibraryView_Previews: PreviewProvider {
    static var previews: some View {
        GameLibraryView()
    }
}
#endif
