import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif

struct RecentlyPlayedView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var languageManager: LanguageManager

    @StateObject private var performanceProfiler = PerformanceProfiler.shared
    @State private var games: [ROMLibraryEntry] = []
    @State private var searchText = ""
    @State private var selectedGame: Game?
    @State private var activeAlert: RecentAlertState?
    @State private var showEarlier = false
    @State private var sortMode: RecentSortMode = .recent
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

    private var collectorGridColumns: [GridItem] {
#if os(iOS)
        let width = UIScreen.main.bounds.width
        let columnCount = width >= 1200 ? 4 : 3
#else
        let columnCount = 4
#endif
        return Array(repeating: GridItem(.flexible(minimum: 0), spacing: 20), count: columnCount)
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
                    VStack(alignment: .leading, spacing: 28) {
                        if filteredAndSortedGames.isEmpty {
                            emptyState
                        } else {
                            continuePlayingSection
                            recentlyPlayedSection
                            earlierSection
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)
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
            switch state {
            case .launchError(let message):
                return Alert(
                    title: Text(L10n.string("home.alert.launch_failed", languageManager: languageManager)),
                    message: Text(message),
                    dismissButton: .cancel(Text(L10n.string("common.ok", languageManager: languageManager)))
                )
            case .confirmDelete(let candidate):
                return Alert(
                    title: Text(candidate.mode.displayName),
                    message: Text(candidate.mode.firstConfirmation),
                    primaryButton: .default(Text(L10n.string("common.continue", languageManager: languageManager))) {
                        activeAlert = .confirmFinalDelete(candidate)
                    },
                    secondaryButton: .cancel()
                )
            case .confirmFinalDelete(let candidate):
                return Alert(
                    title: Text(L10n.string("home.alert.final_confirmation", languageManager: languageManager)),
                    message: Text(candidate.mode.secondConfirmation),
                    primaryButton: .destructive(Text(L10n.string("common.delete", languageManager: languageManager))) {
                        performDeletion(candidate)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        .alert(L10n.string("common.rename_game", languageManager: languageManager), isPresented: renameDialogPresented) {
            TextField(L10n.string("common.game_title", languageManager: languageManager), text: $renameTitle)
            Button(L10n.string("common.cancel", languageManager: languageManager), role: .cancel) {
                clearRenameDraft()
            }
            Button(L10n.string("common.save", languageManager: languageManager)) {
                commitRename()
            }
            .disabled(renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text(L10n.string("home.rename_game.message", languageManager: languageManager))
        }
        .onAppear(perform: loadGames)
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

    private var sortedGames: [ROMLibraryEntry] {
        switch sortMode {
        case .recent:
            return games.sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
        case .mostPlayed:
            return games.sorted { $0.playtimeTotal > $1.playtimeTotal }
        case .alphabetical:
            return games.sorted {
                ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending
            }
        }
    }

    private var filteredAndSortedGames: [ROMLibraryEntry] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sortedGames }
        return sortedGames.filter { entry in
            (entry.title ?? "").localizedCaseInsensitiveContains(q) ||
            (entry.system ?? "").localizedCaseInsensitiveContains(q)
        }
    }

    private var resumeGames: [ROMLibraryEntry] {
        Array(filteredAndSortedGames.prefix(5))
    }

    private var activeListGames: [ROMLibraryEntry] {
        Array(filteredAndSortedGames.dropFirst(resumeGames.count).prefix(5))
    }

    private var earlierGames: [ROMLibraryEntry] {
        Array(filteredAndSortedGames.dropFirst(resumeGames.count + activeListGames.count))
    }

    private var backgroundLayer: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.12), AppColors.accent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: heavyUIEffectsEnabled ? 120 : 30)
                .frame(width: 380, height: 380)
                .offset(x: 170, y: -240)
        }
    }

    private var headerSection: some View {
        VStack(spacing: isCollectorMode ? 8 : 12) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(AppColors.surfaceLight.opacity(0.50))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("recent.title", table: "Screens", languageManager: languageManager))
                        .font(isCollectorMode ? .system(size: 22, weight: .bold) : SubpageUI.Font.heroTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                        .layoutPriority(1)
                        .foregroundColor(AppColors.textPrimary)
                    Text(L10n.format("common.games_count", Int64(games.count), table: "Screens", languageManager: languageManager))
                        .font(SubpageUI.Font.subtitle)
                        .foregroundColor(isCollectorMode ? AppColors.textSecondary : AppColors.primary)
                }

                Spacer()

                Menu {
                    ForEach(RecentSortMode.allCases, id: \.self) { mode in
                        Button {
                            sortMode = mode
                        } label: {
                            if mode == sortMode {
                                Label(mode.title, systemImage: "checkmark")
                            } else {
                                Text(mode.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(sortMode.shortTitle)
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(AppColors.surfaceLight.opacity(0.45))
                    .overlay(
                        Capsule().stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textMuted)

                TextField(L10n.string("recent.search_placeholder", table: "Screens", languageManager: languageManager), text: $searchText)
#if os(iOS)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
#endif
                    .foregroundColor(AppColors.textPrimary)
                    .font(.system(size: 17))
            }
            .subpageSearchField(cornerRadius: 22, height: isCollectorMode ? 38 : 44)
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(AppColors.background.opacity(0.88))
        .overlay(
            Rectangle()
                .fill(AppColors.surfaceLight.opacity(0.55))
                .frame(height: 1),
            alignment: .bottom
        )
    }

    private var continuePlayingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.string("recent.section.active_sessions", table: "Screens", languageManager: languageManager))
                .font(SubpageUI.Font.sectionTitle)
                .foregroundColor(AppColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(resumeSessionCards) { game in
                        RecentGameCard(game: game, variant: .standard) {
                            launchRecentGame(game)
                        }
                        .frame(width: 280)
                        .contextMenu {
                            if let entry = entry(for: game.gameId) {
                                recentContextMenu(entry)
                            }
                        }
                    }
                }
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
    }

    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("recent.section.play_history", table: "Screens", languageManager: languageManager))
                .font(SubpageUI.Font.sectionTitle)
                .foregroundColor(AppColors.textPrimary)

            VStack(spacing: 12) {
                ForEach(activeListGames) { entry in
                    RecentRow(entry: entry) {
                        launchGame(entry)
                    }
                    .contextMenu {
                        recentContextMenu(entry)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var earlierSection: some View {
        if !earlierGames.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.9)) {
                        showEarlier.toggle()
                    }
                } label: {
                    HStack {
                        Text(L10n.string("recent.section.earlier", table: "Screens", languageManager: languageManager))
                            .font(SubpageUI.Font.sectionTitle)
                        Spacer()
                        Image(systemName: showEarlier ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(AppColors.textPrimary)
                }
                .buttonStyle(.plain)

                if showEarlier {
                    VStack(spacing: 12) {
                        ForEach(earlierGames) { entry in
                            RecentRow(entry: entry) {
                                launchGame(entry)
                            }
                            .contextMenu {
                                recentContextMenu(entry)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 30, weight: .medium))
                .foregroundColor(AppColors.textMuted)

            Text(
                searchText.isEmpty
                    ? L10n.string("recent.empty.none", table: "Screens", languageManager: languageManager)
                    : L10n.string("common.no_matching_games", table: "Screens", languageManager: languageManager)
            )
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)

            Text(
                searchText.isEmpty
                    ? L10n.string("recent.empty.none_hint", table: "Screens", languageManager: languageManager)
                    : L10n.string("common.try_different_search", table: "Screens", languageManager: languageManager)
            )
                .font(.system(size: 13))
                .foregroundColor(AppColors.textMuted)
                .multilineTextAlignment(.center)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Text(L10n.string("common.clear_search", table: "Screens", languageManager: languageManager))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(AppColors.primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .subpageCard(cornerRadius: 18)
    }

    @ViewBuilder
    private func recentContextMenu(_ entry: ROMLibraryEntry) -> some View {
        Button {
            launchGame(entry)
        } label: {
            Label(L10n.string("common.play", table: "Screens", languageManager: languageManager), systemImage: "play.fill")
        }
        Button {
            beginRename(entry)
        } label: {
            Label(L10n.string("home.context.rename", languageManager: languageManager), systemImage: "pencil")
        }
        Button {
            editCover(entry)
        } label: {
            Label(L10n.string("common.edit_cover", table: "Screens", languageManager: languageManager), systemImage: "photo")
        }
        Button {
            showDetails(entry)
        } label: {
            Label(L10n.string("home.context.details", languageManager: languageManager), systemImage: "info.circle")
        }
        Button(role: .destructive) {
            resetCover(entry)
        } label: {
            Label(L10n.string("common.reset_cover", table: "Screens", languageManager: languageManager), systemImage: "arrow.counterclockwise")
        }
        .disabled(!hasCustomCover(entry))
#if os(iOS)
        if let shareURL = shareableROMURL(for: entry) {
            ShareLink(item: shareURL) {
                Label(L10n.string("common.share", table: "Screens", languageManager: languageManager), systemImage: "square.and.arrow.up")
            }
        }
#endif
        Button(role: .destructive) {
            activeAlert = .confirmDelete(RecentDeleteCandidate(entry: entry, mode: .removeROMOnly))
        } label: {
            Label(L10n.string("home.context.remove_rom_only", languageManager: languageManager), systemImage: "eject")
        }
        Button(role: .destructive) {
            activeAlert = .confirmDelete(RecentDeleteCandidate(entry: entry, mode: .removeAll))
        } label: {
            Label(L10n.string("home.context.remove", languageManager: languageManager), systemImage: "trash")
        }
    }

    private func loadGames() {
        let request = NSFetchRequest<ROMLibraryEntry>(entityName: "ROMLibraryEntry")
        request.sortDescriptors = [NSSortDescriptor(key: "lastPlayedAt", ascending: false)]
        request.predicate = NSPredicate(format: "lastPlayedAt != nil")
        do {
            games = try viewContext.fetch(request)
        } catch {
            games = []
        }
    }

    private var resumeSessionCards: [RecentGame] {
        resumeGames.map { entry in
            RecentGame(
                id: "recent-\(entry.objectID.uriRepresentation().absoluteString)",
                title: entry.title ?? L10n.string("common.unknown_game", table: "Screens", languageManager: languageManager),
                console: entry.system?.uppercased() ?? L10n.string("common.unknown", table: "Screens", languageManager: languageManager),
                lastPlayed: entry.lastPlayedAt,
                progress: 0,
                image: nil,
                screenshotData: SaveStateStorage.shared.latestScreenshot(for: entry.checksum ?? ""),
                coverData: CoverArtService.shared.resolve(for: entry)?.data,
                totalPlaySeconds: Int(entry.playtimeTotal),
                playableGame: entry.toGame(),
                gameId: entry.id,
                launchIssue: ROMCompatibilityService.shared.compatibility(for: entry).issue
            )
        }
    }

    private func launchGame(_ entry: ROMLibraryEntry) {
        let compatibility = ROMCompatibilityService.shared.compatibility(for: entry)
        if let issue = compatibility.issue {
            activeAlert = .launchError(issue.message)
            return
        }
        guard let game = entry.toGame() else { return }
        selectedGame = game
    }

    private func launchRecentGame(_ recent: RecentGame) {
        if let issue = recent.launchIssue {
            activeAlert = .launchError(issue.message)
            return
        }
        if let playableGame = recent.playableGame {
            selectedGame = playableGame
        }
    }

    private func entry(for id: UUID) -> ROMLibraryEntry? {
        games.first(where: { $0.id == id })
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
            activeAlert = .launchError(
                L10n.format(
                    "recent.error.rename_failed",
                    error.localizedDescription,
                    table: "Screens",
                    languageManager: languageManager
                )
            )
        }
    }

    private func showDetails(_ entry: ROMLibraryEntry) {
        detailEntry = entry
    }

    private func performDeletion(_ candidate: RecentDeleteCandidate) {
        do {
            try GameDeletionService.shared.delete(entry: candidate.entry, mode: candidate.mode, in: viewContext)
            loadGames()
        } catch {
            activeAlert = .launchError(
                L10n.format(
                    "recent.error.delete_failed",
                    error.localizedDescription,
                    table: "Screens",
                    languageManager: languageManager
                )
            )
        }
    }

    private func editCover(_ entry: ROMLibraryEntry) {
#if os(iOS)
        coverEditorEntry = entry
#endif
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
            activeAlert = .launchError(
                L10n.format(
                    "recent.error.reset_cover_failed",
                    error.localizedDescription,
                    table: "Screens",
                    languageManager: languageManager
                )
            )
        }
    }

    private func shareableROMURL(for entry: ROMLibraryEntry) -> URL? {
        guard let checksum = entry.checksum else { return nil }
        let ext = (entry.fileName as NSString?)?.pathExtension.lowercased() ?? ""
        if let location = ROMStorage.shared.getROMLocation(checksum: checksum, fileExtension: ext) {
            return location.url
        }
        return nil
    }

    private func hasCustomCover(_ entry: ROMLibraryEntry) -> Bool {
        !((entry.customCoverURL ?? "").isEmpty) || CoverArtService.shared.customCoverExists(for: entry.id)
    }
}

private struct RecentCollectorCard: View {
    let entry: ROMLibraryEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            CollectorGameCard(
                variant: .standard,
                title: GameCardTitleFormatter.format(entry.title, maxWords: 7),
                metadataPrimary: lastPlayedLabel,
                metadataSecondary: playtimeLabel,
                platformTag: (entry.system ?? "UNK").uppercased(),
                launchIssueIconName: ROMCompatibilityService.shared.compatibility(for: entry).issue?.iconName,
                progress: nil
            ) {
                coverArt
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .buttonStyle(CollectorCardPressStyle())
    }

    @ViewBuilder
    private var coverArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(SubpageUI.CollectorIdentity.placeholderGradient(forSystem: entry.system))
#if os(iOS)
            if let resolved = CoverArtService.shared.resolve(for: entry),
               let uiImage = UIImage(data: resolved.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else if let screenshotData = SaveStateStorage.shared.latestScreenshot(for: entry.checksum ?? ""),
                      let uiImage = UIImage(data: screenshotData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.textMuted)
            }
#else
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 24))
                .foregroundColor(AppColors.textMuted)
