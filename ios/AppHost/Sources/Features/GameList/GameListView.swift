import SwiftUI
import CoreData
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

struct GameListView: View {
    private enum GameListSortOption: String, CaseIterable, Identifiable {
        case recent
        case alphabetical
        case mostPlayed

        var id: String { rawValue }

        var title: String {
            switch self {
            case .recent:
                L10n.string("common.sort_recent", table: "Screens")
            case .alphabetical:
                L10n.string("common.sort_a_to_z", table: "Screens")
            case .mostPlayed:
                L10n.string("common.sort_most_played", table: "Screens")
            }
        }
    }

    let platform: EmulatorPlatform
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var viewModel = GameListViewModel()
    @StateObject private var performanceProfiler = PerformanceProfiler.shared
    @State private var searchText = ""
    @State private var selectedSort: GameListSortOption = .recent
    @State private var selectedGame: Game?
    @State private var showAllGames = false
    @State private var activeAlert: GameListAlertState?
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

    private var sortedFilteredGames: [Game] {
        let filtered = viewModel.filteredGames(searchText: searchText)
        switch selectedSort {
        case .recent:
            return filtered.sorted { ($0.lastPlayedDate ?? .distantPast) > ($1.lastPlayedDate ?? .distantPast) }
        case .alphabetical:
            return filtered.sorted { ($0.title ?? "").localizedCaseInsensitiveCompare($1.title ?? "") == .orderedAscending }
        case .mostPlayed:
            return filtered.sorted { $0.totalPlayTime > $1.totalPlayTime }
        }
    }

