import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#endif

private enum HomeShelfMetrics {
    static func recentGameCardWidth(for availableWidth: CGFloat) -> CGFloat {
        min(280, max(232, availableWidth - 36))
    }

    static func collectorRecentGameCardWidth(for availableWidth: CGFloat) -> CGFloat {
        min(250, max(228, availableWidth - 72))
    }
}

struct HomeView: View {
    private enum IdleHighlightTarget {
        case none
        case gameStats
        case firstContinueCard
    }

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var performanceProfiler = PerformanceProfiler.shared
    @State private var showingSettings = false
    @State private var showingImport = false
    @State private var showingGameLibrary = false
    @State private var showingRecentlyPlayed = false
    @State private var showingPlayerStats = false
    @State private var selectedPlatform: EmulatorPlatform?
    @State private var selectedGame: Game?
    @State private var activeAlert: HomeAlertState?
    @State private var renameEntry: ROMLibraryEntry?
    @State private var renameTitle = ""
    @State private var detailEntry: ROMLibraryEntry?
    @State private var lastInteractionAt = Date()
    @State private var isIdle = false
    @State private var idleBreathing = false
    @State private var idleTarget: IdleHighlightTarget = .none
    private let idleThreshold: TimeInterval = 10
    private let idleTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

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
    
    var body: some View {
        ZStack {
            backgroundGradients
            if isCollectorMode {
                collectorAtmosphere
            }

            VStack(spacing: 0) {
                headerSection

                ScrollView {
                    VStack(spacing: isCollectorMode ? 18 : RMSpacing.sectionGap) {
                        if isCollectorMode {
                            collectorModeContent
                        } else {
                            statsGrid
                            recentGamesSection
                            emulatorsSection
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal, RMSpacing.lg)
                    .padding(.bottom, 32)
                }
            }
        }
        .animation(.easeInOut(duration: 0.28), value: isCollectorMode)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .swipeBack {
                    showingSettings = false
                }
        }
        .sheet(isPresented: $showingImport) {
            RomImportView()
                .swipeBack {
                    showingImport = false
                }
        }
        .sheet(isPresented: $showingGameLibrary) {
            GameLibraryView()
                .swipeBack {
                    showingGameLibrary = false
                }
        }
        .sheet(isPresented: $showingRecentlyPlayed) {
            RecentlyPlayedView()
                .swipeBack {
                    showingRecentlyPlayed = false
                }
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $showingPlayerStats) {
            PlayerStatsView()
        }
        #else
        .sheet(isPresented: $showingPlayerStats) {
            PlayerStatsView()
        }
        #endif
        .sheet(item: $selectedPlatform) { platform in
            GameListView(platform: platform)
                .swipeBack {
                    selectedPlatform = nil
                }
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
        #endif
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
                        activeAlert = HomeAlertState(kind: .confirmFinalDelete(candidate))
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
        .onAppear {
            refreshHome()
            markInteraction()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshHome()
                markInteraction()
            } else {
                isIdle = false
            }
        }
        .onChange(of: showingImport) { _, shown in if !shown { refreshHome() } }
        .onChange(of: showingGameLibrary) { _, shown in if !shown { refreshHome() } }
        .onChange(of: showingRecentlyPlayed) { _, shown in if !shown { refreshHome() } }
        .onChange(of: showingPlayerStats) { _, shown in if !shown { refreshHome() } }
        .onChange(of: showingSettings) { _, shown in if !shown { refreshHome() } }
        .onChange(of: selectedPlatform) { _, platform in if platform == nil { refreshHome() } }
        .onReceive(NotificationCenter.default.publisher(for: .romLibraryDidChange)) { _ in
            refreshHome()
        }
        .onReceive(NotificationCenter.default.publisher(for: .coverArtDidChange)) { _ in
            refreshHome()
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                markInteraction()
            }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).onChanged { _ in
                markInteraction()
            }
        )
        .onReceive(idleTimer) { now in
            guard scenePhase == .active else {
                if isIdle { isIdle = false }
                return
            }
            let shouldIdle = now.timeIntervalSince(lastInteractionAt) >= idleThreshold
            if shouldIdle != isIdle {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isIdle = shouldIdle
                }
            }
        }
        .onChange(of: isIdle) { _, nowIdle in
            if nowIdle {
                chooseIdleTarget()
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    idleBreathing = true
                }
            } else {
                idleBreathing = false
                idleTarget = .none
            }
        }
    }
    
    private var backgroundGradients: some View {
        ZStack {
            AppColors.Background.appPrimary
                .ignoresSafeArea()

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.12), AppColors.accent.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: heavyUIEffectsEnabled ? 110 : 32)
                .frame(width: 320, height: 320)
                .offset(x: 128, y: -228)

            if heavyUIEffectsEnabled {
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

    private var collectorModeContent: some View {
        VStack(alignment: .leading, spacing: 28) {
            collectorActionsRow
            collectorContinueSection
            collectorSystemsSection
            collectorRecentlyAddedSection
        }
        .padding(.horizontal, 8)
    }

    private var collectorActionsRow: some View {
        HStack(spacing: 10) {
            Button {
                showingGameLibrary = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L10n.string("home.library", languageManager: languageManager))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AppColors.Text.primary)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(AppColors.Surface.cardElevated)
                .overlay(Capsule().stroke(AppColors.Border.subtle, lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                showingPlayerStats = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(L10n.string("home.stats", languageManager: languageManager))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(AppColors.Text.primary)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(AppColors.Surface.cardElevated)
                .overlay(Capsule().stroke(AppColors.Border.subtle, lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var collectorContinueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.string("home.continue_playing", languageManager: languageManager))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.Text.primary)
                Spacer()
                Button(L10n.string("home.view_all", languageManager: languageManager)) {
                    showingRecentlyPlayed = true
                }
                .buttonStyle(.plain)
                .font(RMTypeScale.body)
                .foregroundStyle(AppColors.Text.accent)
            }

            if viewModel.recentGames.isEmpty {
                Text(L10n.string("home.no_recent_games", languageManager: languageManager))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.Text.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(AppColors.Surface.cardSecondary)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.Border.subtle, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                GeometryReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 20) {
                            ForEach(viewModel.recentGames) { game in
                                RecentGameCard(game: game, variant: .compact) {
                                    launchRecentGame(game)
                                }
                                .frame(
                                    width: HomeShelfMetrics.collectorRecentGameCardWidth(for: proxy.size.width),
                                    height: 216
                                )
                                .contextMenu {
                                    recentGameContextMenu(game)
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
                .frame(height: 216)
#if os(iOS)
                .scrollTargetBehavior(.viewAligned)
#endif
            }
        }
        .padding(16)
        .background(AppColors.Surface.cardPrimary)
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColors.Border.subtle, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var collectorSystemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.string("home.your_consoles", languageManager: languageManager))
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.Text.primary)
                Spacer()
                Text(L10n.format("home.systems.count", Int64(viewModel.emulators.count), languageManager: languageManager))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.Text.tertiary)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(AppColors.Surface.cardElevated)
                    .clipShape(Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 20) {
                    ForEach(viewModel.emulators) { emulator in
                        CollectorSystemTile(emulator: emulator) {
                            selectedPlatform = platform(for: emulator.shortName)
                        }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 24)
            }
#if os(iOS)
            .scrollTargetBehavior(.viewAligned)
#endif
        }
        .padding(16)
        .background(AppColors.Surface.cardPrimary)
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColors.Border.subtle, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var collectorRecentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.string("home.recently_added", languageManager: languageManager))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.Text.primary)
                Spacer()
            }

            if viewModel.recentlyAddedGames.isEmpty {
                EmptyView()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(viewModel.recentlyAddedGames.prefix(10)) { game in
                            RecentGameCard(game: game, variant: .compact) {
                                launchRecentGame(game)
                            }
                            .frame(width: 240)
                            .contextMenu {
                                recentGameContextMenu(game)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .scrollTargetLayout()
                }
#if os(iOS)
                .scrollTargetBehavior(.viewAligned)
#endif
            }
        }
        .padding(16)
        .background(AppColors.Surface.cardPrimary)
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(AppColors.Border.subtle, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    private var statsGrid: some View {
        HStack(spacing: RMSpacing.lg) {
            Button(action: {
                showingGameLibrary = true
            }) {
                StatCard(
                    title: L10n.string("home.total_games", languageManager: languageManager),
                    value: "\(viewModel.totalGames)",
                    icon: "gamecontroller.fill",
                    helper: L10n.format("home.total_games.helper", Int64(viewModel.emulators.count), languageManager: languageManager),
                    gradient: [AppColors.primary, AppColors.accent]
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            Button(action: {
                showingPlayerStats = true
            }) {
                StatCard(
                    title: L10n.string("home.game_stats", languageManager: languageManager),
                    value: viewModel.totalHours,
                    icon: "chart.bar.fill",
                    helper: viewModel.gameStatsHelper,
                    gradient: [AppColors.info, AppColors.primary]
                )
            }
            .buttonStyle(PlainButtonStyle())
            .scaleEffect(idleTarget == .gameStats ? (idleBreathing ? 1.03 : 0.985) : 1.0)
            .shadow(
                color: AppColors.primary.opacity(idleTarget == .gameStats ? (idleBreathing ? 0.24 : 0.12) : 0.08),
                radius: idleTarget == .gameStats ? 16 : 8,
                x: 0,
                y: idleTarget == .gameStats ? 9 : 5
            )
        }
    }
    
    private var recentGamesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                    Text(L10n.string("home.continue_playing", languageManager: languageManager))
                        .font(RMTypeScale.sectionTitle)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
                
                Button(L10n.string("home.view_all", languageManager: languageManager)) {
                    selectedGame = nil
                    showingRecentlyPlayed = true
                }
                .buttonStyle(.plain)
                .font(RMTypeScale.body)
                .foregroundColor(AppColors.primary)
            }
            .padding(.top, RMSpacing.xl)
            .padding(.bottom, RMSpacing.md)
            .contentShape(Rectangle())
            .zIndex(2)
            
            if viewModel.recentGames.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(AppColors.textMuted)
                    Text(L10n.string("home.no_recent_games", languageManager: languageManager))
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
                GeometryReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(Array(viewModel.recentGames.prefix(4)), id: \.id) { game in
                                RecentGameCard(game: game, variant: .standard) {
                                    launchRecentGame(game)
                                }
                                .frame(width: HomeShelfMetrics.recentGameCardWidth(for: proxy.size.width))
                                .contextMenu {
                                    recentGameContextMenu(game)
                                }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
                .frame(height: 292)
                .zIndex(0)
            }
        }
    }
    
    private var emulatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                    Text(L10n.string("home.all_emulators", languageManager: languageManager))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                Text(L10n.format("home.systems.count", Int64(viewModel.emulators.count), languageManager: languageManager))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.primary)
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
        return EmulatorPlatform.allCases.first { $0.shortName == shortName }
    }

    private func refreshHome() {
        viewModel.loadData(in: viewContext)
    }

    @ViewBuilder
    private func recentGameContextMenu(_ game: RecentGame) -> some View {
        if let entry = viewModel.entry(for: game.gameId) {
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
                activeAlert = HomeAlertState(kind: .confirmDelete(HomeDeleteCandidate(entry: entry, mode: .removeROMOnly)))
            } label: {
                Label(L10n.string("home.context.remove_rom_only", languageManager: languageManager), systemImage: "eject")
            }

            Button(role: .destructive) {
                activeAlert = HomeAlertState(kind: .confirmDelete(HomeDeleteCandidate(entry: entry, mode: .removeAll)))
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
            refreshHome()
        } catch {
            activeAlert = HomeAlertState(kind: .launchError("Could not rename game: \(error.localizedDescription)"))
        }
    }

    private func showDetails(_ entry: ROMLibraryEntry) {
        detailEntry = entry
    }

    private func launchRecentGame(_ recent: RecentGame) {
        if let issue = recent.launchIssue {
            activeAlert = HomeAlertState(kind: .launchError(issue.message))
            return
        }
        if let playable = recent.playableGame {
            selectedGame = playable
        } else {
            showingRecentlyPlayed = true
        }
    }

    private func performDeletion(_ candidate: HomeDeleteCandidate) {
        do {
            try GameDeletionService.shared.delete(entry: candidate.entry, mode: candidate.mode, in: viewContext)
            refreshHome()
        } catch {
            activeAlert = HomeAlertState(kind: .launchError("Could not delete game: \(error.localizedDescription)"))
        }
    }

    private func markInteraction() {
        lastInteractionAt = Date()
        if isIdle {
            isIdle = false
        }
        idleTarget = .none
    }

    private func chooseIdleTarget() {
        if !viewModel.recentGames.isEmpty, Bool.random() {
            idleTarget = .firstContinueCard
        } else {
            idleTarget = .gameStats
        }
    }
}