#endif
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay {
            LinearGradient(
                colors: [Color.white.opacity(0.12), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .bottom) {
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
        .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
        .shadow(color: SubpageUI.CollectorIdentity.glow(forSystem: entry.system), radius: 10, x: 0, y: 5)
    }

    private var playtimeLabel: String? {
        if entry.playtimeTotal > 0 {
            return LocaleFormatting.shortDuration(seconds: Int(entry.playtimeTotal), minimumMinutes: 1)
        }
        return nil
    }

    private var lastPlayedLabel: String {
        guard let date = entry.lastPlayedAt else {
            return L10n.string("common.never_played", table: "Screens")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct RecentResumeCard: View {
    let entry: ROMLibraryEntry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                coverArt
                    .frame(width: 280, height: 160)
                    .overlay(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.58)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                VStack(alignment: .leading, spacing: 7) {
                    Text(GameCardTitleFormatter.format(entry.title, maxWords: 7))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(height: 42, alignment: .topLeading)
                        .shadow(color: .black.opacity(0.25), radius: 4, x: 0, y: 1)

                    Text(lastPlayedLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.88))

                    GeometryReader { geo in
                        Capsule()
                            .fill(Color.white.opacity(0.26))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.84))
                                    .frame(width: max(14, geo.size.width * progress))
                            }
                    }
                    .frame(height: 5)
                }
                .padding(14)

                VStack {
                    HStack {
                        Spacer()
                        Text((entry.system ?? "UNK").uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.94))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.primary.opacity(0.70))
                            .clipShape(Capsule())
                    }
                    Spacer()
                }
                .padding(10)
            }
            .frame(width: 280, height: 160)
            .subpageCard(cornerRadius: 20, shadowOpacity: 0.10)
        }
        .buttonStyle(RecentCardPressStyle())
    }

    private var progress: CGFloat {
        let capped = min(max(Int(entry.playtimeTotal), 0), 14_400)
        return CGFloat(capped) / 14_400.0
    }

    private var lastPlayedLabel: String {
        guard let date = entry.lastPlayedAt else {
            return L10n.string("common.never_played", table: "Screens")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    @ViewBuilder
    private var coverArt: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surfaceLight, AppColors.surface],
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
            } else if let screenshotData = SaveStateStorage.shared.latestScreenshot(for: entry.checksum ?? ""),
                      let uiImage = UIImage(data: screenshotData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.textMuted)
            }