    private var collectorGridColumns: [GridItem] {
        #if os(iOS)
        let width = UIScreen.main.bounds.width
        let columnCount = width >= 1200 ? 4 : 3
        #else
        let columnCount = 4
        #endif
        return Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 20, alignment: .top), count: columnCount)
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
                    VStack(spacing: 16) {
                        if isCollectorMode {
                            collectorModeContent
                        } else {
                            systemIdentitySection
                            continuePlayingSection
                            consoleStatsSection
                            achievementsSection
                            mostPlayedSection
                            recentlyAddedSection
                            allGamesExpandableSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: isCollectorMode)
        .alert(item: $activeAlert) { state in
            switch state.kind {
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
                        activeAlert = GameListAlertState(kind: .confirmFinalDelete(candidate))
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
        #if os(iOS)
        .fullScreenCover(item: $selectedGame) { game in
            GamePlayView(game: game, onExit: {
                selectedGame = nil
            })
            .swipeBack {
                selectedGame = nil
            }
        }
        .sheet(item: $detailEntry) { entry in
            NavigationStack {
                RomDetailView(rom: entry) {
                    detailEntry = nil
                }
            }
        }
        #else
        .sheet(item: $selectedGame) { game in
            GameDetailView(game: game)
        }
        #endif
        .onAppear {
            viewModel.loadGames(for: platform, in: viewContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .romLibraryDidChange)) { _ in
            viewModel.loadGames(for: platform, in: viewContext)
        }
    }
    
    private var backgroundLayer: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.18), AppColors.accent.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: heavyUIEffectsEnabled ? 120 : 36)
                .frame(width: 360, height: 360)
                .offset(x: 140, y: -210)

            if heavyUIEffectsEnabled {
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
                    .offset(x: -170, y: 320)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: isCollectorMode ? RMSpacing.sm : RMSpacing.md) {
            HStack(spacing: 12) {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.Text.primary)
                        .frame(width: 36, height: 36)
                        .background(AppColors.Surface.cardElevated)
                        .overlay(Circle().stroke(AppColors.Border.subtle, lineWidth: 1))
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(platformDisplay.displayName)
                        .font(isCollectorMode ? .system(size: 20, weight: .bold) : SubpageUI.Font.title)
                        .foregroundColor(AppColors.Text.primary)
                    Text(L10n.format("common.games_count", Int64(sortedFilteredGames.count), table: "Screens", languageManager: languageManager))
                        .font(SubpageUI.Font.subtitle)
                        .foregroundColor(isCollectorMode ? AppColors.Text.secondary : AppColors.Text.accent)
                }

                Spacer()

                if platformDisplay.consoleAssetName != nil {
                    RMIconBadge(
                        systemName: nil,
                        assetName: platformDisplay.consoleAssetName,
                        size: 36,
                        shape: .roundedRect,
                        accent: true,
                        imageInset: 4
                    )
                } else {
                    RMIconBadge(
                        systemName: nil,
                        assetName: nil,
                        emoji: platformDisplay.emoji,
                        size: 36,
                        shape: .roundedRect,
                        accent: false,
                        imageInset: 4
                    )
                }
            }

            HStack(spacing: RMSpacing.sm) {
                HStack(spacing: RMSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(AppColors.textMuted)

                    TextField(L10n.string("gamelist.search_placeholder", table: "Screens", languageManager: languageManager), text: $searchText)
#if os(iOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
#endif
                        .foregroundColor(AppColors.textPrimary)
                }
                .subpageSearchField(cornerRadius: 19, height: 38)

                Menu {
                    ForEach(GameListSortOption.allCases) { option in
                        Button {
                            selectedSort = option
                        } label: {
                            HStack {
                                Text(option.title)
                                if selectedSort == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(L10n.string("gamelist.sort", table: "Screens", languageManager: languageManager))
                            .font(.system(size: 12, weight: .semibold))
                        Text(selectedSort.title)
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: 38)
                    .background(AppColors.Surface.cardElevated)
                    .overlay(
                        Capsule().stroke(AppColors.Border.subtle, lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, RMSpacing.lg)
        .padding(.vertical, RMSpacing.md)
        .background(AppColors.Background.appPrimary.opacity(0.88))
        .overlay(
            Rectangle()
                .fill(AppColors.Border.softDivider)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private var systemIdentitySection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.Surface.cardPrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppColors.Surface.accentTint.opacity(0.35))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColors.Border.subtle, lineWidth: 1)
                )
                .shadow(color: AppColors.Shadow.card, radius: 16, x: 0, y: 10)
                .overlay(alignment: .topLeading) {
                    Capsule()
                        .fill(AppColors.primary.opacity(0.42))
                        .frame(width: 52, height: 3)
                        .padding(.leading, 16)
                        .padding(.top, 14)
                }

            VStack(alignment: .leading, spacing: RMSpacing.lg) {
                HStack {
                    HStack(spacing: 8) {
                        RMIconBadge(
                            systemName: "gamecontroller.fill",
                            assetName: nil,
                            size: 28,
                            shape: .roundedRect,
                            accent: true,
                            imageInset: 6
                        )
                        Text(L10n.string("gamelist.quick_stats", table: "Screens", languageManager: languageManager))
                            .font(RMTypeScale.cardTitle)
                            .foregroundColor(AppColors.Text.primary)
                    }
                    Spacer()
                    RMChip(title: platformDisplay.shortName, selected: true, style: .compact)
                }

                HStack(spacing: 16) {
                    platformIcon

                    VStack(alignment: .leading, spacing: 6) {
                        Text(platformDisplay.displayName)
                            .font(RMTypeScale.sectionTitle)
                            .foregroundColor(AppColors.Text.primary)
                        Text(identitySubtitle)
                            .font(RMTypeScale.meta)
                            .foregroundColor(AppColors.Text.secondary)
                            .lineLimit(2)
                    }
                }

                HStack(spacing: RMSpacing.md) {
                    StatBadge(value: "\(viewModel.totalGames)", label: L10n.string("gamelist.stats.games", table: "Screens", languageManager: languageManager))
                    StatBadge(value: "\(viewModel.playedGames)", label: L10n.string("gamelist.stats.played", table: "Screens", languageManager: languageManager))
                    StatBadge(value: "\(viewModel.favoriteGames)", label: L10n.string("gamelist.stats.favorites", table: "Screens", languageManager: languageManager))
                }
            }
            .padding(16)
        }
    }

    private var continuePlayingSection: some View {
        Group {
            if !viewModel.continueGames.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(L10n.format("gamelist.continue_on", platformDisplay.shortName, table: "Screens", languageManager: languageManager), trailing: nil)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.continueGames.prefix(3)) { game in
                                Button {
                                    launchGame(game)
                                } label: {
                                    SystemHubGameCard(
                                        game: game,
                                        platformText: platformDisplay.shortName,
                                        subtitle: recentSubtitle(for: game),
                                        launchIssue: viewModel.compatibilityIssue(for: game),
                                        variant: .continuePlaying
                                    )
                                    .frame(width: 182)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { deletionMenu(for: game) }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
        }
    }

    private var consoleStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(L10n.string("gamelist.your_stats", table: "Screens", languageManager: languageManager), trailing: nil)

            VStack(spacing: RMSpacing.md) {
                ConsoleStatRow(label: L10n.string("gamelist.total_hours", table: "Screens", languageManager: languageManager), value: formatHoursShort(viewModel.totalPlayTimeSeconds))
                ConsoleStatRow(label: L10n.string("gamelist.sessions", table: "Screens", languageManager: languageManager), value: "\(viewModel.estimatedSessionCount)")
                ConsoleStatRow(label: L10n.string("gamelist.avg_session", table: "Screens", languageManager: languageManager), value: formatMinutesShort(viewModel.averageSessionLengthEstimate))
                ConsoleStatRow(
                    label: L10n.string("gamelist.most_played", table: "Screens", languageManager: languageManager),
                    value: viewModel.mostPlayedGameTitle.map { "\($0) · \(formatHoursShort(viewModel.mostPlayedGameSeconds))" } ?? "—"
                )
            }
            .padding(14)
            .subpageCard(cornerRadius: 16, shadowOpacity: 0.05)
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                L10n.string("gamelist.achievements", table: "Screens", languageManager: languageManager),
                trailing: viewModel.achievements.count > 4 ? L10n.string("home.view_all", languageManager: languageManager) : nil
            )

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(Array(viewModel.achievements.prefix(4))) { achievement in
                    AchievementBadgeCard(achievement: achievement)
                }
            }
        }
    }

    private var mostPlayedSection: some View {
        Group {
            if !viewModel.topPlayedGames.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(L10n.string("gamelist.most_played_section", table: "Screens", languageManager: languageManager), trailing: nil)

                    VStack(spacing: 10) {
                        ForEach(Array(viewModel.topPlayedGames.prefix(3).enumerated()), id: \.element.id) { idx, game in
                            MostPlayedBarRow(
                                rank: idx + 1,
                                title: GameCardTitleFormatter.format(game.title, maxWords: 7),
                                seconds: game.totalPlayTime,
                                maxSeconds: max(viewModel.topPlayedGames.first?.totalPlayTime ?? 1, 1)
                            )
                        }
                    }
                    .padding(14)
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.surfaceLight.opacity(0.45), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    private var recentlyAddedSection: some View {
        Group {
            if !viewModel.recentlyAddedGames.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(L10n.string("gamelist.recently_added", table: "Screens", languageManager: languageManager), trailing: nil)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.recentlyAddedGames.prefix(3)) { game in
                                Button {
                                    launchGame(game)
                                } label: {
                                    SystemHubGameCard(
                                        game: game,
                                        platformText: platformDisplay.shortName,
                                        subtitle: L10n.string("gamelist.new_import", table: "Screens", languageManager: languageManager),
                                        launchIssue: viewModel.compatibilityIssue(for: game),
                                        variant: .recentlyAdded
                                    )
                                    .frame(width: 170)
                                }
                                .buttonStyle(.plain)
                                .contextMenu { deletionMenu(for: game) }
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
            }
        }
    }

    private var allGamesExpandableSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showAllGames.toggle()
                }
            } label: {
                HStack {
                    Text(
                        showAllGames
                            ? L10n.string("gamelist.hide_games", table: "Screens", languageManager: languageManager)
                            : L10n.format("gamelist.open_library", Int64(viewModel.totalGames), table: "Screens", languageManager: languageManager)
                    )
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Spacer()
                    Image(systemName: showAllGames ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)

            if showAllGames {
                gamesSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var collectorModeContent: some View {
        Group {
            if sortedFilteredGames.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: searchText.isEmpty ? "gamecontroller" : "magnifyingglass")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                    Text(
                        searchText.isEmpty
                            ? L10n.string("gamelist.no_games_yet", table: "Screens", languageManager: languageManager)
                            : L10n.string("common.no_matching_games", table: "Screens", languageManager: languageManager)
                    )
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
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
                .padding(.vertical, 40)
                .subpageCard(cornerRadius: 16, shadowOpacity: 0.02)
            } else {
                LazyVGrid(columns: collectorGridColumns, spacing: 16) {
                    ForEach(sortedFilteredGames) { game in
                        Button {
                            launchGame(game)
                        } label: {
                            SystemCollectorCard(
                                game: game,
                                platformText: platformDisplay.shortName,
                                subtitle: recentSubtitle(for: game),
                                launchIssue: viewModel.compatibilityIssue(for: game)
                            )
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .buttonStyle(CollectorCardPressStyle())
                        .contextMenu { deletionMenu(for: game) }
                    }
                }
                .transaction { transaction in
                    transaction.animation = nil
                }
            }
        }
    }

    private var platformIcon: some View {
        RMIconBadge(
            systemName: platformDisplay.consoleAssetName == nil ? platform.iconName : nil,
            assetName: platformDisplay.consoleAssetName,
            emoji: platformDisplay.consoleAssetName == nil ? platformDisplay.emoji : nil,
            size: 64,
            shape: .roundedRect,
            accent: true,
            imageInset: 5
        )
    }
    
    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.string("gamelist.game_library", table: "Screens", languageManager: languageManager))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(selectedSort.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textMuted)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(AppColors.surfaceLight.opacity(0.42))
                    .clipShape(Capsule())
            }

            let games = sortedFilteredGames

            if games.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                    Text(
                        searchText.isEmpty
                            ? L10n.string("gamelist.no_games_available", table: "Screens", languageManager: languageManager)
                            : L10n.string("common.no_matching_games", table: "Screens", languageManager: languageManager)
                    )
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    if !searchText.isEmpty {
                        Text(L10n.string("common.try_different_search", table: "Screens", languageManager: languageManager))
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textMuted)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .subpageCard(cornerRadius: 16, shadowOpacity: 0.04)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(games) { game in
                        Button {
                            launchGame(game)
                        } label: {
                            GameCardRow(game: game, launchIssue: viewModel.compatibilityIssue(for: game))
                        }
                        .buttonStyle(.plain)
                        .contextMenu { deletionMenu(for: game) }
                    }
                }
            }
        }
    }

    private var identitySubtitle: String {
        let gameCount = viewModel.totalGames
        let hoursText = formatHoursShort(viewModel.totalPlayTimeSeconds)
        if let firstDate = viewModel.firstConsoleDate {
            return L10n.format(
                "gamelist.identity_with_since",
                Int64(gameCount),
                hoursText,
                firstDate.formatted(date: .abbreviated, time: .omitted),
                table: "Screens",
                languageManager: languageManager
            )
        }
        return L10n.format("gamelist.identity_no_since", Int64(gameCount), hoursText, table: "Screens", languageManager: languageManager)
    }

    private func sectionHeader(_ title: String, trailing: String?) -> some View {
        SubpageSectionHeader(title, trailing: trailing)
    }

    private func recentSubtitle(for game: Game) -> String {
        var pieces: [String] = []
        if let lastPlayed = game.lastPlayedDate {
            pieces.append(relativeDateString(lastPlayed))
        }
        if game.totalPlayTime > 0 {
            pieces.append(formatHoursShort(game.totalPlayTime))
        }
        return pieces.isEmpty ? L10n.string("common.ready_to_play", table: "Screens", languageManager: languageManager) : pieces.joined(separator: " • ")
    }

    private func relativeDateString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatHoursShort(_ seconds: Int) -> String {
        LocaleFormatting.shortDuration(seconds: seconds, languageManager: languageManager)
    }

    private func formatMinutesShort(_ seconds: Int) -> String {
        LocaleFormatting.shortDuration(seconds: seconds, languageManager: languageManager)
    }

    private var platformDisplay: PlatformDisplay {
        PlatformDisplay(platform: platform)
    }

    private func launchGame(_ game: Game) {
        guard let romPath = game.romPath, !romPath.isEmpty else {
            presentLaunchError(L10n.string("gamelist.error.rom_missing", table: "Screens", languageManager: languageManager))
            return
        }
        guard FileManager.default.fileExists(atPath: romPath) else {
            presentLaunchError(L10n.string("gamelist.error.rom_not_found", table: "Screens", languageManager: languageManager))
            return
        }
        guard game.gamePlatform != nil else {
            presentLaunchError(L10n.string("gamelist.error.unsupported_platform", table: "Screens", languageManager: languageManager))
            return
        }
        if let issue = viewModel.compatibilityIssue(for: game) {
            presentLaunchError(issue.message)
            return
        }
        selectedGame = game
    }

    @ViewBuilder
    private func deletionMenu(for game: Game) -> some View {
        if let entry = viewModel.entry(for: game.id) {
            Button {
                beginRename(entry)
            } label: {
                Label(L10n.string("home.context.rename", languageManager: languageManager), systemImage: "pencil")
            }

            Button {
                showDetails(entry)
            } label: {
                Label(L10n.string("home.context.details", languageManager: languageManager), systemImage: "info.circle")
            }

            Button(role: .destructive) {
                activeAlert = GameListAlertState(kind: .confirmDelete(GameDeleteCandidate(entry: entry, mode: .removeROMOnly)))
            } label: {
                Label(L10n.string("home.context.remove_rom_only", languageManager: languageManager), systemImage: "eject")
            }

            Button(role: .destructive) {
                activeAlert = GameListAlertState(kind: .confirmDelete(GameDeleteCandidate(entry: entry, mode: .removeAll)))
            } label: {
                Label(L10n.string("home.context.remove", languageManager: languageManager), systemImage: "trash")
            }
        }
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
            viewModel.loadGames(for: platform, in: viewContext)
        } catch {
            presentLaunchError(L10n.format("gamelist.error.rename_failed", error.localizedDescription, table: "Screens", languageManager: languageManager))
        }
    }

    private func showDetails(_ entry: ROMLibraryEntry) {
        detailEntry = entry
    }

    private func performDeletion(_ candidate: GameDeleteCandidate) {
        do {
            try GameDeletionService.shared.delete(entry: candidate.entry, mode: candidate.mode, in: viewContext)
            if selectedGame?.id == candidate.entry.id {
                selectedGame = nil
            }
            viewModel.loadGames(for: platform, in: viewContext)
        } catch {
            presentLaunchError(L10n.format("gamelist.error.delete_failed", error.localizedDescription, table: "Screens", languageManager: languageManager))
        }
    }

    private func presentLaunchError(_ message: String) {
        activeAlert = GameListAlertState(kind: .launchError(message))
    }
}