struct StatCard: View {
    private static let minHeight: CGFloat = 120
    private static let valueAreaHeight: CGFloat = 78
    private static let helperAreaHeight: CGFloat = 34

    let title: String
    let value: String
    let icon: String
    let helper: String
    let gradient: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: RMSpacing.xs) {
            HStack(alignment: .top) {
                Text(title)
                    .font(RMTypeScale.body)
                    .foregroundStyle(AppColors.Text.secondary)
                Spacer()
                ZStack {
                    Circle()
                        .fill(AppColors.Surface.accentTint)
                        .frame(width: 36, height: 36)

                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(AppColors.Text.accent)
                }
            }

            Text(value)
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(AppColors.Text.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: Self.valueAreaHeight, alignment: .topLeading)

            Text(helper)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.Text.tertiary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: Self.helperAreaHeight, alignment: .topLeading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: Self.minHeight, alignment: .topLeading)
        .background(AppColors.Surface.cardPrimary)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.Border.subtle, lineWidth: 1))
        .shadow(color: AppColors.Shadow.card, radius: 12, x: 0, y: 8)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func isLandscape(game: RecentGame) -> Bool {
        #if os(iOS)
        if let screenshotData = game.screenshotData,
           let uiImage = UIImage(data: screenshotData) {
            return uiImage.size.width > uiImage.size.height
        }
        #endif
        return false
    }
    
    private func formatRecentDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