#else
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 32))
                .foregroundColor(AppColors.textMuted)
#endif
        }
        .clipped()
    }
}

private struct RecentCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct RecentRow: View {
    let entry: ROMLibraryEntry
    let onTap: () -> Void
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                thumbnail
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 5) {
                    Text(GameCardTitleFormatter.format(entry.title, maxWords: 7))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(height: 42, alignment: .topLeading)

                    Text(metaLine)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.primary)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textMuted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 96)
            .subpageCard(cornerRadius: 18, shadowOpacity: 0.04)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surfaceLight, AppColors.surface],
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
            } else if let screenshotData = SaveStateStorage.shared.latestScreenshot(for: entry.checksum ?? ""),
                      let uiImage = UIImage(data: screenshotData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.textMuted)
            }
#else
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 24))
                .foregroundColor(AppColors.textMuted)
#endif
        }
        .clipped()
    }

    private var metaLine: String {
        let timePart: String = {
            guard let date = entry.lastPlayedAt else {
                return L10n.string("common.never", table: "Screens")
            }
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: date, relativeTo: Date())
        }()

        if entry.playtimeTotal <= 0 {
            return L10n.format("recent.opened_format", timePart.lowercased(), table: "Screens", languageManager: languageManager)
        }
        let duration = LocaleFormatting.shortDuration(
            seconds: Int(entry.playtimeTotal),
            minimumMinutes: 1,
            languageManager: languageManager
        )
        if Int(entry.playtimeTotal) >= 3600 {
            return L10n.format("common.total_hours_format", timePart, duration, table: "Screens", languageManager: languageManager)
        }
        return L10n.format("common.total_minutes_format", timePart, duration, table: "Screens", languageManager: languageManager)
    }
}

