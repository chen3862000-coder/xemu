import SwiftUI
import CoreData
import ImageIO
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

private func isGIFData(_ data: Data) -> Bool {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return false }
    let type = CGImageSourceGetType(source)
    return type == UTType.gif.identifier as CFString
}

private enum AllGamesTokens {
    private static var currentTheme: AppThemeMode {
        if let raw = UserDefaults.standard.string(forKey: "appThemeMode"),
           let mode = AppThemeMode(rawValue: raw) {
            return mode
        }
        return .light
    }

    static var isDark: Bool { currentTheme == .dark }

    static var appBackground: Color {
        isDark ? AppColors.Background.appPrimary : Color(hex: "F5F2FA")
    }

    static var surface: Color {
        isDark ? AppColors.Surface.cardPrimary : Color(hex: "FFFFFF")
    }

    static var surfaceAlt: Color {
        isDark ? AppColors.Surface.cardElevated : Color(hex: "FBFBFD")
    }

    static var textPrimary: Color {
        isDark ? Color(hex: "F6F6FA") : Color(hex: "23232B")
    }

    static var textSecondary: Color {
        isDark ? Color(hex: "B5B5C1") : Color(hex: "6A6A75")
    }

    static var textTertiary: Color {
        isDark ? AppColors.Text.tertiary : Color(hex: "9A9AA6")
    }

    static let accent = Color(hex: "9B6BFF")
    static let accentPressed = Color(hex: "7B2FEA")
    static let info = Color(hex: "6C9CFF")

    static var strokeSubtle: Color {
        isDark ? AppColors.Border.subtle : Color.black.opacity(0.06)
    }

    static var strokeDivider: Color {
        isDark ? AppColors.Border.softDivider : Color.black.opacity(0.10)
    }

    static var shadowColor: Color {
        isDark ? AppColors.Shadow.card : Color.black.opacity(0.12)
    }

    static var timeBadgeBackground: Color {
        isDark ? AppColors.Surface.cardOverlay : Color.black.opacity(0.08)
    }

    static var timeBadgeText: Color {
        textSecondary
    }

    static var consoleBadgeText: Color {
        Color(hex: "FFFFFF")
    }

