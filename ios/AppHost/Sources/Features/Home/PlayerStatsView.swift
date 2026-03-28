import SwiftUI
import CoreData

struct PlayerStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var viewModel = PlayerStatsViewModel()
    @State private var selectedGame: Game?
    @State private var launchErrorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        summaryHero
                        consoleBreakdownSection
                        topGamesSection
                        achievementsSection
                        timelineSection
                        insightsSection
                    }
                    .padding(.horizontal, RMSpacing.lg)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    viewModel.load(in: viewContext, languageManager: languageManager)
                }
            }
            .navigationTitle(L10n.string("playerstats.title", table: "Screens", languageManager: languageManager))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                #else
                ToolbarItem {
                    Button(L10n.string("playerstats.close", table: "Screens", languageManager: languageManager)) { dismiss() }
                }
                #endif
            }
            #if os(iOS)
            .fullScreenCover(item: $selectedGame) { game in
                GamePlayView(game: game, onExit: { selectedGame = nil })
            }
            #else
            .sheet(item: $selectedGame) { game in
                GameDetailView(game: game)
            }
            #endif
            .alert(L10n.string("playerstats.error.title", table: "Screens", languageManager: languageManager), isPresented: Binding(
                get: { launchErrorMessage != nil },
                set: { if !$0 { launchErrorMessage = nil } }
            )) {
                Button(L10n.string("common.ok", languageManager: languageManager), role: .cancel) { launchErrorMessage = nil }
            } message: {
                Text(launchErrorMessage ?? L10n.string("playerstats.error.message", table: "Screens", languageManager: languageManager))
            }
            .onAppear { viewModel.load(in: viewContext, languageManager: languageManager) }
            .onChange(of: languageManager.refreshID) {
                viewModel.load(in: viewContext, languageManager: languageManager)
            }
        }
    }

    private var summaryHero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.primary.opacity(0.95), AppColors.accent.opacity(0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "person.crop.circle.fill.badge.checkmark")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 58, height: 58)
                .shadow(color: AppColors.primary.opacity(0.28), radius: 16, x: 0, y: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.string("playerstats.profile", table: "Screens", languageManager: languageManager))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(L10n.format("playerstats.favorite_format", viewModel.playerSinceText, viewModel.favoriteSystemText, table: "Screens", languageManager: languageManager))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                metricCard(title: L10n.string("playerstats.metric.hours_played", table: "Screens", languageManager: languageManager), value: viewModel.totalHoursText, icon: "clock.fill", hero: true)
                metricCard(title: L10n.string("playerstats.metric.sessions", table: "Screens", languageManager: languageManager), value: "\(viewModel.totalSessions)", icon: "bolt.fill", hero: true)
            }

            HStack(spacing: 12) {
                metricCard(title: L10n.string("playerstats.metric.games_played", table: "Screens", languageManager: languageManager), value: "\(viewModel.gamesPlayedCount)", icon: "gamecontroller.fill")
                metricCard(title: L10n.string("playerstats.metric.longest_play", table: "Screens", languageManager: languageManager), value: viewModel.longestPlayText, icon: "hourglass.bottomhalf.filled")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.surface,
                            AppColors.surfaceLight.opacity(0.85)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(AppColors.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: AppColors.primary.opacity(0.12), radius: 16, x: 0, y: 10)
    }

    private func metricCard(title: String, value: String, icon: String, hero: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: hero ? 10 : 6) {
            HStack {
                Text(title)
                    .font(.system(size: hero ? 13 : 12, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: hero ? 13 : 12, weight: .semibold))
                    .foregroundColor(AppColors.primary)
            }

            Text(value)
                .font(.system(size: hero ? 28 : 22, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, hero ? 14 : 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.surface.opacity(0.95))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
        )
    }

    private var consoleBreakdownSection: some View {
        sectionCard(title: L10n.string("playerstats.section.where_time_went", table: "Screens", languageManager: languageManager), trailing: nil) {
            VStack(spacing: 12) {
                ForEach(viewModel.consoleBreakdown) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                            Text(item.hoursText)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(AppColors.primary)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppColors.surfaceLight.opacity(0.65))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [item.color.opacity(0.85), AppColors.primary.opacity(0.65)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(10, proxy.size.width * item.ratio))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
        }
    }

    private var topGamesSection: some View {
        sectionCard(title: L10n.string("playerstats.section.top_games", table: "Screens", languageManager: languageManager), trailing: "\(viewModel.topGames.count)") {
            VStack(spacing: 10) {
                ForEach(Array(viewModel.topGames.enumerated()), id: \.element.id) { index, item in
                    Button {
                        if let issue = item.launchIssue {
                            launchErrorMessage = issue.message
                            return
                        }
                        selectedGame = item.game
                    } label: {
                        HStack(spacing: 12) {
                            Text("#\(index + 1)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(index == 0 ? AppColors.primary : AppColors.textSecondary)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)
                                Text("\(item.systemLabel) · \(item.hoursText)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                                if item.launchIssue != nil {
                                    Label(L10n.string("playerstats.unsupported_mapper", table: "Screens", languageManager: languageManager), systemImage: "exclamationmark.triangle.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.orange)
                                }
                            }

                            Spacer()

                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppColors.primary)
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(AppColors.surfaceLight.opacity(0.8))
                                )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppColors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var achievementsSection: some View {
        sectionCard(title: L10n.string("playerstats.section.achievements", table: "Screens", languageManager: languageManager), trailing: "\(viewModel.unlockedAchievementCount)/\(viewModel.achievements.count)") {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(viewModel.achievements) { achievement in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: achievement.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(achievement.isUnlocked ? achievement.color : AppColors.textMuted.opacity(0.55))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill((achievement.isUnlocked ? achievement.color : AppColors.surfaceLight).opacity(achievement.isUnlocked ? 0.14 : 0.45))
                                )
                            Spacer()
                            if achievement.isUnlocked {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(AppColors.primary)
                            } else {
                                Text("\(Int((achievement.progress * 100).rounded()))%")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppColors.textMuted)
                            }
                        }

                        Text(achievement.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2)

                        Text(achievement.detail)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                            .lineLimit(2)

                        if !achievement.isUnlocked {
                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(AppColors.surfaceLight.opacity(0.7))
                                    Capsule()
                                        .fill(AppColors.primary.opacity(0.75))
                                        .frame(width: max(6, proxy.size.width * achievement.progress))
                                }
                            }
                            .frame(height: 6)
                        } else if let dateText = achievement.unlockedDateText {
                            Text(dateText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.textMuted)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppColors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(achievement.isUnlocked ? AppColors.primary.opacity(0.18) : AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var timelineSection: some View {
        sectionCard(title: L10n.string("playerstats.section.recent_activity", table: "Screens", languageManager: languageManager), trailing: nil) {
            if viewModel.timeline.isEmpty {
                emptyState(L10n.string("playerstats.empty.recent_activity", table: "Screens", languageManager: languageManager))
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.timeline) { event in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: event.icon)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(event.color)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(event.color.opacity(0.12)))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(AppColors.textPrimary)
                                Text(event.subtitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            Spacer()
                            Text(event.relativeText)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.textMuted)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppColors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private var insightsSection: some View {
        sectionCard(title: L10n.string("playerstats.section.insights", table: "Screens", languageManager: languageManager), trailing: nil) {
            if viewModel.insights.isEmpty {
                emptyState(L10n.string("playerstats.empty.insights", table: "Screens", languageManager: languageManager))
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.insights, id: \.self) { insight in
                        HStack(spacing: 10) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(AppColors.primary)
                            Text(insight)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppColors.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppColors.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppColors.primary.opacity(0.08), lineWidth: 1)
                        )
                    }
                }
            }
        }
    }

    private func sectionCard<Content: View>(title: String, trailing: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: RMSpacing.md) {
            HStack {
                Text(title)
                    .font(RMTypeScale.sectionTitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppColors.primary)
                }
            }
            content()
        }
        .padding(RMSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: RMRadius.card, style: .continuous)
                .fill(AppColors.surface.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RMRadius.card, style: .continuous)
                .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: AppColors.primary.opacity(0.06), radius: 10, x: 0, y: 6)
    }

    private func emptyState(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(AppColors.textMuted)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppColors.surfaceLight.opacity(0.55))
        )
    }
}