private struct RecentDeleteCandidate: Identifiable {
    let id = UUID()
    let entry: ROMLibraryEntry
    let mode: GameDeletionMode
}

private enum RecentAlertState: Identifiable {
    case launchError(String)
    case confirmDelete(RecentDeleteCandidate)
    case confirmFinalDelete(RecentDeleteCandidate)

    var id: String {
        switch self {
        case .launchError(let message):
            return "error-\(message)"
        case .confirmDelete(let candidate):
            return "confirm-delete-\(candidate.id.uuidString)"
        case .confirmFinalDelete(let candidate):
            return "confirm-final-delete-\(candidate.id.uuidString)"
        }
    }
}

private enum RecentSortMode: CaseIterable {
    case recent
    case mostPlayed
    case alphabetical

    var title: String {
        switch self {
        case .recent: return L10n.string("common.sort_recent", table: "Screens")
        case .mostPlayed: return L10n.string("common.sort_most_played", table: "Screens")
        case .alphabetical: return L10n.string("common.sort_alphabetical", table: "Screens")
        }
    }

    var shortTitle: String {
        switch self {
        case .recent: return L10n.string("common.sort_recent", table: "Screens")
        case .mostPlayed: return L10n.string("common.sort_played_short", table: "Screens")
        case .alphabetical: return L10n.string("common.sort_a_to_z", table: "Screens")
        }
    }
}

#if DEBUG
struct RecentlyPlayedView_Previews: PreviewProvider {
    static var previews: some View {
        RecentlyPlayedView()
    }
}
#endif