struct LandscapeGameRow: View {
    let game: RecentGame
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                #if os(iOS)
                if let screenshotData = game.screenshotData, let uiImage = UIImage(data: screenshotData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else if let coverData = game.coverData, let uiImage = UIImage(data: coverData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    placeholderImage
                }
                #else
                placeholderImage
                #endif
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(GameCardTitleFormatter.format(game.title, maxWords: 7))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(height: 38, alignment: .topLeading)
                    
                    HStack(spacing: 6) {
                        if let lastPlayed = game.lastPlayed {
                            Text(formatRecentDate(lastPlayed))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }

                        if game.totalPlaySeconds > 0 {
                            Text("•")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppColors.textMuted)
                            Text(totalHoursText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.textMuted)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(AppColors.surfaceLight.opacity(0.65))
                            Capsule()
                                .fill(AppColors.primary.opacity(0.75))
                                .frame(width: max(8, geo.size.width * sessionProgress))
                        }
                    }
                    .frame(height: 6)

                    HStack {
                        Text(game.console)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.textMuted)
                        Spacer()
                        Text("Resume")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppColors.primary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(AppColors.primary)
            }
            .padding(12)
            .background(AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: AppColors.primary.opacity(0.05), radius: 8, x: 0, y: 5)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var placeholderImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.surfaceLight)
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 24))
                .foregroundColor(AppColors.textMuted)
        }
        .frame(width: 160, height: 90)
    }
    
    private func formatRecentDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private var totalHoursText: String {
        let minutes = max(1, game.totalPlaySeconds / 60)
        if minutes < 60 {
            return "\(minutes)m played"
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours)h played"
        }
        return "\(hours)h \(remainder)m played"
    }

    private var sessionProgress: CGFloat {
        guard game.totalPlaySeconds > 0 else { return 0.08 }
        let capped = min(1.0, CGFloat(game.totalPlaySeconds) / CGFloat(4 * 3600))
        return max(0.08, capped)
    }

}

