import CoreData
import Foundation

final class PlayInsightsStore {
    static let shared = PlayInsightsStore()

    private struct Snapshot: Codable {
        var records: [PlayInsightsStoredGameRecord] = []
    }

    struct SessionUpdate: Sendable {
        var gameId: String
        var gameTitle: String
        var system: String
        var supportedGame: PlayInsightsSupportedGame
        var startedAt: Date
        var endedAt: Date
        var durationSeconds: Int
        var deaths: Int
        var damageEvents: Int
        var snapshot: GameSpecificTelemetrySnapshot?
        var latestLocationSummary: String?
    }

    struct LiveSnapshotUpdate: Sendable {
        var gameId: String
        var gameTitle: String
        var system: String
        var supportedGame: PlayInsightsSupportedGame
        var snapshot: GameSpecificTelemetrySnapshot
        var latestLocationSummary: String?
    }

    private let queue = DispatchQueue(label: "PlayInsightsStore.queue")
    private let fileURL: URL
    private var snapshot: Snapshot

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL()
        self.snapshot = Self.loadSnapshot(from: self.fileURL)
    }

    func recordSession(_ update: SessionUpdate) {
        queue.sync {
            let stats = existingRecord(for: update.gameId)?.eventStats ?? GameEventStatsSummary(gameId: update.gameId)
            let priorSessions = existingRecord(for: update.gameId)?.sessions ?? []
            let session = PlayInsightsSessionRecord(
                startedAt: update.startedAt,
                endedAt: update.endedAt,
                durationSeconds: update.durationSeconds,
                deaths: update.deaths,
                damageEvents: update.damageEvents
            )

            var sessions = priorSessions + [session]
            if sessions.count > 60 {
                sessions.removeFirst(sessions.count - 60)
            }

            let totalDeaths = (stats.totalDeaths ?? 0) + update.deaths
            let totalDamage = (stats.totalDamageEvents ?? 0) + update.damageEvents
            let bestSessionDeaths = sessions.map(\.deaths).min() ?? update.deaths
            let averageDamage = sessions.isEmpty ? 0 : Double(sessions.reduce(0) { $0 + $1.damageEvents }) / Double(sessions.count)

            let record = PlayInsightsStoredGameRecord(
                gameId: update.gameId,
                gameTitle: update.gameTitle,
                system: update.system,
                supportedGame: update.supportedGame,
                eventStats: GameEventStatsSummary(
                    gameId: update.gameId,
                    totalDeaths: totalDeaths,
                    totalDamageEvents: totalDamage,
                    currentSessionDeaths: update.deaths,
                    currentSessionDamageEvents: update.damageEvents,
                    lastSessionDeaths: sessions.dropLast().last?.deaths,
                    lastSessionDamageEvents: sessions.dropLast().last?.damageEvents,
                    bestSessionDeaths: bestSessionDeaths,
                    averageDamagePerSession: averageDamage,
                    lastPlayedAt: update.endedAt
                ),
                sessions: sessions,
                latestSnapshot: update.snapshot,
                latestLocationSummary: update.latestLocationSummary,
                updatedAt: update.endedAt
            )

            upsert(record)
            persistSnapshot(snapshot, to: fileURL)
        }
    }

    func refreshLiveSnapshot(_ update: LiveSnapshotUpdate) {
        queue.sync {
            let existing = existingRecord(for: update.gameId)
            if existing?.latestSnapshot == update.snapshot,
               existing?.latestLocationSummary == update.latestLocationSummary,
               existing?.gameTitle == update.gameTitle,
               existing?.system == update.system {
                return
            }

            let record = PlayInsightsStoredGameRecord(
                gameId: update.gameId,
                gameTitle: update.gameTitle,
                system: update.system,
                supportedGame: update.supportedGame,
                eventStats: existing?.eventStats ?? GameEventStatsSummary(gameId: update.gameId),
                sessions: existing?.sessions ?? [],
                latestSnapshot: update.snapshot,
                latestLocationSummary: update.latestLocationSummary,
                updatedAt: update.snapshot.timestamp
            )

            upsert(record)
            persistSnapshot(snapshot, to: fileURL)
        }
    }

    func summary(for gameId: String) -> GamePlayInsightsSummary? {
        queue.sync {
            guard let record = existingRecord(for: gameId) else { return nil }
            return PlayInsightsSummaryBuilder.makeSummary(from: record, allRecords: snapshot.records)
        }
    }

    func continuePlayingSummary(for gameId: String) -> ContinuePlayingSmartSummary? {
        queue.sync {
            guard let record = existingRecord(for: gameId) else { return nil }
            return ContinuePlayingSummaryBuilder.makeSummary(from: record, allRecords: snapshot.records)
        }
    }

    func globalSummary(for entries: [ROMLibraryEntry]) -> GlobalPlaySummary {
        queue.sync {
            let playedRecords = snapshot.records.filter { record in
                entries.contains { $0.checksum == record.gameId }
            }
            let summaries = playedRecords.map { PlayInsightsSummaryBuilder.makeSummary(from: $0, allRecords: snapshot.records) }
            let activeRuns = playedRecords
                .compactMap { record -> ActiveRunItem? in
                    guard let summary = summaries.first(where: { $0.gameId == record.gameId }),
                          let primary = summary.currentRunPrimary,
                          let secondary = summary.currentRunSecondary else { return nil }
                    return ActiveRunItem(
                        gameId: record.gameId,
                        gameTitle: record.gameTitle,
                        primaryText: primary,
                        secondaryText: secondary,
                        badgeText: summary.currentRunBadge,
                        lastPlayedAt: record.eventStats.lastPlayedAt
                    )
                }
                .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }

            let hardestGames = playedRecords
                .sorted {
                    let lhsDeaths = $0.eventStats.totalDeaths ?? -1
                    let rhsDeaths = $1.eventStats.totalDeaths ?? -1
                    if lhsDeaths != rhsDeaths { return lhsDeaths > rhsDeaths }
                    return ($0.eventStats.totalDamageEvents ?? 0) > ($1.eventStats.totalDamageEvents ?? 0)
                }
                .prefix(3)
                .enumerated()
                .map { offset, record in
                    HardestGameItem(
                        gameId: record.gameId,
                        gameTitle: record.gameTitle,
                        primaryMetricText: hardestMetricText(record.eventStats),
                        badgeText: hardestBadgeText(rank: offset + 1, record: record),
                        rank: offset + 1
                    )
                }

            let supportedGameCards = playedRecords
                .compactMap { record -> SupportedGameCardItem? in
                    guard let summary = summaries.first(where: { $0.gameId == record.gameId }) else { return nil }
                    let progress = summary.progressPrimaryValue
                        ?? summary.currentRunPrimary
                        ?? PlayInsightsL10n.string("playinsights.progress.progress_tracked", "Progress tracked")
                    let performanceLine: String
                    if let deaths = record.eventStats.totalDeaths, deaths > 0 {
                        let damage = record.eventStats.totalDamageEvents ?? 0
                        performanceLine = PlayInsightsL10n.format(
                            "playinsights.global.performance_line.deaths_damage",
                            "Deaths: %@ • Damage: %@",
                            "\(deaths)",
                            "\(damage)"
                        )
                    } else if let damage = record.eventStats.totalDamageEvents, damage > 0 {
                        performanceLine = PlayInsightsL10n.format(
                            "playinsights.global.performance_line.damage_only",
                            "Damage Events: %@",
                            "\(damage)"
                        )
                    } else {
                        performanceLine = summary.progressSecondaryValue
                            ?? PlayInsightsL10n.string("playinsights.global.performance_line.current_run_available", "Current run available")
                    }
                    let insight = summary.performanceInsightText
                        ?? summary.currentRunSecondary
                        ?? PlayInsightsL10n.string("playinsights.global.insight.progress_tracked", "Progress is being tracked.")
                    return SupportedGameCardItem(
                        gameId: record.gameId,
                        gameTitle: record.gameTitle,
                        progressLine: progress,
                        performanceLine: performanceLine,
                        insightLine: insight,
                        lastPlayedAt: record.eventStats.lastPlayedAt
                    )
                }
                .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }

            let heroSummaryText = heroSummary(records: playedRecords)

            return GlobalPlaySummary(
                totalDeaths: playedRecords.reduce(0) { $0 + ($1.eventStats.totalDeaths ?? 0) },
                totalDamageEvents: playedRecords.reduce(0) { $0 + ($1.eventStats.totalDamageEvents ?? 0) },
                supportedGamesPlayed: playedRecords.count,
                heroSummaryText: heroSummaryText,
                activeRuns: Array(activeRuns.prefix(5)),
                hardestGames: hardestGames,
                supportedGameCards: supportedGameCards,
                updatedAt: Date()
            )
        }
    }

    #if DEBUG
    func resetForTesting() {
        queue.sync {
            snapshot = Snapshot()
            persistSnapshot(snapshot, to: fileURL)
        }
    }
    #endif

    private func existingRecord(for gameId: String) -> PlayInsightsStoredGameRecord? {
        snapshot.records.first { $0.gameId == gameId }
    }

    private func upsert(_ record: PlayInsightsStoredGameRecord) {
        if let index = snapshot.records.firstIndex(where: { $0.gameId == record.gameId }) {
            snapshot.records[index] = record
        } else {
            snapshot.records.append(record)
        }
    }

    private func heroSummary(records: [PlayInsightsStoredGameRecord]) -> String {
        if records.count >= 2, records.filter({ $0.latestSnapshot != nil }).count >= 2 {
            return PlayInsightsL10n.string("playinsights.global.hero.active_progressing", "You’re actively progressing across several games.")
        }
        if records.contains(where: { $0.supportedGame.prefersExplorationLanguage }) &&
            records.filter({ $0.supportedGame.prefersExplorationLanguage }).count >= max(1, records.count / 2) {
            return PlayInsightsL10n.string("playinsights.global.hero.exploration_momentum", "Your strongest momentum right now is in exploration-heavy games.")
        }
        if records.contains(where: { PlayInsightsSummaryBuilder.makeComparison(record: $0, allRecords: records).isImproving }) {
            return PlayInsightsL10n.string("playinsights.global.hero.more_consistent", "You’ve become more consistent lately.")
        }
        if records.contains(where: { !($0.supportedGame.prefersExplorationLanguage) }) {
            return PlayInsightsL10n.string("playinsights.global.hero.platformers_challenge", "Platformers remain your biggest challenge.")
        }
        return PlayInsightsL10n.string("playinsights.global.hero.meaningful_progress", "Your supported games are tracking meaningful play progress.")
    }

    private func hardestMetricText(_ stats: GameEventStatsSummary) -> String {
        if let deaths = stats.totalDeaths, deaths > 0 {
            return PlayInsightsL10n.format("playinsights.global.hardest_metric.deaths", "%@ deaths", "\(deaths)")
        }
        return PlayInsightsL10n.format(
            "playinsights.global.hardest_metric.damage_events",
            "%@ damage events",
            "\((stats.totalDamageEvents ?? 0))"
        )
    }

    private func hardestBadgeText(rank: Int, record: PlayInsightsStoredGameRecord) -> String {
        if rank == 1 { return PlayInsightsL10n.string("playinsights.global.hardest_badge.highest_total", "Highest total") }
        if PlayInsightsSummaryBuilder.makeComparison(record: record, allRecords: snapshot.records).isImproving {
            return PlayInsightsL10n.string("playinsights.global.hardest_badge.improving", "Improving")
        }
        return PlayInsightsL10n.string("playinsights.global.hardest_badge.challenging", "Challenging")
    }

    private static func defaultFileURL() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = appSupport.appendingPathComponent("AppHost", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("play_insights_v1.json", isDirectory: false)
    }

    private static func loadSnapshot(from url: URL) -> Snapshot {
        guard let data = try? Data(contentsOf: url) else { return Snapshot() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(Snapshot.self, from: data)) ?? Snapshot()
    }

    private func persistSnapshot(_ snapshot: Snapshot, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: url, options: [.atomic])
    }
}