private struct PlatformDisplay {
    let displayName: String
    let shortName: String
    let emoji: String
    let consoleAssetName: String?

    init(platform: EmulatorPlatform) {
        if let console = ConsoleIdentity.resolve(platform: platform) {
            displayName = console.displayName
            shortName = console.shortName
            consoleAssetName = console.assetName
            switch console {
            case .gb: emoji = "🎮"
            case .gbc: emoji = "🌈"
            case .gba: emoji = "⚡"
            case .nds: emoji = "📱"
            }
        } else {
            switch platform {
            case .playStation1:
                displayName = platform.displayName
                shortName = platform.shortName
                emoji = "💿"
                consoleAssetName = nil
            case .nintendo3DS:
                displayName = platform.displayName
                shortName = platform.shortName
                emoji = "🔺"
                consoleAssetName = nil
            case .psp:
                displayName = platform.displayName
                shortName = platform.shortName
                emoji = "🎯"
                consoleAssetName = nil
            case .gameBoy, .gameBoyColor, .gameBoyAdvance, .nintendoDS:
                displayName = platform.displayName
                shortName = platform.shortName
                emoji = "🎮"
                consoleAssetName = nil
            }
        }
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(AppColors.Text.primary)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(AppColors.Text.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppColors.Surface.cardElevated)
        .overlay(
            RoundedRectangle(cornerRadius: RMRadius.chip)
                .stroke(AppColors.Border.subtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: RMRadius.chip))
    }
}