@MainActor
final class PlayerStatsViewModel: ObservableObject {
    @Published private(set) var totalHoursText = "0h"
    @Published private(set) var totalSessions = 0
    @Published private(set) var gamesPlayedCount = 0
    @Published private(set) var longestPlayText = "0m"
    @Published private(set) var playerSinceText = "No play history yet"
    @Published private(set) var favoriteSystemText = "None"
    @Published private(set) var consoleBreakdown: [ConsolePlayBreakdown] = []
    @Published private(set) var topGames: [TopPlayedGame] = []
    @Published private(set) var achievements: [PlayerAchievement] = []
    @Published private(set) var timeline: [PlayerActivityEvent] = []
    @Published private(set) var insights: [String] = []

    var unlockedAchievementCount: Int { achievements.filter(\.isUnlocked).count }

    func load(in context: NSManagedObjectContext, languageManager: LanguageManager = .shared) {
        let progressSnapshot = PlayerProgressStore.shared.currentSnapshot()
        let request: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ROMLibraryEntry.lastPlayedAt, ascending: false),
            NSSortDescriptor(keyPath: \ROMLibraryEntry.dateAdded, ascending: false)
        ]

        do {
            let entries = try context.fetch(request)
            rebuild(from: entries, snapshot: progressSnapshot, languageManager: languageManager)
        } catch {
            print("Failed to load player stats: \(error)")
            rebuild(from: [], snapshot: progressSnapshot, languageManager: languageManager)
        }
    }

    private func rebuild(from entries: [ROMLibraryEntry], snapshot: PlayerProgressSnapshot, languageManager: LanguageManager) {
        let sessions = snapshot.sessions.sorted { $0.endTime > $1.endTime }
        let sessionSeconds = sessions.reduce(0) { $0 + $1.durationSeconds }
        let entrySeconds = Int(entries.reduce(Int64(0)) { $0 + $1.playtimeTotal })
        let totalSeconds = max(sessionSeconds, entrySeconds)
        let totalHours = Int(totalSeconds / 3600)
        totalHoursText = LocaleFormatting.shortDuration(seconds: totalSeconds, languageManager: languageManager)

        let playedEntries = entries.filter { $0.playtimeTotal > 0 || $0.lastPlayedAt != nil }
        let uniqueSessionGames = Set(sessions.map(\.gameID)).count
        gamesPlayedCount = max(uniqueSessionGames, playedEntries.count)
        totalSessions = sessions.isEmpty ? max(0, playedEntries.count + totalHours / 2) : sessions.count

        let maxSessionSeconds = sessions.map(\.durationSeconds).max() ?? 0
        let maxGameSeconds = Int(playedEntries.map(\.playtimeTotal).max() ?? 0)
        longestPlayText = Self.durationText(seconds: max(maxSessionSeconds, maxGameSeconds), languageManager: languageManager)

        if let firstSessionDate = sessions.map(\.startTime).min() {
            playerSinceText = L10n.format(
                "playerstats.player_since_format",
                firstSessionDate.formatted(date: .abbreviated, time: .omitted),
                table: "Screens",
                languageManager: languageManager
            )
        } else if let firstDate = entries.compactMap(\.dateAdded).min() {
            playerSinceText = L10n.format(
                "playerstats.player_since_format",
                firstDate.formatted(date: .abbreviated, time: .omitted),
                table: "Screens",
                languageManager: languageManager
            )
        } else {
            playerSinceText = L10n.string("playerstats.player_since_today", table: "Screens", languageManager: languageManager)
        }

        buildConsoleBreakdown(from: entries, sessions: sessions, totalSeconds: totalSeconds, languageManager: languageManager)
        favoriteSystemText = consoleBreakdown.first?.name ?? L10n.string("playerstats.none", table: "Screens", languageManager: languageManager)
        buildTopGames(from: playedEntries, languageManager: languageManager)
        buildAchievements(
            sessions: sessions,
            unlockedDates: snapshot.unlockedAchievementDates,
            fallbackPlayedGames: playedEntries.count,
            fallbackTotalPlaySeconds: totalSeconds,
            languageManager: languageManager
        )
        buildTimeline(from: entries, sessions: sessions, languageManager: languageManager)
        buildInsights(playedEntries: playedEntries, sessions: sessions, totalSeconds: totalSeconds, languageManager: languageManager)
    }

    private func buildConsoleBreakdown(from entries: [ROMLibraryEntry], sessions: [PlayerHistorySession], totalSeconds: Int, languageManager: LanguageManager) {
        let palette: [String: Color] = [
            "gb": .green,
            "gbc": .blue,
            "gba": .purple,
            "nds": .pink
        ]

        let groups: [String: Int]
        if !sessions.isEmpty {
            groups = Dictionary(grouping: sessions) { normalizedSystem($0.system) }
                .mapValues { items in
                    items.reduce(0) { $0 + $1.durationSeconds }
                }
        } else {
            groups = Dictionary(grouping: entries) { normalizedSystem($0.system) }
                .mapValues { items in
                    items.reduce(0) { $0 + Int($1.playtimeTotal) }
                }
        }

        consoleBreakdown = groups
            .map { system, secs in
                return ConsolePlayBreakdown(
                    id: system,
                    name: displaySystemName(system, languageManager: languageManager),
                    seconds: secs,
                    ratio: totalSeconds > 0 ? min(1, Double(secs) / Double(totalSeconds)) : 0,
                    color: palette[system] ?? AppColors.primary,
                    languageManager: languageManager
                )
            }
            .filter { $0.seconds > 0 }
            .sorted { $0.seconds > $1.seconds }
    }

    private func buildTopGames(from entries: [ROMLibraryEntry], languageManager: LanguageManager) {
        topGames = entries
            .sorted { $0.playtimeTotal > $1.playtimeTotal }
            .prefix(5)
            .compactMap { entry in
                guard let game = entry.toGame() else { return nil }
                return TopPlayedGame(
                    id: entry.objectID.uriRepresentation().absoluteString,
                    title: entry.title ?? L10n.string("common.unknown_game", table: "Screens", languageManager: languageManager),
                    systemLabel: displaySystemName(normalizedSystem(entry.system), languageManager: languageManager),
                    seconds: Int(entry.playtimeTotal),
                    game: game,
                    launchIssue: ROMCompatibilityService.shared.compatibility(for: entry).issue,
                    languageManager: languageManager
                )
            }
    }

    private func buildAchievements(
        sessions: [PlayerHistorySession],
        unlockedDates: [String: Date],
        fallbackPlayedGames: Int,
        fallbackTotalPlaySeconds: Int,
        languageManager: LanguageManager
    ) {
        let sessionCount = sessions.count
        let totalPlaySeconds = max(sessions.reduce(0) { $0 + $1.durationSeconds }, fallbackTotalPlaySeconds)
        let uniqueGames = max(Set(sessions.map(\.gameID)).count, fallbackPlayedGames)
        let colorsByID: [String: Color] = [
            "power-on": .blue,
            "first-hour": .green,
            "retro-fan": .orange,
            "dedicated-player": .purple,
            "game-sampler": .mint
        ]

        achievements = PlayerProgressStore.achievementDefinitions.map { definition in
            let currentValue: Int
            switch definition.metric {
            case .sessionCount:
                currentValue = sessionCount
            case .totalPlaySeconds:
                currentValue = totalPlaySeconds
            case .uniqueGamesPlayed:
                currentValue = uniqueGames
            }

            let progress = definition.target > 0
                ? min(1, max(0, Double(currentValue) / Double(definition.target)))
                : 1
            let unlockedDate = unlockedDates[definition.id]
            let unlocked = unlockedDate != nil || currentValue >= definition.target

            return PlayerAchievement(
                id: definition.id,
                title: definition.localizedTitle(languageManager: languageManager),
                detail: definition.localizedDetail(languageManager: languageManager),
                icon: definition.icon,
                color: colorsByID[definition.id] ?? AppColors.primary,
                progress: progress,
                isUnlocked: unlocked,
                unlockedDateText: unlockedDate.map {
                    L10n.format(
                        "playerstats.unlocked_on",
                        $0.formatted(date: .abbreviated, time: .omitted),
                        table: "Screens",
                        languageManager: languageManager
                    )
                }
            )
        }
    }

    private func buildTimeline(from entries: [ROMLibraryEntry], sessions: [PlayerHistorySession], languageManager: LanguageManager) {
        if !sessions.isEmpty {
            timeline = sessions
                .sorted { $0.endTime > $1.endTime }
                .prefix(10)
                .map { session in
                    let system = displaySystemName(normalizedSystem(session.system), languageManager: languageManager)
                    let systemLabel = system.isEmpty ? L10n.string("playerstats.unknown_system", table: "Screens", languageManager: languageManager) : system
                    return PlayerActivityEvent(
                        id: session.id.uuidString,
                        date: session.endTime,
                        icon: "gamecontroller.fill",
                        color: AppColors.primary,
                        title: L10n.format("playerstats.timeline.played", session.gameTitle, table: "Screens", languageManager: languageManager),
                        subtitle: L10n.format(
                            "playerstats.timeline.session_subtitle",
                            Self.durationText(seconds: session.durationSeconds, languageManager: languageManager),
                            systemLabel,
                            table: "Screens",
                            languageManager: languageManager
                        )
                    )
                }
            return
        }

        var events: [PlayerActivityEvent] = []
        for entry in entries {
            let title = entry.title ?? L10n.string("common.unknown_game", table: "Screens", languageManager: languageManager)
            if let lastPlayed = entry.lastPlayedAt {
                let totalText = LocaleFormatting.shortDuration(
                    seconds: Int(entry.playtimeTotal),
                    minimumMinutes: 1,
                    languageManager: languageManager
                )
                events.append(
                    PlayerActivityEvent(
                        id: "\(entry.objectID.uriRepresentation().absoluteString)-played",
                        date: lastPlayed,
                        icon: "gamecontroller.fill",
                        color: AppColors.primary,
                        title: L10n.format("playerstats.timeline.played", title, table: "Screens", languageManager: languageManager),
                        subtitle: L10n.format("playerstats.timeline.total_on_record", totalText, table: "Screens", languageManager: languageManager)
                    )
                )
            }
            if let imported = entry.dateAdded {
                events.append(
                    PlayerActivityEvent(
                        id: "\(entry.objectID.uriRepresentation().absoluteString)-imported",
                        date: imported,
                        icon: "square.and.arrow.down.fill",
                        color: AppColors.info,
                        title: L10n.format("playerstats.timeline.imported", title, table: "Screens", languageManager: languageManager),
                        subtitle: displaySystemName(normalizedSystem(entry.system), languageManager: languageManager)
                    )
                )
            }
        }

        timeline = events
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map { $0 }
    }

    private func buildInsights(playedEntries: [ROMLibraryEntry], sessions: [PlayerHistorySession], totalSeconds: Int, languageManager: LanguageManager) {
        var items: [String] = []

        if let topConsole = consoleBreakdown.first {
            items.append(L10n.format("playerstats.insight.top_console", topConsole.name, topConsole.hoursText, table: "Screens", languageManager: languageManager))
        }

        if let topGame = topGames.first {
            items.append(L10n.format("playerstats.insight.top_game", topGame.title, topGame.hoursText, table: "Screens", languageManager: languageManager))
        }

        if !sessions.isEmpty {
            let averageSession = totalSeconds / max(1, sessions.count)
            items.append(L10n.format("playerstats.insight.average_session", Self.durationText(seconds: averageSession, languageManager: languageManager), table: "Screens", languageManager: languageManager))
            let activeDays = Set(sessions.map { Calendar.current.startOfDay(for: $0.endTime) }).count
            items.append(
                L10n.format(
                    activeDays == 1 ? "playerstats.insight.active_days.one" : "playerstats.insight.active_days.other",
                    Int64(activeDays),
                    table: "Screens",
                    languageManager: languageManager
                )
            )
        } else if gamesPlayedCount > 0 {
            let average = totalSeconds / max(1, gamesPlayedCount)
            items.append(L10n.format("playerstats.insight.average_per_game", Self.durationText(seconds: average, languageManager: languageManager), table: "Screens", languageManager: languageManager))
        }

        let recentHours: [Int]
        if !sessions.isEmpty {
            recentHours = sessions.map { Calendar.current.component(.hour, from: $0.endTime) }
        } else {
            recentHours = playedEntries
                .compactMap(\.lastPlayedAt)
                .map { Calendar.current.component(.hour, from: $0) }
        }
        if !recentHours.isEmpty {
            let eveningCount = recentHours.filter { (18...23).contains($0) }.count
            let daytimeCount = recentHours.filter { (10...17).contains($0) }.count
            if eveningCount > daytimeCount {
                items.append(L10n.string("playerstats.insight.evening", table: "Screens", languageManager: languageManager))
            } else if daytimeCount > 0 {
                items.append(L10n.string("playerstats.insight.daytime", table: "Screens", languageManager: languageManager))
            }
        }

        insights = Array(items.prefix(4))
    }

    private func normalizedSystem(_ raw: String?) -> String {
        (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func displaySystemName(_ key: String, languageManager: LanguageManager) -> String {
        switch key {
        case "gb": return L10n.string("console.gb", languageManager: languageManager)
        case "gbc": return L10n.string("console.gbc", languageManager: languageManager)
        case "gba": return L10n.string("console.gba", languageManager: languageManager)
        case "nds": return L10n.string("console.nds", languageManager: languageManager)
        default: return key.uppercased()
        }
    }

    nonisolated static func durationText(seconds: Int, languageManager: LanguageManager = .shared) -> String {
        LocaleFormatting.shortDuration(seconds: seconds, languageManager: languageManager)
    }
}

struct ConsolePlayBreakdown: Identifiable {
    let id: String
    let name: String
    let seconds: Int
    let ratio: Double
    let color: Color
    let languageManager: LanguageManager

    var hoursText: String {
        LocaleFormatting.decimalHours(seconds: seconds, languageManager: languageManager)
    }
}

struct TopPlayedGame: Identifiable {
    let id: String
    let title: String
    let systemLabel: String
    let seconds: Int
    let game: Game
    let launchIssue: ROMLaunchIssue?
    let languageManager: LanguageManager

    var hoursText: String { PlayerStatsViewModel.durationText(seconds: seconds, languageManager: languageManager) }
}

struct PlayerAchievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let color: Color
    let progress: Double
    let isUnlocked: Bool
    let unlockedDateText: String?

    static func make(id: String, title: String, detail: String, icon: String, color: Color, current: Double, target: Double) -> PlayerAchievement {
        let ratio = target > 0 ? min(1, max(0, current / target)) : 1
        let unlocked = current >= target
        return PlayerAchievement(
            id: id,
            title: title,
            detail: detail,
            icon: icon,
            color: color,
            progress: ratio,
            isUnlocked: unlocked,
            unlockedDateText: unlocked ? L10n.string("playerstats.unlocked_local", table: "Screens") : nil
        )
    }
}

struct PlayerActivityEvent: Identifiable {
    let id: String
    let date: Date
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var relativeText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
