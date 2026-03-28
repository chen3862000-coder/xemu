import Foundation

protocol GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary?
    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary?
    func makePerformanceInsight(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String?
    func makePlayStyle(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> PlayStyleSummary?
}

struct PlayInsightsComparison: Equatable, Sendable {
    var isImproving: Bool
    var isHardTitle: Bool
    var hasRiskyPattern: Bool
    var isExplorationLed: Bool
}

enum PlayInsightsFormatterFactory {
    static func formatter(for game: PlayInsightsSupportedGame) -> GameTelemetryFormatter {
        switch game {
        case .superMarioAdvance2: return SMA2TelemetryFormatter()
        case .superMarioAdvance4: return SMA4TelemetryFormatter()
        case .metroidFusion: return MetroidFusionTelemetryFormatter()
        case .castlevaniaAriaOfSorrow: return AriaOfSorrowTelemetryFormatter()
        case .castlevaniaCircleOfTheMoon: return CircleOfTheMoonTelemetryFormatter()
        case .castlevaniaHarmonyOfDissonance: return HarmonyOfDissonanceTelemetryFormatter()
        }
    }
}

enum PlayInsightsL10n {
    static func string(_ key: String, _ fallback: String) -> String {
        L10n.string(key, table: "Screens", fallback: fallback)
    }

    static func format(_ key: String, _ fallback: String, _ arguments: CVarArg...) -> String {
        let format = string(key, fallback)
        return String(format: format, locale: LanguageManager.shared.formattingLocale, arguments: arguments)
    }
}

enum PlayInsightsSummaryBuilder {
    static func makeSummary(
        from record: PlayInsightsStoredGameRecord,
        allRecords: [PlayInsightsStoredGameRecord]
    ) -> GamePlayInsightsSummary {
        let formatter = PlayInsightsFormatterFactory.formatter(for: record.supportedGame)
        let comparison = makeComparison(record: record, allRecords: allRecords)
        let progress = formatter.makeProgressSummary(snapshot: record.latestSnapshot, stats: record.eventStats)
        let currentRun = formatter.makeCurrentRunSummary(snapshot: record.latestSnapshot, stats: record.eventStats)
        let insight = formatter.makePerformanceInsight(
            snapshot: record.latestSnapshot,
            stats: record.eventStats,
            comparison: comparison
        )
        let playStyle = formatter.makePlayStyle(
            snapshot: record.latestSnapshot,
            stats: record.eventStats,
            comparison: comparison
        )

        let deathsCardVisible = (record.eventStats.totalDeaths ?? 0) > 0 || record.supportedGame.supportsEventMetrics
        let damageCardVisible = (record.eventStats.totalDamageEvents ?? 0) > 0 || record.supportedGame.supportsEventMetrics
        let progressCardVisible = progress != nil
        let insightCardVisible = insight != nil
        let styleCardVisible = playStyle != nil
        let visibleCardCount = [deathsCardVisible, damageCardVisible, progressCardVisible, insightCardVisible, styleCardVisible]
            .filter { $0 }
            .count

        return GamePlayInsightsSummary(
            gameId: record.gameId,
            playInsightsEnabled: visibleCardCount >= 2,
            currentRunEnabled: currentRun != nil,
            deathsPrimaryValue: deathsCardVisible ? string(record.eventStats.totalDeaths ?? 0) : nil,
            deathsSecondaryLine1: deathsCardVisible
                ? PlayInsightsL10n.format(
                    "playinsights.metric.this_session",
                    "This Session: %@",
                    string(record.eventStats.currentSessionDeaths ?? 0)
                )
                : nil,
            deathsSecondaryLine2: deathsCardVisible
                ? PlayInsightsL10n.format(
                    "playinsights.metric.best_session",
                    "Best Session: %@",
                    string(record.eventStats.bestSessionDeaths ?? 0)
                )
                : nil,
            deathsChip: deathsCardVisible ? deathsChip(stats: record.eventStats, comparison: comparison) : nil,
            damagePrimaryValue: damageCardVisible ? string(record.eventStats.totalDamageEvents ?? 0) : nil,
            damageSecondaryLine1: damageCardVisible
                ? PlayInsightsL10n.format(
                    "playinsights.metric.this_session",
                    "This Session: %@",
                    string(record.eventStats.currentSessionDamageEvents ?? 0)
                )
                : nil,
            damageSecondaryLine2: damageCardVisible
                ? PlayInsightsL10n.format(
                    "playinsights.metric.avg_per_session",
                    "Avg / Session: %@",
                    averageDamageText(record.eventStats.averageDamagePerSession)
                )
                : nil,
            damageChip: damageCardVisible ? damageChip(stats: record.eventStats, comparison: comparison) : nil,
            progressPrimaryValue: progress?.primary,
            progressSecondaryValue: progress?.secondary,
            performanceInsightText: insight,
            playStyleTitle: playStyle?.title,
            playStyleBullet1: playStyle?.bullet1,
            playStyleBullet2: playStyle?.bullet2,
            currentRunPrimary: currentRun?.primary,
            currentRunSecondary: currentRun?.secondary,
            currentRunBadge: currentRun?.badge,
            lastPlayedAt: record.eventStats.lastPlayedAt,
            updatedAt: record.updatedAt
        )
    }

    static func makeComparison(
        record: PlayInsightsStoredGameRecord,
        allRecords: [PlayInsightsStoredGameRecord]
    ) -> PlayInsightsComparison {
        let sessions = record.sessions.suffix(4)
        let previousSessions = record.sessions.dropLast().suffix(3)
        let recentDeaths = sessions.reduce(0) { $0 + $1.deaths }
        let previousDeaths = previousSessions.reduce(0) { $0 + $1.deaths }
        let recentDamage = sessions.reduce(0) { $0 + $1.damageEvents }
        let previousDamage = previousSessions.reduce(0) { $0 + $1.damageEvents }
        let totals = allRecords.map { max($0.eventStats.totalDeaths ?? 0, ($0.eventStats.totalDamageEvents ?? 0) / 2) }
        let hardThreshold = totals.sorted().dropFirst(max(0, totals.count - 2)).first ?? 0
        let currentDifficulty = max(record.eventStats.totalDeaths ?? 0, (record.eventStats.totalDamageEvents ?? 0) / 2)
        let progressFields = record.latestSnapshot?.payloadJson ?? [:]
        let progressSignal = progressFields["visitedAreas", default: 0] > 0 || progressFields["area", default: 0] > 0
        let riskyPattern = (record.eventStats.currentSessionDamageEvents ?? 0) >= max(6, (record.eventStats.currentSessionDeaths ?? 0) * 2)

        return PlayInsightsComparison(
            isImproving: (previousDeaths > 0 && recentDeaths < previousDeaths) || (previousDamage > 0 && recentDamage < previousDamage),
            isHardTitle: currentDifficulty >= hardThreshold && currentDifficulty > 0,
            hasRiskyPattern: riskyPattern,
            isExplorationLed: progressSignal && (record.eventStats.currentSessionDeaths ?? 0) <= 1
        )
    }

    private static func string(_ value: Int) -> String { "\(value)" }

    private static func averageDamageText(_ value: Double?) -> String {
        guard let value else { return "0" }
        return "\(Int(value.rounded()))"
    }

    private static func deathsChip(stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String? {
        if comparison.isImproving { return PlayInsightsL10n.string("playinsights.chip.improving", "Improving") }
        if (stats.currentSessionDeaths ?? 0) >= 6 { return PlayInsightsL10n.string("playinsights.chip.struggling", "Struggling") }
        if comparison.hasRiskyPattern && (stats.currentSessionDeaths ?? 0) >= 3 {
            return PlayInsightsL10n.string("playinsights.chip.high_risk", "High Risk")
        }
        return PlayInsightsL10n.string("playinsights.chip.stable", "Stable")
    }

    private static func damageChip(stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String? {
        if comparison.isImproving { return PlayInsightsL10n.string("playinsights.chip.controlled", "Controlled") }
        if comparison.hasRiskyPattern { return PlayInsightsL10n.string("playinsights.chip.high_pressure", "High Pressure") }
        if (stats.currentSessionDamageEvents ?? 0) <= 2 {
            return PlayInsightsL10n.string("playinsights.chip.low_pressure", "Low Pressure")
        }
        return PlayInsightsL10n.string("playinsights.chip.controlled", "Controlled")
    }
}

private struct SMA2TelemetryFormatter: GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary? {
        guard let snapshot else { return nil }
        let map = snapshot.payloadJson["map", default: 0]
        let level = snapshot.payloadJson["level", default: 0]
        return ProgressSummary(
            primary: sma2MapName(map),
            secondary: PlayInsightsL10n.format("playinsights.progress.stage_format", "Stage %@", sma2StageLabel(level))
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        guard let snapshot else { return nil }
        let map = snapshot.payloadJson["map", default: 0]
        let level = snapshot.payloadJson["level", default: 0]
        return CurrentRunSummary(
            primary: "\(sma2MapName(map)) • \(PlayInsightsL10n.format("playinsights.progress.stage_format", "Stage %@", sma2StageLabel(level)))",
            secondary: PlayInsightsL10n.string("playinsights.current_run.level_in_progress", "Level in progress"),
            badge: PlayInsightsL10n.string("playinsights.badge.platforming", "Platforming")
        )
    }

    func makePerformanceInsight(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String? {
        if comparison.isImproving {
            return PlayInsightsL10n.string("playinsights.insight.improving_recent", "You’re improving in recent sessions.")
        }
        if comparison.isHardTitle {
            return PlayInsightsL10n.string("playinsights.insight.harder_games", "This is still one of your harder games.")
        }
        if comparison.hasRiskyPattern {
            return PlayInsightsL10n.string("playinsights.insight.risky_sections", "You tend to push forward through risky sections.")
        }
        return PlayInsightsL10n.string("playinsights.insight.progress_tracked_recent", "Your progress is being tracked across recent sessions.")
    }

    func makePlayStyle(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> PlayStyleSummary? {
        if comparison.hasRiskyPattern {
            return PlayStyleSummary(
                title: PlayInsightsL10n.string("playinsights.style.risk_taker.title", "Risk Taker"),
                bullet1: PlayInsightsL10n.string("playinsights.style.risk_taker.body", "Fast progress with higher damage pressure."),
                bullet2: nil
            )
        }
        if (stats.totalDamageEvents ?? 0) <= max(3, stats.totalDeaths ?? 0) {
            return PlayStyleSummary(
                title: PlayInsightsL10n.string("playinsights.style.precision_player.title", "Precision Player"),
                bullet1: PlayInsightsL10n.string("playinsights.style.precision_player.body", "Precise control with minimal damage taken."),
                bullet2: nil
            )
        }
        return nil
    }
}

private struct SMA4TelemetryFormatter: GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary? {
        guard let snapshot else { return nil }
        let world = max(1, Int(snapshot.payloadJson["world", default: 1]))
        return ProgressSummary(
            primary: PlayInsightsL10n.format("playinsights.progress.world_format", "World %@", "\(world)"),
            secondary: PlayInsightsL10n.string("playinsights.progress.overworld_tracked", "Overworld progress tracked")
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        guard let snapshot else { return nil }
        let world = max(1, Int(snapshot.payloadJson["world", default: 1]))
        return CurrentRunSummary(
            primary: "\(PlayInsightsL10n.format("playinsights.progress.world_format", "World %@", "\(world)")) • \(PlayInsightsL10n.string("playinsights.current_run.overworld", "Overworld"))",
            secondary: PlayInsightsL10n.string("playinsights.current_run.map_node_tracked", "Current map node tracked"),
            badge: PlayInsightsL10n.string("playinsights.badge.route_active", "Route active")
        )
    }

    func makePerformanceInsight(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String? {
        if comparison.isHardTitle { return PlayInsightsL10n.string("playinsights.insight.remains_hardest", "This remains one of your hardest games.") }
        if comparison.isImproving { return PlayInsightsL10n.string("playinsights.insight.more_consistent", "Your recent runs look more consistent.") }
        if comparison.hasRiskyPattern { return PlayInsightsL10n.string("playinsights.insight.risky_sections", "You tend to push forward through risky sections.") }
        return PlayInsightsL10n.string("playinsights.insight.progress_tracked_recent", "Your progress is being tracked across recent sessions.")
    }

    func makePlayStyle(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> PlayStyleSummary? {
        if comparison.hasRiskyPattern {
            return PlayStyleSummary(
                title: PlayInsightsL10n.string("playinsights.style.aggressive_mover.title", "Aggressive Mover"),
                bullet1: PlayInsightsL10n.string("playinsights.style.aggressive_mover.body", "Forward momentum stays high through rough sections."),
                bullet2: nil
            )
        }
        return nil
    }
}

private struct MetroidFusionTelemetryFormatter: GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary? {
        guard let snapshot else { return nil }
        let area = max(1, Int(snapshot.payloadJson["area", default: 1]))
        return ProgressSummary(
            primary: PlayInsightsL10n.format("playinsights.progress.sector_format", "Sector %@", "\(area)"),
            secondary: PlayInsightsL10n.string("playinsights.progress.room_map_tracked", "Room and map position tracked")
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        guard let snapshot else { return nil }
        let area = max(1, Int(snapshot.payloadJson["area", default: 1]))
        return CurrentRunSummary(
            primary: "\(PlayInsightsL10n.format("playinsights.progress.sector_format", "Sector %@", "\(area)")) • \(PlayInsightsL10n.string("playinsights.current_run.room_tracked", "Room tracked"))",
            secondary: PlayInsightsL10n.string("playinsights.current_run.map_position_available", "Map position available"),
            badge: PlayInsightsL10n.string("playinsights.badge.exploration", "Exploration")
        )
    }

    func makePerformanceInsight(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String? {
        if comparison.isImproving { return PlayInsightsL10n.string("playinsights.insight.improving_recent", "You’re improving in recent sessions.") }
        if comparison.isExplorationLed { return PlayInsightsL10n.string("playinsights.insight.steady_exploration", "Your recent runs are focused on steady exploration.") }
        if comparison.isHardTitle { return PlayInsightsL10n.string("playinsights.insight.remains_hardest", "This remains one of your hardest games.") }
        return PlayInsightsL10n.string("playinsights.insight.progress_tracked_recent", "Your progress is being tracked across recent sessions.")
    }

    func makePlayStyle(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> PlayStyleSummary? {
        if comparison.isExplorationLed {
            return PlayStyleSummary(
                title: PlayInsightsL10n.string("playinsights.style.explorer.title", "Explorer"),
                bullet1: PlayInsightsL10n.string("playinsights.style.explorer.sector_body", "Steady sector discovery keeps progress moving."),
                bullet2: nil
            )
        }
        if (stats.totalDeaths ?? 0) >= 8 {
            return PlayStyleSummary(
                title: PlayInsightsL10n.string("playinsights.style.persistent_challenger.title", "Persistent Challenger"),
                bullet1: PlayInsightsL10n.string("playinsights.style.persistent_challenger.body", "You keep pushing through repeat attempts."),
                bullet2: nil
            )
        }
        return nil
    }
}

private struct AriaOfSorrowTelemetryFormatter: GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary? {
        guard let snapshot else { return nil }
        return ProgressSummary(
            primary: PlayInsightsL10n.format("playinsights.progress.visited_areas_format", "Visited %@ areas", "\(visitedAreas(snapshot))"),
            secondary: PlayInsightsL10n.string("playinsights.progress.castle_exploration_tracked", "Castle exploration tracked")
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        guard let snapshot else { return nil }
        return CurrentRunSummary(
            primary: PlayInsightsL10n.string("playinsights.current_run.exploration_active", "Exploration active"),
            secondary: PlayInsightsL10n.format("playinsights.progress.visited_areas_format", "Visited %@ areas", "\(visitedAreas(snapshot))"),
            badge: PlayInsightsL10n.string("playinsights.style.explorer.title", "Explorer")
        )
    }

    func makePerformanceInsight(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String? {
        if comparison.isExplorationLed { return PlayInsightsL10n.string("playinsights.insight.steady_exploration", "Your recent runs are focused on steady exploration.") }
        if comparison.hasRiskyPattern { return PlayInsightsL10n.string("playinsights.insight.risky_sections", "You tend to push forward through risky sections.") }
        if comparison.isHardTitle { return PlayInsightsL10n.string("playinsights.insight.remains_hardest", "This remains one of your hardest games.") }
        return PlayInsightsL10n.string("playinsights.insight.exploration_focused", "This title is currently exploration-focused.")
    }

    func makePlayStyle(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> PlayStyleSummary? {
        if comparison.isExplorationLed {
            return PlayStyleSummary(
                title: PlayInsightsL10n.string("playinsights.style.explorer.title", "Explorer"),
                bullet1: PlayInsightsL10n.string("playinsights.style.explorer.area_body", "Steady area discovery defines your recent runs."),
                bullet2: nil
            )
        }
        if comparison.hasRiskyPattern {
            return PlayStyleSummary(
                title: PlayInsightsL10n.string("playinsights.style.risk_taker.title", "Risk Taker"),
                bullet1: PlayInsightsL10n.string("playinsights.style.risk_taker.combat_body", "You keep momentum through combat-heavy routes."),
                bullet2: nil
            )
        }
        return nil
    }

    private func visitedAreas(_ snapshot: GameSpecificTelemetrySnapshot) -> Int {
        Int(snapshot.payloadJson["visitedAreas", default: 0].nonzeroBitCount)
    }
}

private struct CircleOfTheMoonTelemetryFormatter: GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary? {
        ProgressSummary(
            primary: PlayInsightsL10n.string("playinsights.progress.progress_tracked", "Progress tracked"),
            secondary: PlayInsightsL10n.string("playinsights.progress.current_state_available", "Current state available")
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        CurrentRunSummary(
            primary: PlayInsightsL10n.string("playinsights.current_run.current_state_tracked", "Current state tracked"),
            secondary: PlayInsightsL10n.string("playinsights.current_run.recent_progress_available", "Recent progress available"),
            badge: nil
        )
    }

    func makePerformanceInsight(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String? {
        nil
    }

    func makePlayStyle(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> PlayStyleSummary? {
        nil
    }
}

private struct HarmonyOfDissonanceTelemetryFormatter: GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary? {
        ProgressSummary(
            primary: PlayInsightsL10n.string("playinsights.progress.progress_tracked", "Progress tracked"),
            secondary: PlayInsightsL10n.string("playinsights.progress.current_route_state_available", "Current route/state available")
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        CurrentRunSummary(
            primary: PlayInsightsL10n.string("playinsights.current_run.castle_progress_in_motion", "Castle progress in motion"),
            secondary: PlayInsightsL10n.string("playinsights.progress.current_state_available", "Current state available"),
            badge: nil
        )
    }

    func makePerformanceInsight(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String? {
        nil
    }

    func makePlayStyle(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> PlayStyleSummary? {
        nil
    }
}

private func sma2MapName(_ map: UInt16) -> String {
    switch map {
    case 0x01: return "Donut Plains"
    case 0x02: return "Vanilla Dome"
    case 0x03: return "Twin Bridges"
    case 0x04: return "Forest of Illusion"
    case 0x05: return "Chocolate Island"
    case 0x06: return "Valley of Bowser"
    default: return "Current World"
    }
}

private func sma2LevelName(map: UInt16, level: UInt16) -> String {
    if map == 0x01 && level == 0x15 { return "Donut Plains 2" }
    if level > 0 {
        return "\(sma2MapName(map)) \(String(level, radix: 16).uppercased())"
    }
    return sma2MapName(map)
}

private func sma2StageLabel(_ level: UInt16) -> String {
    if level == 0x15 { return "2A" }
    if level == 0 { return "1" }
    return String(level, radix: 16).uppercased()
}