private struct ConsoleStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textMuted)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.trailing)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

fileprivate struct ConsoleHubAchievement: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let isUnlocked: Bool
    let iconName: String
}

private struct AchievementBadgeCard: View {
    let achievement: ConsoleHubAchievement

    var body: some View {
        HStack(spacing: 10) {
            RMIconBadge(
                systemName: achievement.iconName,
                assetName: nil,
                size: 34,
                shape: .roundedRect,
                accent: achievement.isUnlocked,
                imageInset: 6
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(achievement.subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(achievement.isUnlocked ? AppColors.primary : AppColors.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(AppColors.Surface.cardPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(achievement.isUnlocked ? AppColors.Border.active : AppColors.Border.subtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct MostPlayedBarRow: View {
    let rank: Int
    let title: String
    let seconds: Int
    let maxSeconds: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text("#\(rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(rank == 1 ? AppColors.primary : AppColors.textSecondary)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(Self.format(seconds: seconds))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.textMuted)
            }
            GeometryReader { proxy in
                let pct = max(0.06, min(1.0, Double(seconds) / Double(max(maxSeconds, 1))))
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.surfaceLight.opacity(0.35))
                    Capsule().fill(AppColors.primary.opacity(0.8))
                        .frame(width: proxy.size.width * pct)
                }
            }
            .frame(height: 6)
        }
    }

    private static func format(seconds: Int) -> String {
        LocaleFormatting.shortDuration(seconds: seconds)
    }
}

private enum SystemHubGameCardVariant {
    case continuePlaying
    case recentlyAdded
}

private struct SystemHubGameCard: View {
    let game: Game
    let platformText: String
    let subtitle: String
    let launchIssue: ROMLaunchIssue?
    let variant: SystemHubGameCardVariant

    private var coverHeight: CGFloat {
        switch variant {
        case .continuePlaying: return 110
        case .recentlyAdded: return 96
        }
    }

    private var cardHeight: CGFloat {
        switch variant {
        case .continuePlaying: return 196
        case .recentlyAdded: return 182
        }
    }

    private var titleHeight: CGFloat {
        switch variant {
        case .continuePlaying: return 44
        case .recentlyAdded: return 36
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                coverView
                    .frame(maxWidth: .infinity)
                    .frame(height: coverHeight)
                    .clipped()

                RMOverlayBadge(
                    title: platformText,
                    backgroundColor: CollectorPlatformStyle(systemTag: platformText).badgeColor
                )
                .padding(RMSpacing.sm)

                if let launchIssue {
                    VStack {
                        HStack {
                            Image(systemName: launchIssue.iconName)
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
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 4) {
                Text(GameCardTitleFormatter.format(game.title, maxWords: 7))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: titleHeight, maxHeight: titleHeight, alignment: .topLeading)
                    .multilineTextAlignment(.leading)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, minHeight: 16, maxHeight: 16, alignment: .leading)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: cardHeight - coverHeight, maxHeight: cardHeight - coverHeight, alignment: .topLeading)
            .background(AppColors.surface)
        }
        .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight, alignment: .topLeading)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.surfaceLight.opacity(0.45), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var coverView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surfaceLight.opacity(0.55), AppColors.surface.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            #if canImport(AppKit)
            if let data = game.coverImage, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.22)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
            } else {
                placeholder
            }
            #elseif canImport(UIKit)
            if let data = game.coverImage, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .overlay(
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.22)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
            } else {
                placeholder
            }
            #else
            placeholder
            #endif
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.surfaceLight.opacity(0.25))
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColors.primary.opacity(0.75))
        }
    }
}

