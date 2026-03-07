import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#endif

struct HomeView: View {
    private enum IdleHighlightTarget {
        case none
        case gameStats
        case firstContinueCard
    }

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
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
                    VStack(spacing: isCollectorMode ? 18 : 24) {
                        if isCollectorMode {
                            collectorModeContent
                        } else {
                            statsGrid
                            recentGamesSection
                            emulatorsSection
                        }
                    }
                    .padding(.top, 12)
                    .padding(.horizontal, 16)
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
                        activeAlert = HomeAlertState(kind: .confirmFinalDelete(candidate))
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
                .blur(radius: heavyUIEffectsEnabled ? 120 : 36)
                .frame(width: 380, height: 380)
                .offset(x: 140, y: -220)

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
        VStack(alignment: .leading, spacing: 18) {
            collectorActionsRow
            collectorContinueSection
            collectorSystemsSection
        }
    }

    private var collectorActionsRow: some View {
        HStack(spacing: 10) {
            Button {
                showingGameLibrary = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 12, weight: .semibold))
                    Text("All Games")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(AppColors.surface)
                .overlay(
                    Capsule().stroke(AppColors.surfaceLight.opacity(0.6), lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                showingPlayerStats = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Stats")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(AppColors.surface)
                .overlay(
                    Capsule().stroke(AppColors.surfaceLight.opacity(0.6), lineWidth: 1)
                )
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var collectorContinueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Continue Playing")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button("View All") {
                    showingRecentlyPlayed = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.primary)
            }

            if viewModel.recentGames.isEmpty {
                Text("No recent games")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .background(AppColors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 20) {
                        ForEach(viewModel.recentGames) { game in
                            RecentGameCard(game: game) {
                                launchRecentGame(game)
                            }
                            .frame(width: 210)
                            .contextMenu {
                                recentGameContextMenu(game)
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
        }
    }

    private var collectorSystemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Systems")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("\(viewModel.emulators.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textMuted)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background(AppColors.surfaceLight.opacity(0.45))
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
            
            Button(action: {
                showingPlayerStats = true
            }) {
                StatCard(
                    title: "Game Stats",
                    value: viewModel.totalHours,
                    icon: "chart.bar.fill",
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
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                    Text("Continue Playing")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
                
                Button("View All") {
                    selectedGame = nil
                    showingRecentlyPlayed = true
                }
                .buttonStyle(.plain)
                .font(.system(size: 16, weight: .semibold))
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
                LazyVStack(spacing: 12) {
                    ForEach(Array(viewModel.recentGames.prefix(2).enumerated()), id: \.element.id) { index, game in
                        LandscapeGameRow(game: game) {
                            launchRecentGame(game)
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
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                    Text("All Emulators")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                }

                Spacer()

                Text("\(viewModel.emulators.count) systems")
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
        if shortName == "GB/GBC" {
            return .gameBoy
        }
        return EmulatorPlatform.allCases.first { $0.shortName == shortName }
    }

    private func refreshHome() {
        viewModel.loadData(in: viewContext)
    }

    @ViewBuilder
    private func recentGameContextMenu(_ game: RecentGame) -> some View {
        if let entry = viewModel.entry(for: game.gameId) {
            Button(role: .destructive) {
                activeAlert = HomeAlertState(kind: .confirmDelete(HomeDeleteCandidate(entry: entry, mode: .removeROMOnly)))
            } label: {
                Label("Remove ROM Only", systemImage: "eject")
            }

            Button(role: .destructive) {
                activeAlert = HomeAlertState(kind: .confirmDelete(HomeDeleteCandidate(entry: entry, mode: .removeAll)))
            } label: {
                Label("Remove", systemImage: "trash")
            }
        }
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
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(AppColors.primary)
                Spacer()
                ZStack {
                    Circle()
                        .fill(AppColors.primary.opacity(0.16))
                        .frame(width: 44, height: 44)

                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
            }

            Text(value)
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(AppColors.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 88, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [AppColors.primary.opacity(0.06), AppColors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.surfaceLight.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: AppColors.primary.opacity(0.10), radius: 10, x: 0, y: 6)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                } else {
                    placeholderImage
                }
                #else
                placeholderImage
                #endif
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayTitle(game.title))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                    
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
        let hours = max(0, game.totalPlaySeconds / 3600)
        return "\(hours)h"
    }

    private var sessionProgress: CGFloat {
        guard game.totalPlaySeconds > 0 else { return 0.08 }
        let capped = min(1.0, CGFloat(game.totalPlaySeconds) / CGFloat(4 * 3600))
        return max(0.08, capped)
    }

    private func displayTitle(_ title: String) -> String {
        let withoutTags = title.replacingOccurrences(
            of: #"\s*\([^)]*\)"#,
            with: "",
            options: .regularExpression
        )
        return withoutTags.replacingOccurrences(of: "_", with: " ")
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
                        colors: [Color.clear, Color.black.opacity(0.38)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(game.console)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppColors.primary.opacity(0.76))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .padding(8)

                    if let issue = game.launchIssue {
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
                    Text(game.title)
                        .font(.system(size: 17, weight: .bold))
                        .lineLimit(2)
                        .foregroundColor(AppColors.textPrimary)

                    HStack(spacing: 5) {
                        Image(systemName: "clock")
                            .font(.system(size: 10, weight: .semibold))
                        Text(playedDateText)
                            .font(.system(size: 12, weight: .semibold))
                        if game.totalPlaySeconds > 0 {
                            Text("•")
                                .font(.system(size: 11, weight: .medium))
                                .opacity(0.55)
                            Text(totalHoursText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.textMuted)
                        }
                    }
                    .foregroundColor(AppColors.textSecondary)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Session")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(AppColors.textMuted)
                            Text(sessionDescriptor)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary)
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
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
            }
            .frame(maxWidth: .infinity)
            .background(AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(AppColors.surfaceLight.opacity(0.65), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.06), radius: 10, x: 0, y: 5)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(CollectorCardPressStyle())
    }

    @ViewBuilder
    private var recentCardArtwork: some View {
        #if os(iOS)
        if let screenshotData = game.screenshotData, let uiImage = UIImage(data: screenshotData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
                .overlay(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if let coverData = game.coverData, let uiImage = UIImage(data: coverData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
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
            .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 120)
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

    private var sessionDescriptor: String {
        if game.totalPlaySeconds <= 0 { return "New" }
        if game.totalPlaySeconds < 1800 { return "Early run" }
        if game.totalPlaySeconds < 7200 { return "In progress" }
        return "Veteran"
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
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.background.opacity(0.9))
                            .frame(width: 56, height: 56)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LinearGradient(colors: gradient.map { $0.opacity(0.45) }, startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                            )

                        if let consoleAssetName {
                            Image(consoleAssetName)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 46, height: 46)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Text(icon)
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                        }
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
                            .fill(AppColors.primary)
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
        switch emulator.shortName {
        case "GB/GBC": return "ConsoleGBGBC"
        case "GBA": return "ConsoleGBA"
        case "NDS": return "ConsoleNDS"
        default: return nil
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: emulator.gradient.map { $0.opacity(0.35) } + [AppColors.surface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 130, height: 84)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(AppColors.surfaceLight.opacity(0.65), lineWidth: 1)
                        )

                    if let consoleAssetName {
                        Image(consoleAssetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        Text(emulator.icon)
                            .font(.system(size: 26))
                    }
                }

                Text(emulator.shortName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)

                Text("\(emulator.gamesCount) games")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppColors.textMuted)
            }
            .frame(width: 130, alignment: .leading)
        }
        .buttonStyle(CollectorCardPressStyle())
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
                        Label("Supports: .gb, .gbc, .gba, .nds", systemImage: "checkmark.seal")
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
                        await MainActor.run {
                            print("ROM imported successfully: \(url.lastPathComponent)")
                        }
                        successCount += 1
                    } catch {
                        let detail = error.localizedDescription
                        failures.append("\(url.lastPathComponent): \(detail)")
                        print("Import error for \(url.lastPathComponent): \(detail)")
                    }
                }
                await MainActor.run {
                    self.coordinator.isImporting = false
                    if successCount > 0 {
                        self.dismiss()
                    } else if let firstFailure = failures.first {
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
    @Published var recentGames: [RecentGame] = []
    @Published var emulators: [EmulatorInfo] = []
    private var entriesByID: [UUID: ROMLibraryEntry] = [:]
    
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
        entriesByID = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
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
                coverData: CoverArtService.shared.resolve(for: entry)?.data,
                totalPlaySeconds: Int(entry.playtimeTotal),
                playableGame: entry.toGame(),
                gameId: entry.id,
                launchIssue: ROMCompatibilityService.shared.compatibility(for: entry).issue
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