struct RecentGameCard: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let game: RecentGame
    let variant: CollectorCardVariant
    let onTap: () -> Void

    init(game: RecentGame, variant: CollectorCardVariant = .featured, onTap: @escaping () -> Void) {
        self.game = game
        self.variant = variant
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap) {
            CollectorGameCard(
                variant: variant,
                title: GameCardTitleFormatter.format(game.title, maxWords: 7),
                supportingTitleLine: game.smartSummary?.primaryProgressLine,
                metadataPrimary: playedDateText,
                metadataSecondary: continuePlayingMetadataSecondary,
                platformTag: game.console,
                launchIssueIconName: game.launchIssue?.iconName,
                progress: sessionProgress
            ) {
                recentCardArtwork
            }
        }
        .buttonStyle(CollectorCardPressStyle())
    }

    @ViewBuilder
    private var recentCardArtwork: some View {
        let artworkHeight: CGFloat = variant == .featured ? 152 : 126
        #if os(iOS)
        if let screenshotData = game.screenshotData, let uiImage = UIImage(data: screenshotData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, minHeight: artworkHeight, maxHeight: artworkHeight)
                .clipped()
                .overlay(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let coverData = game.coverData, let uiImage = UIImage(data: coverData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, minHeight: artworkHeight, maxHeight: artworkHeight)
                .clipped()
                .overlay(Color.white.opacity(0.16))
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
            .frame(maxWidth: .infinity, minHeight: artworkHeight, maxHeight: artworkHeight)
            .clipped()
            .overlay(Color.white.opacity(0.16))
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
            .frame(maxWidth: .infinity, minHeight: artworkHeight, maxHeight: artworkHeight)
            .clipped()
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
        .frame(maxWidth: .infinity, minHeight: variant == .featured ? 152 : 126, maxHeight: variant == .featured ? 152 : 126)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var playedDateText: String {
        guard let date = game.lastPlayed else {
            return L10n.string("common.never_played", table: "Screens", languageManager: languageManager)
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = languageManager.formattingLocale
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private var continuePlayingMetadataSecondary: String? {
        if let statusLine = game.smartSummary?.supportingStateLine, !statusLine.isEmpty {
            return statusLine
        }
        return game.totalPlaySeconds > 0 ? totalHoursText : nil
    }

    private var totalHoursText: String {
        let hours = max(0, game.totalPlaySeconds / 3600)
        return L10n.format(
            "common.duration_hours_only",
            Int64(hours),
            table: "Screens",
            languageManager: languageManager
        )
    }

    private var sessionProgress: CGFloat {
        guard game.totalPlaySeconds > 0 else { return 0.08 }
        let capped = min(1.0, CGFloat(game.totalPlaySeconds) / CGFloat(4 * 3600))
        return max(0.08, capped)
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
        ConsoleIdentity.resolve(systemRaw: shortName)?.assetName
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
                                    colors: [Color.white.opacity(0.16), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
                    )
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [gradient.first?.opacity(0.24) ?? Color.clear, Color.clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 72)
                    }
                    .shadow(color: AppColors.primary.opacity(0.05), radius: 12, x: 0, y: 6)

                HStack(spacing: 16) {
                    ZStack {
                        RMIconBadge(
                            systemName: nil,
                            assetName: consoleAssetName,
                            emoji: consoleAssetName == nil ? icon : nil,
                            size: 56,
                            shape: .roundedRect,
                            accent: true,
                            imageInset: 5
                        )
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(AppColors.textPrimary)

            HStack(spacing: 4) {
                Text(shortName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textMuted)

                            Text("•")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(AppColors.textMuted)

                            Text("\(gamesCount) games")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Spacer()

                    ZStack {
                        Circle()
                            .fill(AppColors.accentGradient.opacity(0.9))
                            .frame(width: 44, height: 44)
                            .shadow(color: AppColors.primary.opacity(isHovered ? 0.38 : 0.22), radius: isHovered ? 16 : 10, x: 0, y: 6)

                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .offset(x: 1)
                    }
                }
                .padding(16)
            }
            .frame(minHeight: 92)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

private struct CollectorSystemTile: View {
    let emulator: EmulatorInfo
    let onTap: () -> Void

    private var consoleAssetName: String? {
        ConsoleIdentity.resolve(systemRaw: emulator.shortName)?.assetName
    }

    var body: some View {
        CollectorConsoleTile(
            title: emulator.shortName,
            subtitle: "\(emulator.gamesCount) games",
            systemTag: emulator.shortName,
            icon: emulator.icon,
            consoleAssetName: consoleAssetName,
            onTap: onTap
        )
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
    @State private var importErrorMessage: String?
    
    init() {
        let persistence = PersistenceController.shared
        let romsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ROMs", isDirectory: true)
        _coordinator = StateObject(wrappedValue: RomImportCoordinator(persistence: persistence, romsDirectory: romsDir))
    }
    
    // presentDocumentPicker() moved to private func with full implementation below
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer(minLength: 8)

                VStack(spacing: 16) {
                    ZStack {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.primary.opacity(0.95), AppColors.accent.opacity(0.9)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 78, height: 78)
                                .shadow(color: AppColors.primary.opacity(0.25), radius: 14, x: 0, y: 8)

                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundColor(.white.opacity(0.95))
                        }

                    VStack(spacing: 8) {
                            Text("Import ROMs")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(AppColors.textPrimary)

                            Text("Select ROM files from your device to add them to your library.")
                                .font(.system(size: 15))
                                .foregroundColor(AppColors.textMuted)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 26)
                    .padding(.horizontal, 20)
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(AppColors.surfaceLight.opacity(0.55), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Label(
                            "Supports: " + RomImportCoordinator.supportedROMFileExtensions
                                .map { ".\($0)" }
                                .joined(separator: ", "),
                            systemImage: "checkmark.seal"
                        )
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                        Label("Files stay on your device", systemImage: "lock.shield")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)

                    Spacer(minLength: 0)

                    Button(action: {
                        #if os(iOS)
                        presentDocumentPicker()
                        #endif
                    }) {
                        Text("Select Files")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.12, blue: 0.35), AppColors.primary],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 18)
                }
                .padding(.horizontal, 16)
            }
            .navigationTitle("Import")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
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
        .alert(
            "Import Failed",
            isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    importErrorMessage = nil
                }
            },
            message: {
                Text(importErrorMessage ?? "The selected file could not be imported.")
            }
        )
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
                var successCount = 0
                var failures: [String] = []
                for url in urls {
                    do {
                        _ = try await self.coordinator.importROM(from: url)
                        successCount += 1
                    } catch {
                        let detail = error.localizedDescription
                        failures.append("\(url.lastPathComponent): \(detail)")
                    }
                }
                let didImportAny = successCount > 0
                let firstFailure = failures.first
                await MainActor.run {
                    self.coordinator.isImporting = false
                    if didImportAny {
                        self.dismiss()
                    } else if let firstFailure {
                        self.importErrorMessage = firstFailure
                    }
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
    @Published var gameStatsHelper: String
    @Published var recentGames: [RecentGame] = []
    @Published var recentlyAddedGames: [RecentGame] = []
    @Published var emulators: [EmulatorInfo] = []
    private var entriesByID: [UUID: ROMLibraryEntry] = [:]
    private let languageManager: LanguageManager
    
    private var fetchedResultsController: NSFetchedResultsController<ROMLibraryEntry>?
    private weak var viewContext: NSManagedObjectContext?

    init(languageManager: LanguageManager = .shared) {
        self.languageManager = languageManager
        self.gameStatsHelper = L10n.string("home.game_stats.empty_helper", languageManager: languageManager)
    }
    
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
        }
    }
    
    private func updateStats(from entries: [ROMLibraryEntry]) {
        entriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
        totalGames = entries.count
        
        let totalSeconds = Int(entries.reduce(0) { $0 + $1.playtimeTotal })
        totalHours = LocaleFormatting.shortDuration(
            seconds: totalSeconds,
            languageManager: languageManager
        )
        
        let recentEntries = entries.filter { $0.lastPlayedAt != nil }.prefix(5)
        recentGames = recentEntries.map { entry in
            let console = entry.consoleIdentity?.systemCode ?? entry.system?.uppercased() ?? "Unknown"
            return RecentGame(
                id: entry.objectID.uriRepresentation().absoluteString,
                title: entry.title ?? "Unknown",
                console: console,
                lastPlayed: entry.lastPlayedAt,
                progress: 0,
                image: nil,
                screenshotData: SaveStateStorage.shared.latestScreenshot(for: entry.checksum ?? ""),
                coverData: CoverArtService.shared.resolve(for: entry)?.data,
                totalPlaySeconds: Int(entry.playtimeTotal),
                playableGame: entry.toGame(),
                gameId: entry.id,
                launchIssue: ROMCompatibilityService.shared.compatibility(for: entry).issue,
                smartSummary: entry.checksum.flatMap { PlayInsightsStore.shared.continuePlayingSummary(for: $0) }
            )
        }
        gameStatsHelper = recentGames.first?.title
            ?? L10n.string("home.game_stats.empty_helper", languageManager: languageManager)

        let addedEntries = entries
            .sorted {
                let lhs = $0.dateAdded ?? Date.distantPast
                let rhs = $1.dateAdded ?? Date.distantPast
                return lhs > rhs
            }
            .prefix(8)

        recentlyAddedGames = addedEntries.map { entry in
            let console = entry.consoleIdentity?.systemCode ?? entry.system?.uppercased() ?? "Unknown"
            return RecentGame(
                id: "added-\(entry.objectID.uriRepresentation().absoluteString)",
                title: entry.title ?? "Unknown",
                console: console,
                lastPlayed: entry.dateAdded ?? entry.lastPlayedAt,
                progress: 0,
                image: nil,
                screenshotData: SaveStateStorage.shared.latestScreenshot(for: entry.checksum ?? ""),
                coverData: CoverArtService.shared.resolve(for: entry)?.data,
                totalPlaySeconds: Int(entry.playtimeTotal),
                playableGame: entry.toGame(),
                gameId: entry.id,
                launchIssue: ROMCompatibilityService.shared.compatibility(for: entry).issue,
                smartSummary: entry.checksum.flatMap { PlayInsightsStore.shared.continuePlayingSummary(for: $0) }
            )
        }
    }
    
    private func loadEmulators(from entries: [ROMLibraryEntry]) {
        let countsBySystem = Dictionary(grouping: entries) {
            $0.resolvedSystemCode
        }.mapValues(\.count)

        emulators = [
            EmulatorInfo(name: "Game Boy", shortName: "GB", gamesCount: countsBySystem["gb", default: 0], gradient: [Color(hex: "B7D6A4"), Color(hex: "7D9A52")], icon: "🎮"),
            EmulatorInfo(name: "Game Boy Color", shortName: "GBC", gamesCount: countsBySystem["gbc", default: 0], gradient: [Color(hex: "B597F5"), Color(hex: "7A4BC2")], icon: "🌈"),
            EmulatorInfo(name: "Game Boy Advance", shortName: "GBA", gamesCount: countsBySystem["gba", default: 0], gradient: [Color.purple, Color.indigo], icon: "⚡"),
            EmulatorInfo(name: "Nintendo DS", shortName: "NDS", gamesCount: countsBySystem["nds", default: 0], gradient: [Color.cyan, Color.blue], icon: "📱"),
        ].filter { $0.gamesCount > 0 || ["GB", "GBC", "GBA", "NDS"].contains($0.shortName) }
    }
    
    func entry(for id: UUID) -> ROMLibraryEntry? {
        entriesByID[id]
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
    let coverData: Data?
    let totalPlaySeconds: Int
    let playableGame: Game?
    let gameId: UUID
    let launchIssue: ROMLaunchIssue?
    let smartSummary: ContinuePlayingSmartSummary?
}

struct EmulatorInfo: Identifiable {
    let id = UUID()
    let name: String
    let shortName: String
    var gamesCount: Int
    let gradient: [Color]
    let icon: String
}

private struct HomeDeleteCandidate: Identifiable {
    let id = UUID()
    let entry: ROMLibraryEntry
    let mode: GameDeletionMode
}

private struct HomeAlertState: Identifiable {
    enum Kind {
        case launchError(String)
        case confirmDelete(HomeDeleteCandidate)
        case confirmFinalDelete(HomeDeleteCandidate)
    }

    let id = UUID()
    let kind: Kind
}