private struct SystemCollectorCard: View {
    let game: Game
    let platformText: String
    let subtitle: String
    let launchIssue: ROMLaunchIssue?

    var body: some View {
        CollectorGameCard(
            variant: .standard,
            title: GameCardTitleFormatter.format(game.title, maxWords: 7),
            metadataPrimary: subtitle,
            metadataSecondary: nil,
            platformTag: platformText,
            launchIssueIconName: launchIssue?.iconName,
            progress: nil
        ) {
            coverView
        }
    }

    @ViewBuilder
    private var coverView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(SubpageUI.CollectorIdentity.placeholderGradient(forSystem: platformText))

#if canImport(AppKit)
            if let data = game.coverImage, let img = NSImage(data: data) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
#elseif canImport(UIKit)
            if let data = game.coverImage, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
#else
            placeholder
#endif
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(SubpageUI.CollectorIdentity.placeholderGradient(forSystem: platformText))
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppColors.textMuted)
        }
    }
}

struct GameCardRow: View {
    let game: Game
    let launchIssue: ROMLaunchIssue?
    
    var body: some View {
        HStack(spacing: 12) {
            gameCover

            VStack(alignment: .leading, spacing: 6) {
                Text(GameCardTitleFormatter.format(game.title, maxWords: 7))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                if launchIssue != nil {
                    Label(L10n.string("common.unsupported_mapper", table: "Screens"), systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.orange)
                }

                HStack(spacing: 8) {
                    if game.totalPlayTime > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10))
                            Text(formatPlayTime(game.totalPlayTime))
                                .font(.system(size: 11))
                        }
                        .foregroundColor(AppColors.textSecondary)
                    }