    static func placeholderGradient(for system: String?) -> LinearGradient {
        let normalized = SubpageUI.CollectorIdentity.normalizedSystemCode(system)
        switch normalized {
        case "gbc", "gba", "nds":
            return SubpageUI.CollectorIdentity.placeholderGradient(forSystem: system)
        default:
            return LinearGradient(colors: [surfaceAlt, surface], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    static func placeholderGlyph(for system: String?) -> String {
        switch ConsoleIdentity.resolve(systemRaw: system) {
        case .gb, .gbc: return "rectangle.portrait.fill"
        case .gba: return "bolt.fill"
        case .nds: return "rectangle.split.2x1"
        default: return "gamecontroller.fill"
        }
    }
}

private struct AllGamesCardStyle: ViewModifier {
    let cornerRadius: CGFloat
    let elevated: Bool

    func body(content: Content) -> some View {
        content
            .background(AllGamesTokens.surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AllGamesTokens.strokeSubtle, lineWidth: 1)
            )
            .shadow(
                color: elevated ? AllGamesTokens.shadowColor : .clear,
                radius: elevated ? 4 : 0,
                x: 0,
                y: elevated ? 2 : 0
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct AllGamesSearchFieldStyle: ViewModifier {
    let cornerRadius: CGFloat
    let height: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(height: height)
            .background(AllGamesTokens.surfaceAlt)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AllGamesTokens.strokeSubtle, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

private struct AllGamesConsoleBadge: View {
    let text: String
    let backgroundColor: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AllGamesTokens.consoleBadgeText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct AllGamesTimeBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(AllGamesTokens.timeBadgeText)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AllGamesTokens.timeBadgeBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private extension View {
    func allGamesCard(cornerRadius: CGFloat = 20, elevated: Bool = true) -> some View {
        modifier(AllGamesCardStyle(cornerRadius: cornerRadius, elevated: elevated))
    }

    func allGamesSearchField(cornerRadius: CGFloat = 20, height: CGFloat = 44) -> some View {
        modifier(AllGamesSearchFieldStyle(cornerRadius: cornerRadius, height: height))
    }
}

enum LibrarySortOption: String, CaseIterable, Identifiable {
    case recent = "recent"
    case alphabetical = "alphabetical"
    case mostPlayed = "mostPlayed"

    var id: String { rawValue }

    init?(rawValue: String) {
        switch rawValue {
        case "recent": self = .recent
        case "alphabetical": self = .alphabetical
        case "mostPlayed": self = .mostPlayed
        default: return nil
        }
    }
}

enum LibrarySystemFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case gb = "gb"
    case gbc = "gbc"
    case gba = "gba"
    case nds = "nds"

    var id: String { rawValue }

    init?(rawValue: String) {
        switch rawValue {
        case "all": self = .all
        case "gb": self = .gb
        case "gbc": self = .gbc
        case "gba": self = .gba
        case "nds": self = .nds
        default: return nil
        }
    }

    var label: String {
        switch self {
        case .all: return "All"
        case .gb: return "Game Boy"
        case .gbc: return "Game Boy Color"
        case .gba: return "Game Boy Advance"
        case .nds: return "Nintendo DS"
        }
    }
}

enum LibraryViewMode: String {
    case grid = "grid"
    case list = "list"

    init?(rawValue: String) {
        switch rawValue {
        case "grid": self = .grid
        case "list": self = .list
        default: return nil
        }
    }
}

struct GameLibraryView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @StateObject private var performanceProfiler = PerformanceProfiler.shared
    @State private var games: [ROMLibraryEntry] = []
    @State private var selectedGame: Game?
    @State private var searchText = ""
    @AppStorage("library.sortOption") private var selectedSort: LibrarySortOption = .recent
    @AppStorage("library.systemFilter") private var selectedSystemFilter: LibrarySystemFilter = .all
    @AppStorage("library.viewMode") private var viewMode: LibraryViewMode = .grid
    @State private var showConsoleFilters: Bool = true
    @State private var activeAlert: LibraryAlertState?
    @State private var coverEditorEntry: ROMLibraryEntry?
    @State private var renameEntry: ROMLibraryEntry?
    @State private var renameTitle = ""
    @State private var detailEntry: ROMLibraryEntry?

    private var heavyUIEffectsEnabled: Bool {
        performanceProfiler.currentQualityProfile.heavyUIEffects
    }

    private var collectorAtmosphere: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.04), Color.clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var isCollectorMode: Bool {
#if os(iOS)
        verticalSizeClass == .compact
#else
        false
#endif
    }

    private var effectiveViewMode: LibraryViewMode {
        isCollectorMode ? .grid : viewMode
    }

    private var contentHorizontalPadding: CGFloat {
        isCollectorMode ? 20 : 20
    }

    private var gridColumns: [GridItem] {
        if isCollectorMode {
            #if os(iOS)
            let width = UIScreen.main.bounds.width
            let columnCount = width >= 1200 ? 4 : 3
            #else
            let columnCount = 4
            #endif
            return Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 20, alignment: .top), count: columnCount)
        }
        return [
            GridItem(.flexible(minimum: 0), spacing: 16),
            GridItem(.flexible(minimum: 0), spacing: 16)
        ]
    }
    
    var body: some View {
        ZStack {
            backgroundLayer
            if isCollectorMode {
                collectorAtmosphere
            }

            VStack(spacing: 0) {
                headerSection

                ScrollView {
                    VStack(spacing: 14) {
                        if filteredGames.isEmpty {
                            emptyState
                        } else if isCollectorMode {
                            collectorShelfContent
                        } else {
                            if effectiveViewMode == .grid {
                                gamesGrid
                            } else {
                                gamesList
                            }
                        }
                    }
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: isCollectorMode)
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
        .alert("Rename Game", isPresented: renameDialogPresented) {
            TextField("Game title", text: $renameTitle)
            Button("Cancel", role: .cancel) {
                clearRenameDraft()
            }
            Button("Save") {
                commitRename()
            }
            .disabled(renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Enter a new display title for this game.")
        }
        .onAppear {
            loadGames()
        }
        .onReceive(NotificationCenter.default.publisher(for: .romLibraryDidChange)) { _ in
            loadGames()
        }
        .onReceive(NotificationCenter.default.publisher(for: .coverArtDidChange)) { _ in
            loadGames()
        }
#if os(iOS)
        .sheet(item: $coverEditorEntry) { entry in
            CoverEditorSheet(entry: entry) {
                loadGames()
            }
        }
        .sheet(item: $detailEntry) { entry in
            NavigationStack {
                RomDetailView(rom: entry) {
                    detailEntry = nil
                }
            }
        }
#endif
    }

    private var filteredGames: [ROMLibraryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        let filteredBySystem = games.filter { entry in
            guard selectedSystemFilter != .all else { return true }
            let system = entry.resolvedSystemCode
            switch selectedSystemFilter {
            case .all:
                return true
            case .gb:
                return system == "gb"
            case .gbc:
                return system == "gbc"
            case .gba:
                return system == "gba"
            case .nds:
                return system == "nds"
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
                if leftDate != rightDate {
                    return leftDate > rightDate
                }
                return stableOrderingKey(lhs) < stableOrderingKey(rhs)
            })
        case .alphabetical:
            return filteredBySearch.sorted(by: {
                let compare = ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "")
                if compare == .orderedSame {
                    return stableOrderingKey($0) < stableOrderingKey($1)
                }
                return compare == .orderedAscending
            })
        case .mostPlayed:
            return filteredBySearch.sorted(by: {
                if $0.playtimeTotal != $1.playtimeTotal {
                    return $0.playtimeTotal > $1.playtimeTotal
                }
                return stableOrderingKey($0) < stableOrderingKey($1)
            })
        }
    }

    private func stableOrderingKey(_ entry: ROMLibraryEntry) -> String {
        entry.objectID.uriRepresentation().absoluteString
    }

    private var backgroundLayer: some View {
        ZStack {
            LinearGradient(
                colors: [AllGamesTokens.appBackground, AppColors.Background.appSecondary, AllGamesTokens.appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AllGamesTokens.accent.opacity(0.12), AllGamesTokens.info.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: heavyUIEffectsEnabled ? 36 : 22)
                .frame(width: 300, height: 300)
                .opacity(0.85)
                .offset(x: 140, y: -250)

            if heavyUIEffectsEnabled {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AllGamesTokens.info.opacity(0.08), AllGamesTokens.accent.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 28)
                    .frame(width: 240, height: 240)
                    .opacity(0.85)
                    .offset(x: -130, y: -180)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: isCollectorMode ? 8 : 10) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AllGamesTokens.textPrimary)
                }
                .buttonStyle(RMIconCircleButtonStyle())

                VStack(alignment: .leading, spacing: 1) {
                    Text("Game Library")
                        .font(isCollectorMode ? .system(size: 20, weight: .bold) : SubpageUI.Font.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                        .allowsTightening(true)
                        .foregroundColor(AllGamesTokens.textPrimary)
                    Text("\(games.count) games total")
                        .font(SubpageUI.Font.subtitle)
                        .foregroundColor(AllGamesTokens.textSecondary)
                }

                Spacer()
            }

            if isCollectorMode {
                HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13))
                            .foregroundColor(AllGamesTokens.textTertiary)

                        TextField("Search games...", text: $searchText)
#if os(iOS)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
#endif
                            .foregroundColor(AllGamesTokens.textPrimary)
                    }
                    .allGamesSearchField(cornerRadius: 19, height: 38)

                    Menu {
                        ForEach(LibrarySortOption.allCases) { option in
                            Button {
                                selectedSort = option
                            } label: {
                                HStack {
                                    Text(sortLabel(option))
                                    if selectedSort == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        RMChip(title: sortLabel(selectedSort), selected: true, style: .compact)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    RMChip(title: "\(filteredGames.count) on shelf", style: .compact)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(AllGamesTokens.textTertiary)

                    TextField("Search games...", text: $searchText)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
#endif
                        .foregroundColor(AllGamesTokens.textPrimary)
                }
                .allGamesSearchField(cornerRadius: 19, height: 38)

                HStack(spacing: 8) {
                    Menu {
                        ForEach(LibrarySortOption.allCases) { option in
                            Button {
                                selectedSort = option
                            } label: {
                                HStack {
                                    Text(sortLabel(option))
                                    if selectedSort == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        RMChip(title: sortLabel(selectedSort), selected: true)
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
                                .foregroundColor(viewMode == .grid ? Color.white : AllGamesTokens.textSecondary)
                                .frame(width: 34, height: 30)
                                .background(viewMode == .grid ? AllGamesTokens.accent : Color.clear)
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.easeOut(duration: 0.18)) {
                                viewMode = .list
                            }
                        } label: {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(viewMode == .list ? Color.white : AllGamesTokens.textSecondary)
                                .frame(width: 34, height: 30)
                                .background(viewMode == .list ? AllGamesTokens.accent : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                    .background(AllGamesTokens.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(AllGamesTokens.strokeSubtle, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 15))

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            showConsoleFilters.toggle()
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(showConsoleFilters ? Color.white : AllGamesTokens.textPrimary)
                            .frame(width: 34, height: 30)
                            .background(showConsoleFilters ? AllGamesTokens.accent : AllGamesTokens.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 15)
                                    .stroke(AllGamesTokens.strokeSubtle, lineWidth: 1)
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
                                    Text(filter.label)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(selectedSystemFilter == filter ? AppColors.Text.primary : AllGamesTokens.textSecondary)
                                        .padding(.horizontal, 12)
                                        .frame(height: 30)
                                        .background(selectedSystemFilter == filter ? AppColors.Surface.accentTintStrong : AllGamesTokens.surface)
                                        .overlay(
                                            Capsule().stroke(selectedSystemFilter == filter ? AppColors.Border.active : AllGamesTokens.strokeSubtle, lineWidth: 1)
                                        )
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
        }
        .padding(.horizontal, contentHorizontalPadding)
        .padding(.vertical, 12)
        .background(AllGamesTokens.appBackground.opacity(0.96))
        .overlay(
            Rectangle()
                .fill(AllGamesTokens.strokeDivider)
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var gamesGrid: some View {
        LazyVGrid(
            columns: gridColumns,
            spacing: 16
        ) {
            ForEach(filteredGames) { entry in
                AllGamesCard(entry: entry, collectorMode: isCollectorMode, selectedSystemFilter: selectedSystemFilter) {
                    launchGame(entry)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .buttonStyle(PressScaleButtonStyle())
                .contextMenu { gameActionsMenu(for: entry) }
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var gamesList: some View {
        LazyVStack(spacing: 12) {
            ForEach(filteredGames) { entry in
                AllGamesListRow(entry: entry) {
                    launchGame(entry)
                }
                .buttonStyle(PressScaleButtonStyle())
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
#if os(iOS)
                    if let shareURL = shareableROMURL(for: entry) {
                        ShareLink(item: shareURL) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .tint(.blue)
                    }
#endif
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        activeAlert = LibraryAlertState(kind: .confirmDelete(LibraryDeleteCandidate(entry: entry, mode: .removeAll)))
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
                .contextMenu { gameActionsMenu(for: entry) }
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var collectorShelfContent: some View {
        VStack(alignment: .leading, spacing: 26) {
            CollectorShelfFilterRail(
                selectedFilter: selectedSystemFilter,
                counts: shelfCounts
            ) { filter in
                selectedSystemFilter = filter
            }

            ForEach(collectorSections, id: \.key) { section in
                CollectorShelfSectionView(
                    title: section.title,
                    subtitle: "\(section.entries.count) games",
                    entries: section.entries
                ) { entry in
                    collectorShelfBox(entry, metadata: shelfMetadata(for: entry), progress: nil, showsMetadataByDefault: false)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: searchText.isEmpty ? "gamecontroller" : "magnifyingglass")
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(AllGamesTokens.textTertiary)

            Text(searchText.isEmpty ? "No Games Yet" : "No Matching Games")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AllGamesTokens.textPrimary)

            Text(searchText.isEmpty ? "Import some ROMs to get started!" : "Try a different search term.")
                .font(.system(size: 12))
                .foregroundColor(AllGamesTokens.textSecondary)
                .multilineTextAlignment(.center)

            if !searchText.isEmpty || selectedSystemFilter != .all {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        searchText = ""
                        selectedSystemFilter = .all
                    }
                } label: {
                    Text("Clear Filter")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AllGamesTokens.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .allGamesCard(cornerRadius: 16, elevated: false)
    }

    private var collectorSections: [(key: String, title: String, entries: [ROMLibraryEntry])] {
        let grouped = Dictionary(grouping: filteredGames) { entry in
            CollectorShelfGrouping.sectionKey(for: entry.resolvedSystemCode)
        }

        return CollectorShelfGrouping.orderedSectionKeys(for: filteredGames.map(\.resolvedSystemCode)).compactMap { key in
            guard let entries = grouped[key], !entries.isEmpty else { return nil }
            return (
                key: key,
                title: CollectorShelfGrouping.sectionTitle(for: key),
                entries: entries.sorted(by: collectorSectionOrdering(_:_:))
            )
        }
    }

    private var shelfCounts: [LibrarySystemFilter: Int] {
        [
            .all: games.count,
            .gb: games.filter {
                let key = CollectorShelfGrouping.sectionKey(for: $0.resolvedSystemCode)
                return key == "gb"
            }.count,
            .gbc: games.filter {
                let key = CollectorShelfGrouping.sectionKey(for: $0.resolvedSystemCode)
                return key == "gbc"
            }.count,
            .gba: games.filter {
                let key = CollectorShelfGrouping.sectionKey(for: $0.resolvedSystemCode)
                return key == "gba"
            }.count,
            .nds: games.filter {
                let key = CollectorShelfGrouping.sectionKey(for: $0.resolvedSystemCode)
                return key == "nds"
            }.count
        ]
    }

    private func collectorSectionOrdering(_ lhs: ROMLibraryEntry, _ rhs: ROMLibraryEntry) -> Bool {
        switch selectedSort {
        case .recent:
            let leftDate = lhs.lastPlayedAt ?? lhs.dateAdded ?? Date.distantPast
            let rightDate = rhs.lastPlayedAt ?? rhs.dateAdded ?? Date.distantPast
            if leftDate != rightDate {
                return leftDate > rightDate
            }
        case .alphabetical:
            let compare = (lhs.title ?? "").localizedCaseInsensitiveCompare(rhs.title ?? "")
            if compare != .orderedSame {
                return compare == .orderedAscending
            }
        case .mostPlayed:
            if lhs.playtimeTotal != rhs.playtimeTotal {
                return lhs.playtimeTotal > rhs.playtimeTotal
            }
        }
        return stableOrderingKey(lhs) < stableOrderingKey(rhs)
    }

    private func collectorShelfBox(
        _ entry: ROMLibraryEntry,
        metadata: String,
        progress: CGFloat?,
        showsMetadataByDefault: Bool
    ) -> some View {
        CollectorShelfBoxButton(
            title: displayTitle(entry.title),
            systemTag: (entry.system ?? "UNK").uppercased(),
            metadata: metadata,
            progress: progress,
            showsMetadataByDefault: showsMetadataByDefault
        ) {
            launchGame(entry)
        } artwork: {
            collectorShelfArtwork(for: entry)
        }
        .contextMenu {
            gameActionsMenu(for: entry)
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

    @ViewBuilder
    private func gameActionsMenu(for entry: ROMLibraryEntry) -> some View {
        Button {
            launchGame(entry)
        } label: {
            Label("Play", systemImage: "play.fill")
        }
        Button {
            beginRename(entry)
        } label: {
            Label("Rename", systemImage: "pencil")
        }
        Button {
            editCover(entry)
        } label: {
            Label("Edit Cover", systemImage: "photo")
        }
        Button(role: .destructive) {
            resetCover(entry)
        } label: {
            Label("Reset Cover", systemImage: "arrow.counterclockwise")
        }
        .disabled(!hasCustomCover(entry))
        Button {
            showDetails(entry)
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

    private var renameDialogPresented: Binding<Bool> {
        Binding(
            get: { renameEntry != nil },
            set: { isPresented in
                if !isPresented {
                    clearRenameDraft()
                }
            }
        )
    }

    private func beginRename(_ entry: ROMLibraryEntry) {
        renameEntry = entry
        renameTitle = entry.title ?? ""
    }

    private func clearRenameDraft() {
        renameEntry = nil
        renameTitle = ""
    }

    private func commitRename() {
        guard let entry = renameEntry else { return }
        do {
            try GameRenameService.shared.rename(entry: entry, to: renameTitle, in: viewContext)
#if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
            clearRenameDraft()
            loadGames()
        } catch {
            activeAlert = LibraryAlertState(kind: .launchError("Could not rename game: \(error.localizedDescription)"))
        }
    }

    private func showDetails(_ entry: ROMLibraryEntry) {
        detailEntry = entry
    }

    private func editCover(_ entry: ROMLibraryEntry) {
#if os(iOS)
        coverEditorEntry = entry
#endif
    }

    private func hasCustomCover(_ entry: ROMLibraryEntry) -> Bool {
        !((entry.customCoverURL ?? "").isEmpty) || CoverArtService.shared.customCoverExists(for: entry.id)
    }

    private func resetCover(_ entry: ROMLibraryEntry) {
        CoverArtService.shared.removeCustomCover(for: entry.id)
        entry.customCoverURL = nil
        CoverArtService.shared.assignDeterministicPlaceholderIfNeeded(to: entry)
        do {
            try viewContext.save()
#if os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
            loadGames()
        } catch {
            activeAlert = LibraryAlertState(kind: .launchError("Could not reset cover: \(error.localizedDescription)"))
        }
    }

    private func shareableROMURL(for entry: ROMLibraryEntry) -> URL? {
        guard let checksum = entry.checksum else { return nil }
        let preferredExt = (entry.fileName as NSString?)?.pathExtension.lowercased() ?? ""
        if let location = ROMStorage.shared.getROMLocation(checksum: checksum, fileExtension: preferredExt) {
            return location.url
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let romsDir = docs?.appendingPathComponent("ROMs", isDirectory: true)
        guard let romsDir,
              let files = try? FileManager.default.contentsOfDirectory(at: romsDir, includingPropertiesForKeys: nil) else {
            return nil
        }

        return files.first(where: { $0.lastPathComponent.lowercased().hasPrefix("\(checksum.lowercased()).") })
    }

    @ViewBuilder
    private func collectorShelfArtwork(for entry: ROMLibraryEntry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.16), Color.black.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

#if os(iOS)
            if let resolved = CoverArtService.shared.resolve(for: entry),
               let uiImage = UIImage(data: resolved.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                collectorShelfPlaceholder(for: entry)
            }
#else
            collectorShelfPlaceholder(for: entry)
#endif
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.18), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func collectorShelfPlaceholder(for entry: ROMLibraryEntry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AllGamesTokens.placeholderGradient(for: entry.system))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: AllGamesTokens.placeholderGlyph(for: entry.system))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.40))
                    Spacer()
                }

                Spacer()

                Text(String((displayTitle(entry.title)).prefix(1)).uppercased())
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.18))
            }
            .padding(14)
        }
    }

    private func shelfMetadata(for entry: ROMLibraryEntry) -> String {
        if entry.playtimeTotal > 0 {
            return playtimeLabel(for: entry)
        }
        if let issue = ROMCompatibilityService.shared.compatibility(for: entry).issue {
            return issue.title
        }
        return "Ready"
    }

    private func shelfLastPlayedLabel(for entry: ROMLibraryEntry) -> String {
        guard let lastPlayed = entry.lastPlayedAt else { return shelfMetadata(for: entry) }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastPlayed, relativeTo: Date())
    }

    private func shelfProgress(for entry: ROMLibraryEntry) -> CGFloat? {
        guard entry.playtimeTotal > 0 else { return nil }
        return max(0.08, min(1.0, CGFloat(entry.playtimeTotal) / CGFloat(4 * 3600)))
    }

    private func playtimeLabel(for entry: ROMLibraryEntry) -> String {
        let minutes = Int(entry.playtimeTotal) / 60
        if minutes < 60 {
            return "\(max(minutes, 1))m"
        }
        return "\(minutes / 60)h"
    }

    private func displayTitle(_ title: String?) -> String {
        GameCardTitleFormatter.format(title, maxWords: 7)
    }

    private func sortLabel(_ option: LibrarySortOption) -> String {
        switch option {
        case .recent: return "Recent"
        case .alphabetical: return "A-Z"
        case .mostPlayed: return "Most Played"
        }
    }
}

struct AllGamesCard: View {
    static let collectorCoverAspectRatio: CGFloat = 0.75

    let entry: ROMLibraryEntry
    let collectorMode: Bool
    let selectedSystemFilter: LibrarySystemFilter
    let onTap: () -> Void

    private let coverCornerRadius: CGFloat = 18

    init(entry: ROMLibraryEntry, collectorMode: Bool = false, selectedSystemFilter: LibrarySystemFilter = .all, onTap: @escaping () -> Void) {
        self.entry = entry
        self.collectorMode = collectorMode
        self.selectedSystemFilter = selectedSystemFilter
        self.onTap = onTap
    }

    private var coverAspectRatio: CGFloat {
        Self.collectorCoverAspectRatio
    }

    var body: some View {
        let issue = ROMCompatibilityService.shared.compatibility(for: entry).issue
        let metadata = issue?.title ?? lastPlayedLabel
        let shouldShowBadge = !(entry.resolvedSystemCode == "gba" &&
                              selectedSystemFilter == .gba)
        let platformTag = entry.consoleIdentity?.systemCode ?? (entry.system ?? "UNK").uppercased()
        let progress: CGFloat? = entry.playtimeTotal > 0 ? max(0.08, min(1.0, CGFloat(entry.playtimeTotal) / CGFloat(4 * 3600))) : nil
        let content = Button(action: onTap) {
            CollectorGameCard(
                variant: collectorMode ? .standard : .compact,
                title: displayTitle(entry.title),
                metadataPrimary: metadata,
                metadataSecondary: entry.playtimeTotal > 0 ? playtimeBadge : nil,
                platformTag: shouldShowBadge ? platformTag : nil,
                launchIssueIconName: issue?.iconName,
                progress: progress
            ) {
                coverArt
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        if collectorMode {
            content
                .buttonStyle(CollectorCardPressStyle())
        } else {
            content
                .buttonStyle(PlainButtonStyle())
                .allGamesCard(cornerRadius: 18, elevated: true)
        }
    }

    private var coverSection: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { proxy in
                coverArt
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }

            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.28)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .aspectRatio(coverAspectRatio, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay {
            LinearGradient(
                colors: [Color.white.opacity(0.12), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: coverCornerRadius))
            .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: coverCornerRadius)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottomLeading) {
            if entry.playtimeTotal > 0 {
                AllGamesTimeBadge(text: playtimeBadge)
                    .padding(collectorMode ? 6 : 8)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            let shouldShowBadge = !(entry.resolvedSystemCode == "gba" &&
                                  selectedSystemFilter == .gba)
            if shouldShowBadge {
                AllGamesConsoleBadge(
                    text: entry.consoleIdentity?.systemCode ?? (entry.system ?? "UNK").uppercased(),
                    backgroundColor: SubpageUI.CollectorIdentity.accent(forSystem: entry.resolvedSystemCode)
                )
                    .padding(collectorMode ? 6 : 8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: coverCornerRadius))
        .overlay(alignment: .bottom) {
            if collectorMode {
                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .frame(width: proxy.size.width * 0.72, height: 10)
                        .blur(radius: 8)
                        .offset(y: 8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .allowsHitTesting(false)
            }
        }
        .shadow(
            color: .black.opacity(collectorMode ? 0.12 : 0.08),
            radius: collectorMode ? 12 : 8,
            x: 0,
            y: collectorMode ? 6 : 4
        )
        .shadow(
            color: SubpageUI.CollectorIdentity.glow(forSystem: entry.system).opacity(collectorMode ? 1.0 : 0.0),
            radius: collectorMode ? 10 : 0,
            x: 0,
            y: collectorMode ? 5 : 0
        )
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(displayTitle(entry.title))
                .font(.system(size: collectorMode ? 14 : 15, weight: .semibold))
                .foregroundColor(AllGamesTokens.textPrimary)
                .lineLimit(2)
                .truncationMode(.tail)

            HStack(spacing: 5) {
                Image(systemName: ROMCompatibilityService.shared.compatibility(for: entry).issue == nil ? "clock.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text(ROMCompatibilityService.shared.compatibility(for: entry).issue?.title ?? lastPlayedLabel)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundColor(ROMCompatibilityService.shared.compatibility(for: entry).issue == nil ? AllGamesTokens.textSecondary : .orange)
        }
        .frame(height: collectorMode ? 46 : 56, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.bottom, collectorMode ? 0 : 12)
    }

    private var coverArt: some View {
        Group {
            #if os(iOS)
            if let resolved = CoverArtService.shared.resolve(for: entry) {
                if isGIFData(resolved.data) {
                    AnimatedGIFView(data: resolved.data)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let uiImage = UIImage(data: resolved.data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholderGlyph
                }
            } else {
                placeholderGlyph
            }
            #else
            placeholderGlyph
            #endif
        }
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private var placeholderGlyph: some View {
        GeometryReader { proxy in
            let minSide = min(proxy.size.width, proxy.size.height)
            let letterSize = minSide * 0.25

            ZStack {
                RoundedRectangle(cornerRadius: coverCornerRadius)
                    .fill(AllGamesTokens.placeholderGradient(for: entry.system))

                RadialGradient(
                    colors: [Color.white.opacity(AllGamesTokens.isDark ? 0.12 : 0.18), .clear],
                    center: .topLeading,
                    startRadius: 8,
                    endRadius: minSide * 0.85
                )
                .blendMode(.screen)

                Text(String((entry.title ?? "?").prefix(1)).uppercased())
                    .font(.system(size: letterSize, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.15))
                    .shadow(color: .black.opacity(0.14), radius: 2, x: 0, y: 1)

                VStack {
                    HStack {
                        Image(systemName: AllGamesTokens.placeholderGlyph(for: entry.system))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white.opacity(0.42))
                        Spacer()
                    }
                    .padding(10)

                    Spacer()

                    HStack {
                        Spacer()
                        Image(systemName: AllGamesTokens.placeholderGlyph(for: entry.system))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.30))
                    }
                    .padding(10)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func displayTitle(_ title: String?) -> String {
        GameCardTitleFormatter.format(title, maxWords: 7)
    }
}

private struct AllGamesListRow: View {
    let entry: ROMLibraryEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                rowThumbnail
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle(entry.title))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AllGamesTokens.textPrimary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        AllGamesConsoleBadge(
                            text: (entry.system ?? "UNK").uppercased(),
                            backgroundColor: SubpageUI.CollectorIdentity.accent(forSystem: entry.system)
                        )

                        Text(lastPlayedLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AllGamesTokens.textSecondary)
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
                    .foregroundColor(AllGamesTokens.textTertiary)
            }
            .padding(12)
            .frame(minHeight: 96)
            .allGamesCard(cornerRadius: 18, elevated: false)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var rowThumbnail: some View {
        ZStack {
            #if os(iOS)
            if let resolved = CoverArtService.shared.resolve(for: entry),
               let uiImage = UIImage(data: resolved.data) {
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
                        AllGamesTokens.placeholderGradient(for: entry.system)
                    )
                    .overlay(
                        Image(systemName: AllGamesTokens.placeholderGlyph(for: entry.system))
                            .font(.system(size: 20))
                            .foregroundColor(Color.white.opacity(0.28))
                    )
            }
            #else
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    AllGamesTokens.placeholderGradient(for: entry.system)
                )
                .overlay(
                    Image(systemName: AllGamesTokens.placeholderGlyph(for: entry.system))
                        .font(.system(size: 20))
                        .foregroundColor(Color.white.opacity(0.28))
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

    private func displayTitle(_ title: String?) -> String {
        GameCardTitleFormatter.format(title, maxWords: 7)
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

#if os(iOS)
struct AnimatedGIFView: View {
    let data: Data

    @State private var currentFrameIndex = 0
    @State private var currentImage: UIImage?
    @State private var isAnimating = false
    @State private var loadedFrames: [UIImage] = []
    @State private var loadedDurations: [TimeInterval] = []

    var body: some View {
        Group {
            if let image = currentImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            loadAndAnimateGIF()
        }
        .onDisappear {
            stopAnimation()
        }
    }

    private func loadAndAnimateGIF() {
        guard !isAnimating else { return }
        isAnimating = true
        loadedFrames.removeAll()
        loadedDurations.removeAll()
        currentFrameIndex = 0
        currentImage = nil

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            isAnimating = false
            return
        }

        let count = CGImageSourceGetCount(source)
        guard count > 0 else {
            isAnimating = false
            return
        }

        var frames: [UIImage] = []
        var durations: [TimeInterval] = []

        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                let image = UIImage(cgImage: cgImage)
                frames.append(image)

                let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any]
                let gifDict = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
                let delay = gifDict?[kCGImagePropertyGIFDelayTime] as? TimeInterval ?? 0.1
                durations.append(delay)
            }
        }

        guard !frames.isEmpty, !durations.isEmpty else {
            isAnimating = false
            return
        }

        self.loadedFrames = frames
        self.loadedDurations = durations
        self.currentImage = frames.first
        self.currentFrameIndex = 0

        // Start animation immediately
        scheduleNextFrame()
    }

    private func stopAnimation() {
        isAnimating = false
    }

    private func scheduleNextFrame() {
        guard isAnimating,
              !loadedFrames.isEmpty,
              !loadedDurations.isEmpty,
              currentFrameIndex < loadedFrames.count,
              currentFrameIndex < loadedDurations.count else { return }

        let delay = loadedDurations[currentFrameIndex]
        // Use a minimum delay to ensure animation is visible
        let adjustedDelay = max(delay, 0.05)

        DispatchQueue.main.asyncAfter(deadline: .now() + adjustedDelay) {
            guard self.isAnimating else { return }
            self.currentFrameIndex = (self.currentFrameIndex + 1) % self.loadedFrames.count
            self.currentImage = self.loadedFrames[self.currentFrameIndex]
            self.scheduleNextFrame()
        }
    }
}
#endif

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
