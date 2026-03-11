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
        case recent = "Recent"
        case alphabetical = "A-Z"
        case mostPlayed = "Most Played"

        var id: String { rawValue }
    }

    let platform: EmulatorPlatform
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
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
                    title: Text("Unable to Open Game"),
                    message: Text(message),
                    dismissButton: .cancel(Text("OK"))
                )
            case .confirmDelete(let candidate):
                return Alert(
                    title: Text(candidate.mode.displayName),
                    message: Text(candidate.mode.firstConfirmation),
                    primaryButton: .default(Text("Continue")) {
                        activeAlert = GameListAlertState(kind: .confirmFinalDelete(candidate))
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
        VStack(spacing: isCollectorMode ? 8 : 10) {
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
                    Text(platformDisplay.displayName)
                        .font(isCollectorMode ? .system(size: 20, weight: .bold) : SubpageUI.Font.title)
                        .foregroundColor(AppColors.textPrimary)
                    Text("\(sortedFilteredGames.count) games")
                        .font(SubpageUI.Font.subtitle)
                        .foregroundColor(isCollectorMode ? AppColors.textSecondary : AppColors.primary)
                }

                Spacer()

                if let assetName = platformDisplay.consoleAssetName {
                    Image(assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Text(platformDisplay.emoji)
                        .font(.system(size: 28))
                }
            }

            HStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textMuted)

                    TextField("Search games...", text: $searchText)
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
                                Text(option.rawValue)
                                if selectedSort == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(selectedSort.rawValue)
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .padding(.horizontal, 10)
                    .frame(height: 38)
                    .background(AppColors.surfaceLight.opacity(0.45))
                    .overlay(
                        Capsule().stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
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
    
    private var systemIdentitySection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(AppColors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(platform.gradient.opacity(0.035))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppColors.primary.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: AppColors.primary.opacity(0.12), radius: 16, x: 0, y: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.10), lineWidth: 0.7)
                )
                .overlay(alignment: .topLeading) {
                    Capsule()
                        .fill(AppColors.primary.opacity(0.28))
                        .frame(width: 52, height: 3)
                        .padding(.leading, 16)
                        .padding(.top, 14)
                }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "gamecontroller.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                        Text("Quick Stats")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    Spacer()
                    Text(platformDisplay.shortName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }

                HStack(spacing: 16) {
                    platformIcon

                    VStack(alignment: .leading, spacing: 4) {
                        Text(platformDisplay.displayName)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)
                        Text(identitySubtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                            .lineLimit(2)
                    }
                }

                HStack(spacing: 10) {
                    StatBadge(value: "\(viewModel.totalGames)", label: "Games")
                    StatBadge(value: "\(viewModel.playedGames)", label: "Played")
                    StatBadge(value: "\(viewModel.favoriteGames)", label: "Favorites")
                }
            }
            .padding(16)
        }
    }

    private var continuePlayingSection: some View {
        Group {
            if !viewModel.continueGames.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader("Continue on \(platformDisplay.shortName)", trailing: nil)

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
            sectionHeader("Your Stats", trailing: nil)

            VStack(spacing: 10) {
                ConsoleStatRow(label: "Total Hours", value: formatHoursShort(viewModel.totalPlayTimeSeconds))
                ConsoleStatRow(label: "Sessions", value: "\(viewModel.estimatedSessionCount)")
                ConsoleStatRow(label: "Avg Session", value: formatMinutesShort(viewModel.averageSessionLengthEstimate))
                ConsoleStatRow(
                    label: "Most Played",
                    value: viewModel.mostPlayedGameTitle.map { "\($0) · \(formatHoursShort(viewModel.mostPlayedGameSeconds))" } ?? "—"
                )
            }
            .padding(14)
            .subpageCard(cornerRadius: 16, shadowOpacity: 0.05)
        }
    }

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Achievements", trailing: viewModel.achievements.count > 4 ? "View All" : nil)

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
                    sectionHeader("Most Played", trailing: nil)

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
                    sectionHeader("Recently Added", trailing: nil)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(viewModel.recentlyAddedGames.prefix(3)) { game in
                                Button {
                                    launchGame(game)
                                } label: {
                                    SystemHubGameCard(
                                        game: game,
                                        platformText: platformDisplay.shortName,
                                        subtitle: "New import",
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
                    Text(showAllGames ? "Hide Games" : "Open Game Library (\(viewModel.totalGames))")
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
                    Text(searchText.isEmpty ? "No Games Yet" : "No Matching Games")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Text("Clear Search")
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
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(platform.gradient)
                .frame(width: 64, height: 64)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            if let assetName = platformDisplay.consoleAssetName {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Image(systemName: platform.iconName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
    
    private var gamesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Game Library")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                Text(selectedSort.rawValue)
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
                    Text(searchText.isEmpty ? "No games available" : "No matching games")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                    if !searchText.isEmpty {
                        Text("Try a different search term")
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
            return "\(gameCount) games · \(hoursText) played · Since \(firstDate.formatted(date: .abbreviated, time: .omitted))"
        }
        return "\(gameCount) games · \(hoursText) played"
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
        return pieces.isEmpty ? "Ready to play" : pieces.joined(separator: " • ")
    }

    private func relativeDateString(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatHoursShort(_ seconds: Int) -> String {
        let hours = max(0, seconds / 3600)
        let minutes = max(0, (seconds % 3600) / 60)
        if hours == 0 { return "\(minutes)m" }
        return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
    }

    private func formatMinutesShort(_ seconds: Int) -> String {
        let minutes = max(0, seconds / 60)
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }

    private var platformDisplay: PlatformDisplay {
        PlatformDisplay(platform: platform)
    }

    private func launchGame(_ game: Game) {
        guard let romPath = game.romPath, !romPath.isEmpty else {
            presentLaunchError("ROM file path is missing for this game.")
            return
        }
        guard FileManager.default.fileExists(atPath: romPath) else {
            presentLaunchError("ROM file could not be found. Try re-importing the game.")
            return
        }
        guard game.gamePlatform != nil else {
            presentLaunchError("This game platform is not supported for direct launch.")
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
                Label("Rename", systemImage: "pencil")
            }

            Button {
                showDetails(entry)
            } label: {
                Label("Details", systemImage: "info.circle")
            }

            Button(role: .destructive) {
                activeAlert = GameListAlertState(kind: .confirmDelete(GameDeleteCandidate(entry: entry, mode: .removeROMOnly)))
            } label: {
                Label("Remove ROM Only", systemImage: "eject")
            }

            Button(role: .destructive) {
                activeAlert = GameListAlertState(kind: .confirmDelete(GameDeleteCandidate(entry: entry, mode: .removeAll)))
            } label: {
                Label("Remove", systemImage: "trash")
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
            presentLaunchError("Could not rename game: \(error.localizedDescription)")
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
            presentLaunchError("Could not delete game: \(error.localizedDescription)")
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
        switch platform {
        case .gameBoy:
            displayName = "Game Boy + Color"
            shortName = "GB/GBC"
            emoji = "🎮"
            consoleAssetName = "ConsoleGBGBC"
        case .gameBoyColor:
            displayName = "Game Boy + Color"
            shortName = "GB/GBC"
            emoji = "🎮"
            consoleAssetName = "ConsoleGBGBC"
        case .gameBoyAdvance:
            displayName = "Game Boy Advance"
            shortName = "GBA"
            emoji = "⚡"
            consoleAssetName = "ConsoleGBA"
        case .nintendoDS:
            displayName = "Nintendo DS"
            shortName = "NDS"
            emoji = "📱"
            consoleAssetName = "ConsoleNDS"
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
        }
    }
}

struct StatBadge: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
                Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(AppColors.primary.opacity(0.9))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AppColors.background.opacity(0.35))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.surfaceLight.opacity(0.45), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill((achievement.isUnlocked ? AppColors.primary : AppColors.surfaceLight).opacity(achievement.isUnlocked ? 0.16 : 0.35))
                    .frame(width: 34, height: 34)
                Image(systemName: achievement.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(achievement.isUnlocked ? AppColors.primary : AppColors.textMuted.opacity(0.7))
            }

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
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke((achievement.isUnlocked ? AppColors.primary : AppColors.surfaceLight).opacity(achievement.isUnlocked ? 0.22 : 0.45), lineWidth: 1)
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
                Text("\(rank).")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.primary)
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
        let h = max(0, seconds / 3600)
        let m = max(0, (seconds % 3600) / 60)
        if h == 0 { return "\(m)m" }
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
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

                Text(platformText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(AppColors.primary)
                    .clipShape(Capsule())
                    .padding(8)

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
                    Label("Unsupported Mapper", systemImage: "exclamationmark.triangle.fill")
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
        switch game.emulatorPlatform {
        case .gameBoy, .gameBoyColor:
            return Color(hue: 0.45, saturation: 0.18, brightness: 0.88)  // Mint/teal
        case .gameBoyAdvance:
            return Color(hue: 0.72, saturation: 0.25, brightness: 0.75)  // Purple-blue
        case .nintendoDS:
            return Color(hue: 0.58, saturation: 0.12, brightness: 0.82)  // Gray-blue
        default:
            return Color(hue: 0.75, saturation: 0.20, brightness: 0.80)  // Soft purple
        }
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
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
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
            request.predicate = NSPredicate(format: "system IN %@", ["gb", "gbc"])
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
            mostPlayedGameTitle = top.title ?? "Unknown"
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
            ConsoleHubAchievement(id: "first-hour", title: "First Hour", subtitle: totalPlayTimeSeconds >= 3600 ? "Unlocked" : "1h total play", isUnlocked: totalPlayTimeSeconds >= 3600, iconName: "clock.fill"),
            ConsoleHubAchievement(id: "ten-hours", title: "10h Milestone", subtitle: totalPlayTimeSeconds >= 36_000 ? "Unlocked" : "Reach 10h", isUnlocked: totalPlayTimeSeconds >= 36_000, iconName: "timer"),
            ConsoleHubAchievement(id: "five-games", title: "5 Games Played", subtitle: uniquePlayedGames.count >= 5 ? "Unlocked" : "\(uniquePlayedGames.count)/5", isUnlocked: uniquePlayedGames.count >= 5, iconName: "square.grid.2x2.fill"),
            ConsoleHubAchievement(id: "save-master", title: "Save Master", subtitle: saveStateCountEstimate >= 10 ? "Unlocked" : "10 saves", isUnlocked: saveStateCountEstimate >= 10, iconName: "externaldrive.fill.badge.checkmark")
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