                    if let lastPlayed = game.lastPlayedDate {
                        Text(formatDate(lastPlayed))
                            .font(.system(size: 10))
                            .foregroundColor(AppColors.textMuted)
                    }
                }
            }

            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(AppColors.surfaceLight.opacity(0.38))
                    .frame(width: 32, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1))
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.primary)
                    .offset(x: 1)
            }
        }
        .padding(12)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: AppColors.primary.opacity(0.05), radius: 8, x: 0, y: 4)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private var gameCover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surfaceLight, AppColors.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 64, height: 64)
            
            gameCoverImage
        }
    }
    
    @ViewBuilder
    private var gameCoverImage: some View {
        #if canImport(AppKit)
        if let coverData = game.coverImage, let nsImage = NSImage(data: coverData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            placeholderGlyph
        }
        #elseif canImport(UIKit)
        if let coverData = game.coverImage, let uiImage = UIImage(data: coverData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            placeholderGlyph
        }
        #else
        placeholderGlyph
        #endif
    }

    private var placeholderGlyph: some View {
        ZStack {
            // Console-based background
            RoundedRectangle(cornerRadius: 14)
                .fill(consolePlaceholderColor)
            
            // Subtle pattern
            consolePlaceholderPattern
                .opacity(0.08)
            
            // Monogram letter
            Text(String(game.title?.prefix(1) ?? "?").uppercased())
                .font(.system(size: 48, weight: .heavy))
                .foregroundColor(.white.opacity(0.22))
            
            // Inner border
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
    
    private var consolePlaceholderColor: some ShapeStyle {
        game.consoleIdentity?.accentColor ?? Color(hue: 0.75, saturation: 0.20, brightness: 0.80)
    }
    
    @ViewBuilder
    private var consolePlaceholderPattern: some View {
        switch game.emulatorPlatform {
        case .gameBoy, .gameBoyColor:
            PixelGridPattern()
        case .gameBoyAdvance:
            DiagonalPattern()
        case .nintendoDS:
            RectangleOutlinePattern()
        default:
            EmptyView()
        }
    }
    
    private func formatPlayTime(_ seconds: Int) -> String {
        LocaleFormatting.shortDuration(seconds: seconds, minimumMinutes: 1)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

@MainActor
class GameListViewModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var isLoading = false
    @Published var continueGames: [Game] = []
    @Published var topPlayedGames: [Game] = []
    @Published var recentlyAddedGames: [Game] = []
    @Published var firstConsoleDate: Date?
    @Published var totalPlayTimeSeconds: Int = 0
    @Published var estimatedSessionCount: Int = 0
    @Published var averageSessionLengthEstimate: Int = 0
    @Published var longestSessionEstimate: Int = 0
    @Published var mostPlayedGameTitle: String?
    @Published var mostPlayedGameSeconds: Int = 0
    @Published fileprivate var achievements: [ConsoleHubAchievement] = []
    private var entryByGameID: [UUID: ROMLibraryEntry] = [:]
    private var compatibilityByGameID: [UUID: ROMLaunchCompatibility] = [:]
    
    var totalGames: Int { games.count }
    var playedGames: Int { games.filter { $0.totalPlayTime > 0 }.count }
    var favoriteGames: Int { games.filter { $0.isFavorite }.count }
    
    func loadGames(for platform: EmulatorPlatform, in context: NSManagedObjectContext) {
        isLoading = true

        let request: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ROMLibraryEntry.lastPlayedAt, ascending: false),
            NSSortDescriptor(keyPath: \ROMLibraryEntry.dateAdded, ascending: false)
        ]

        switch platform {
        case .gameBoy:
            request.predicate = NSPredicate(format: "system == %@", "gb")
        case .gameBoyColor:
            request.predicate = NSPredicate(format: "system == %@", "gbc")
        case .gameBoyAdvance:
            request.predicate = NSPredicate(format: "system == %@", "gba")
        case .nintendoDS:
            request.predicate = NSPredicate(format: "system == %@", "nds")
        default:
            request.predicate = NSPredicate(format: "system == %@", platform.shortName.lowercased())
        }

        do {
            let entries = try context.fetch(request)
            let mappedGames = entries.compactMap { $0.toGame() }
            games = mappedGames
            entryByGameID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
            compatibilityByGameID = Dictionary(uniqueKeysWithValues: mappedGames.map { game in
                if let entry = entryByGameID[game.id] {
                    return (game.id, ROMCompatibilityService.shared.compatibility(for: entry))
                }
                return (game.id, .compatible)
            })
            deriveConsoleHubState(from: entries, mappedGames: mappedGames)
        } catch {
            print("Failed to load games for \(platform.displayName): \(error)")
            games = []
            entryByGameID = [:]
            compatibilityByGameID = [:]
            deriveConsoleHubState(from: [], mappedGames: [])
        }

        isLoading = false
    }
    
    func filteredGames(searchText: String) -> [Game] {
        if searchText.isEmpty {
            return games
        }
        return games.filter { ($0.title ?? "").localizedCaseInsensitiveContains(searchText) }
    }

    func entry(for gameID: UUID) -> ROMLibraryEntry? {
        entryByGameID[gameID]
    }

    func compatibilityIssue(for game: Game) -> ROMLaunchIssue? {
        compatibilityByGameID[game.id]?.issue
    }

    private func deriveConsoleHubState(from entries: [ROMLibraryEntry], mappedGames: [Game]) {
        let entryById: [UUID: ROMLibraryEntry] = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })

        firstConsoleDate = entries.compactMap(\.dateAdded).min()
        totalPlayTimeSeconds = Int(entries.reduce(Int64(0)) { $0 + $1.playtimeTotal })

        let playedEntries = entries.filter { $0.playtimeTotal > 0 || $0.lastPlayedAt != nil }
        let uniquePlayedGames = Set(playedEntries.compactMap { $0.checksum })
        estimatedSessionCount = max(playedEntries.filter { $0.lastPlayedAt != nil }.count, totalPlayTimeSeconds > 0 ? max(1, totalPlayTimeSeconds / (35 * 60)) : 0)
        averageSessionLengthEstimate = estimatedSessionCount > 0 ? (totalPlayTimeSeconds / estimatedSessionCount) : 0
        let maxGameTime = playedEntries.map { Int($0.playtimeTotal) }.max() ?? 0
        longestSessionEstimate = max(averageSessionLengthEstimate * 2, maxGameTime / 2)

        continueGames = mappedGames
            .filter { $0.lastPlayedDate != nil || $0.totalPlayTime > 0 }
            .sorted {
                ($0.lastPlayedDate ?? .distantPast) > ($1.lastPlayedDate ?? .distantPast)
            }

        topPlayedGames = mappedGames
            .filter { $0.totalPlayTime > 0 }
            .sorted { $0.totalPlayTime > $1.totalPlayTime }

        if let top = topPlayedGames.first {
            mostPlayedGameTitle = top.title ?? L10n.string("common.unknown_game", table: "Screens")
            mostPlayedGameSeconds = top.totalPlayTime
        } else {
            mostPlayedGameTitle = nil
            mostPlayedGameSeconds = 0
        }

        let now = Date()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        let recentEntryIDs = Set(
            entries
                .filter { ($0.dateAdded ?? .distantPast) >= sevenDaysAgo }
                .map { $0.id }
        )

        let fallbackRecent = entries
            .sorted {
                ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast)
            }
            .prefix(3)
            .map { $0.id }
        let chosenRecentIDs = recentEntryIDs.isEmpty ? Set(fallbackRecent) : recentEntryIDs
        recentlyAddedGames = mappedGames.filter { game in
            chosenRecentIDs.contains(game.id)
        }
        .sorted {
            let lhs = entryById[$0.id]
            let rhs = entryById[$1.id]
            return (lhs?.dateAdded ?? .distantPast) > (rhs?.dateAdded ?? .distantPast)
        }

        let saveStateCountEstimate = entries.filter { ($0.lastPlayedAt != nil) || $0.playtimeTotal > 0 }.count * 2
        achievements = [
            ConsoleHubAchievement(
                id: "first-hour",
                title: L10n.string("gamelist.achievement.first_hour.title", table: "Screens"),
                subtitle: totalPlayTimeSeconds >= 3600
                    ? L10n.string("gamelist.achievement.unlocked", table: "Screens")
                    : L10n.string("gamelist.achievement.first_hour.locked", table: "Screens"),
                isUnlocked: totalPlayTimeSeconds >= 3600,
                iconName: "clock.fill"
            ),
            ConsoleHubAchievement(
                id: "ten-hours",
                title: L10n.string("gamelist.achievement.ten_hours.title", table: "Screens"),
                subtitle: totalPlayTimeSeconds >= 36_000
                    ? L10n.string("gamelist.achievement.unlocked", table: "Screens")
                    : L10n.string("gamelist.achievement.ten_hours.locked", table: "Screens"),
                isUnlocked: totalPlayTimeSeconds >= 36_000,
                iconName: "timer"
            ),
            ConsoleHubAchievement(
                id: "five-games",
                title: L10n.string("gamelist.achievement.five_games.title", table: "Screens"),
                subtitle: uniquePlayedGames.count >= 5
                    ? L10n.string("gamelist.achievement.unlocked", table: "Screens")
                    : "\(uniquePlayedGames.count)/5",
                isUnlocked: uniquePlayedGames.count >= 5,
                iconName: "square.grid.2x2.fill"
            ),
            ConsoleHubAchievement(
                id: "save-master",
                title: L10n.string("gamelist.achievement.save_master.title", table: "Screens"),
                subtitle: saveStateCountEstimate >= 10
                    ? L10n.string("gamelist.achievement.unlocked", table: "Screens")
                    : L10n.string("gamelist.achievement.save_master.locked", table: "Screens"),
                isUnlocked: saveStateCountEstimate >= 10,
                iconName: "externaldrive.fill.badge.checkmark"
            )
        ]
    }
}

private struct GameDeleteCandidate: Identifiable {
    let id = UUID()
    let entry: ROMLibraryEntry
    let mode: GameDeletionMode
}

private struct GameListAlertState: Identifiable {
    enum Kind {
        case launchError(String)
        case confirmDelete(GameDeleteCandidate)
        case confirmFinalDelete(GameDeleteCandidate)
    }

    let id = UUID()
    let kind: Kind
}

#Preview {
    GameListView(platform: .gameBoyAdvance)
}
