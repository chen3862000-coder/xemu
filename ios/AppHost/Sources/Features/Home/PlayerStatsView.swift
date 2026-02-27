import SwiftUI
import CoreData

struct PlayerStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = PlayerStatsViewModel()
    @State private var selectedGame: Game?
    @State private var launchErrorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        summaryHero
                        consoleBreakdownSection
                        topGamesSection
                        achievementsSection
                        timelineSection
                        insightsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 28)
                }
                .refreshable {
                    viewModel.load(in: viewContext)
                }
            }
            .navigationTitle("Your Gaming Stats")
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
                    Button("Close") { dismiss() }
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
            .alert("Unable to Open Game", isPresented: Binding(
                get: { launchErrorMessage != nil },
                set: { if !$0 { launchErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { launchErrorMessage = nil }
            } message: {
                Text(launchErrorMessage ?? "This game cannot be launched right now.")
            }
            .onAppear { viewModel.load(in: viewContext) }
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
                    Text("Player Profile")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(viewModel.playerSinceText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                }

                Spacer()
            }

            HStack(spacing: 12) {
                metricCard(title: "Hours Played", value: viewModel.totalHoursText, icon: "clock.fill", hero: true)
                metricCard(title: "Sessions", value: "\(viewModel.totalSessions)", icon: "bolt.fill", hero: true)
            }

            HStack(spacing: 12) {
                metricCard(title: "Games Played", value: "\(viewModel.gamesPlayedCount)", icon: "gamecontroller.fill")
                metricCard(title: "Longest Play", value: viewModel.longestPlayText, icon: "hourglass.bottomhalf.filled")
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
        sectionCard(title: "Where Your Time Went", trailing: nil) {
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
                        .frame(height: 9)
                    }
                }
            }
        }
    }

    private var topGamesSection: some View {
        sectionCard(title: "Top Games by Playtime", trailing: "\(viewModel.topGames.count)") {
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
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(AppColors.primary)
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
                                    Label("Unsupported Mapper", systemImage: "exclamationmark.triangle.fill")
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
        sectionCard(title: "Achievements", trailing: "\(viewModel.unlockedAchievementCount)/\(viewModel.achievements.count)") {
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
        sectionCard(title: "Recent Activity", trailing: nil) {
            if viewModel.timeline.isEmpty {
                emptyState("No recent activity yet")
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
        sectionCard(title: "Insights", trailing: nil) {
            if viewModel.insights.isEmpty {
                emptyState("Play a few more games to unlock insights")
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
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
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.surface.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
    @Published private(set) var consoleBreakdown: [ConsolePlayBreakdown] = []
    @Published private(set) var topGames: [TopPlayedGame] = []
    @Published private(set) var achievements: [PlayerAchievement] = []
    @Published private(set) var timeline: [PlayerActivityEvent] = []
    @Published private(set) var insights: [String] = []

    var unlockedAchievementCount: Int { achievements.filter(\.isUnlocked).count }

    func load(in context: NSManagedObjectContext) {
        let request: NSFetchRequest<ROMLibraryEntry> = ROMLibraryEntry.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \ROMLibraryEntry.lastPlayedAt, ascending: false),
            NSSortDescriptor(keyPath: \ROMLibraryEntry.dateAdded, ascending: false)
        ]

        do {
            let entries = try context.fetch(request)
            rebuild(from: entries)
        } catch {
            print("Failed to load player stats: \(error)")
            rebuild(from: [])
        }
    }

    private func rebuild(from entries: [ROMLibraryEntry]) {
        let totalSeconds = entries.reduce(Int64(0)) { $0 + $1.playtimeTotal }
        let totalHours = Int(totalSeconds / 3600)
        totalHoursText = totalHours > 0 ? "\(totalHours)h" : "0h"

        let playedEntries = entries.filter { $0.playtimeTotal > 0 || $0.lastPlayedAt != nil }
        gamesPlayedCount = playedEntries.count
        totalSessions = max(0, playedEntries.count + totalHours / 2) // estimated until session logging lands

        let maxGameSeconds = Int(playedEntries.map(\.playtimeTotal).max() ?? 0)
        longestPlayText = Self.durationText(seconds: maxGameSeconds)

        if let firstDate = entries.compactMap(\.dateAdded).min() {
            playerSinceText = "Player since \(firstDate.formatted(date: .abbreviated, time: .omitted))"
        } else {
            playerSinceText = "Player since today"
        }

        buildConsoleBreakdown(from: entries, totalSeconds: Int(totalSeconds))
        buildTopGames(from: playedEntries)
        buildAchievements(from: entries, playedEntries: playedEntries, totalHours: totalHours, maxGameSeconds: maxGameSeconds)
        buildTimeline(from: entries)
        buildInsights(from: entries, playedEntries: playedEntries, totalSeconds: Int(totalSeconds))
    }

    private func buildConsoleBreakdown(from entries: [ROMLibraryEntry], totalSeconds: Int) {
        let groups = Dictionary(grouping: entries) { normalizedSystem($0.system) }
        let palette: [String: Color] = [
            "gb": .green,
            "gbc": .blue,
            "gba": .purple,
            "nds": .pink
        ]

        consoleBreakdown = groups
            .map { system, items in
                let secs = items.reduce(0) { $0 + Int($1.playtimeTotal) }
                return ConsolePlayBreakdown(
                    id: system,
                    name: displaySystemName(system),
                    seconds: secs,
                    ratio: totalSeconds > 0 ? min(1, Double(secs) / Double(totalSeconds)) : 0,
                    color: palette[system] ?? AppColors.primary
                )
            }
            .filter { $0.seconds > 0 }
            .sorted { $0.seconds > $1.seconds }
    }

    private func buildTopGames(from entries: [ROMLibraryEntry]) {
        topGames = entries
            .sorted { $0.playtimeTotal > $1.playtimeTotal }
            .prefix(5)
            .compactMap { entry in
                guard let game = entry.toGame() else { return nil }
                return TopPlayedGame(
                    id: entry.objectID.uriRepresentation().absoluteString,
                    title: entry.title ?? "Unknown Game",
                    systemLabel: displaySystemName(normalizedSystem(entry.system)),
                    seconds: Int(entry.playtimeTotal),
                    game: game,
                    launchIssue: ROMCompatibilityService.shared.compatibility(for: entry).issue
                )
            }
    }

    private func buildAchievements(from entries: [ROMLibraryEntry], playedEntries: [ROMLibraryEntry], totalHours: Int, maxGameSeconds: Int) {
        let consoleCount = Set(entries.map { normalizedSystem($0.system) }.filter { !$0.isEmpty }).count
        let playedGamesCount = playedEntries.count
        let importedGamesCount = entries.count

        achievements = [
            PlayerAchievement.make(id: "first-hour", title: "First Hour", detail: "Play for 1 hour total", icon: "clock.badge.checkmark", color: .green, current: Double(totalHours), target: 1),
            PlayerAchievement.make(id: "ten-hours", title: "10 Hours Milestone", detail: "Reach 10 hours total playtime", icon: "medal.fill", color: .orange, current: Double(totalHours), target: 10),
            PlayerAchievement.make(id: "fifty-hours", title: "50 Hours Veteran", detail: "Reach 50 total hours", icon: "trophy.fill", color: .yellow, current: Double(totalHours), target: 50),
            PlayerAchievement.make(id: "explorer", title: "Console Explorer", detail: "Play 3 different systems", icon: "gamecontroller.circle.fill", color: .blue, current: Double(consoleCount), target: 3),
            PlayerAchievement.make(id: "collector", title: "Library Starter", detail: "Import 10 games", icon: "shippingbox.fill", color: .purple, current: Double(importedGamesCount), target: 10),
            PlayerAchievement.make(id: "marathon", title: "Marathon Play", detail: "Play one game for 2 hours", icon: "flame.fill", color: .red, current: Double(maxGameSeconds), target: 7200),
            PlayerAchievement.make(id: "sampler", title: "Game Sampler", detail: "Play 5 different games", icon: "sparkles", color: .mint, current: Double(playedGamesCount), target: 5)
        ]
    }

    private func buildTimeline(from entries: [ROMLibraryEntry]) {
        var events: [PlayerActivityEvent] = []
        for entry in entries {
            let title = entry.title ?? "Unknown Game"
            if let lastPlayed = entry.lastPlayedAt {
                let mins = max(1, Int(entry.playtimeTotal) / 60)
                events.append(
                    PlayerActivityEvent(
                        id: "\(entry.objectID.uriRepresentation().absoluteString)-played",
                        date: lastPlayed,
                        icon: "gamecontroller.fill",
                        color: AppColors.primary,
                        title: "Played \(title)",
                        subtitle: mins > 59 ? "\(mins / 60)h total on record" : "\(mins)m total on record"
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
                        title: "Imported \(title)",
                        subtitle: displaySystemName(normalizedSystem(entry.system))
                    )
                )
            }
        }

        timeline = events
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map { $0 }
    }

    private func buildInsights(from entries: [ROMLibraryEntry], playedEntries: [ROMLibraryEntry], totalSeconds: Int) {
        var items: [String] = []

        if let topConsole = consoleBreakdown.first {
            items.append("You spend most of your time on \(topConsole.name) (\(topConsole.hoursText)).")
        }

        if let topGame = topGames.first {
            items.append("Your top game is \(topGame.title) with \(topGame.hoursText) played.")
        }

        if gamesPlayedCount > 0 {
            let average = totalSeconds / max(1, gamesPlayedCount)
            items.append("Average playtime per game is \(Self.durationText(seconds: average)).")
        }

        let recentHours = playedEntries
            .compactMap(\.lastPlayedAt)
            .map { Calendar.current.component(.hour, from: $0) }
        if !recentHours.isEmpty {
            let eveningCount = recentHours.filter { (18...23).contains($0) }.count
            let daytimeCount = recentHours.filter { (10...17).contains($0) }.count
            if eveningCount > daytimeCount {
                items.append("You usually play in the evening.")
            } else if daytimeCount > 0 {
                items.append("You often play during the day.")
            }
        }

        insights = Array(items.prefix(4))
    }

    private func normalizedSystem(_ raw: String?) -> String {
        (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func displaySystemName(_ key: String) -> String {
        switch key {
        case "gb": return "Game Boy"
        case "gbc": return "Game Boy Color"
        case "gba": return "Game Boy Advance"
        case "nds": return "Nintendo DS"
        default: return key.uppercased()
        }
    }

    nonisolated static func durationText(seconds: Int) -> String {
        let s = max(0, seconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

struct ConsolePlayBreakdown: Identifiable {
    let id: String
    let name: String
    let seconds: Int
    let ratio: Double
    let color: Color

    var hoursText: String {
        let hours = Double(seconds) / 3600.0
        if hours >= 1 { return String(format: "%.1fh", hours) }
        return "\(max(1, seconds / 60))m"
    }
}

struct TopPlayedGame: Identifiable {
    let id: String
    let title: String
    let systemLabel: String
    let seconds: Int
    let game: Game
    let launchIssue: ROMLaunchIssue?

    var hoursText: String { PlayerStatsViewModel.durationText(seconds: seconds) }
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
            unlockedDateText: unlocked ? "Unlocked locally" : nil
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
