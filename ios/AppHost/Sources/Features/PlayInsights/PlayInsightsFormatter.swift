import Foundation

protocol GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary?
    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary?
    func makePerformanceInsight(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String?
    func makePlayStyle(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> PlayStyleSummary?
    func makeContinuePlayingSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> ContinuePlayingSmartSummary?
}

struct PlayInsightsComparison: Equatable, Sendable {
    var isImproving: Bool
    var isHardTitle: Bool
    var hasRiskyPattern: Bool
    var isExplorationLed: Bool
}

extension GameTelemetryFormatter {
    func makeContinuePlayingSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> ContinuePlayingSmartSummary? {
        let progress = makeProgressSummary(snapshot: snapshot, stats: stats)
        let currentRun = makeCurrentRunSummary(snapshot: snapshot, stats: stats)
        let insight = makePerformanceInsight(snapshot: snapshot, stats: stats, comparison: comparison)
        let primary = currentRun?.primary ?? progress?.primary
        guard let primary else { return nil }
        let support = currentRun?.secondary ?? progress?.secondary ?? insight
        return ContinuePlayingSmartSummary(
            primaryProgressLine: primary,
            supportingStateLine: support,
            badgeText: currentRun?.badge
        )
    }
}

enum PlayInsightsFormatterFactory {
    static func formatter(for game: PlayInsightsSupportedGame) -> GameTelemetryFormatter {
        switch game {
        case .superMarioAdvance2: return SMA2TelemetryFormatter()
        case .superMarioAdvance4: return SMA4TelemetryFormatter()
        case .dragonBallAdvancedAdventure: return DragonBallAdvancedAdventureTelemetryFormatter()
        case .onePiece: return OnePieceTelemetryFormatter()
        case .kingdomHeartsChainOfMemories: return KingdomHeartsChainOfMemoriesTelemetryFormatter()
        case .zeldaMinishCap: return ZeldaMinishCapTelemetryFormatter()
        case .metroidFusion: return MetroidFusionTelemetryFormatter()
        case .metroidZeroMission: return MetroidZeroMissionTelemetryFormatter()
        case .castlevaniaAriaOfSorrow: return AriaOfSorrowTelemetryFormatter()
        case .castlevaniaCircleOfTheMoon: return CircleOfTheMoonTelemetryFormatter()
        case .castlevaniaHarmonyOfDissonance: return HarmonyOfDissonanceTelemetryFormatter()
        }
    }
}

enum ContinuePlayingSummaryBuilder {
    static func makeSummary(
        from record: PlayInsightsStoredGameRecord,
        allRecords: [PlayInsightsStoredGameRecord]
    ) -> ContinuePlayingSmartSummary? {
        let formatter = PlayInsightsFormatterFactory.formatter(for: record.supportedGame)
        let comparison = PlayInsightsSummaryBuilder.makeComparison(record: record, allRecords: allRecords)
        let summary = formatter.makeContinuePlayingSummary(
            snapshot: record.latestSnapshot,
            stats: record.eventStats,
            comparison: comparison
        )
        let enriched = PlayInsightsSummaryBuilder.appendVitals(to: summary, snapshot: record.latestSnapshot)
        guard let enriched else { return nil }
        return ContinuePlayingSmartSummary(
            primaryProgressLine: PlayInsightsSummaryBuilder.preferredPrimaryText(base: enriched.primaryProgressLine, record: record) ?? enriched.primaryProgressLine,
            supportingStateLine: enriched.supportingStateLine,
            badgeText: enriched.badgeText
        )
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
        let progress = appendVitals(
            to: formatter.makeProgressSummary(snapshot: record.latestSnapshot, stats: record.eventStats),
            snapshot: record.latestSnapshot
        )
        let currentRun = appendVitals(
            to: formatter.makeCurrentRunSummary(snapshot: record.latestSnapshot, stats: record.eventStats),
            snapshot: record.latestSnapshot
        )
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
            progressPrimaryValue: preferredPrimaryText(base: progress?.primary, record: record),
            progressSecondaryValue: progress?.secondary,
            performanceInsightText: insight,
            playStyleTitle: playStyle?.title,
            playStyleBullet1: playStyle?.bullet1,
            playStyleBullet2: playStyle?.bullet2,
            currentRunPrimary: preferredPrimaryText(base: currentRun?.primary, record: record),
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

    static func appendVitals(
        to summary: ProgressSummary?,
        snapshot: GameSpecificTelemetrySnapshot?
    ) -> ProgressSummary? {
        guard let summary else { return nil }
        return ProgressSummary(
            primary: summary.primary,
            secondary: appendVitalsText(base: summary.secondary, snapshot: snapshot) ?? summary.secondary
        )
    }

    static func appendVitals(
        to summary: CurrentRunSummary?,
        snapshot: GameSpecificTelemetrySnapshot?
    ) -> CurrentRunSummary? {
        guard let summary else { return nil }
        return CurrentRunSummary(
            primary: summary.primary,
            secondary: appendVitalsText(base: summary.secondary, snapshot: snapshot) ?? summary.secondary,
            badge: summary.badge
        )
    }

    static func appendVitals(
        to summary: ContinuePlayingSmartSummary?,
        snapshot: GameSpecificTelemetrySnapshot?
    ) -> ContinuePlayingSmartSummary? {
        guard let summary else { return nil }
        return ContinuePlayingSmartSummary(
            primaryProgressLine: summary.primaryProgressLine,
            supportingStateLine: vitalsSummary(snapshot) ?? summary.supportingStateLine,
            badgeText: summary.badgeText
        )
    }

    private static func string(_ value: Int) -> String { "\(value)" }

    private static func appendVitalsText(base: String?, snapshot: GameSpecificTelemetrySnapshot?) -> String? {
        let vitals = vitalsSummary(snapshot)
        guard let vitals else { return base }
        guard let base, !base.isEmpty else { return vitals }
        if base.contains(vitals) {
            return base
        }
        return "\(base) • \(vitals)"
    }

    private static func vitalsSummary(_ snapshot: GameSpecificTelemetrySnapshot?) -> String? {
        guard let snapshot else { return nil }
        var parts: [String] = []
        if let health = snapshot.payloadJson["health"] {
            if let maxHealth = snapshot.payloadJson["maxHealth"], maxHealth > 0 {
                parts.append(
                    PlayInsightsL10n.format(
                        "playinsights.vitals.hp_max_format",
                        "HP %@/%@",
                        "\(health)",
                        "\(maxHealth)"
                    )
                )
            } else {
                parts.append(
                    PlayInsightsL10n.format(
                        "playinsights.vitals.hp_current_format",
                        "HP %@",
                        "\(health)"
                    )
                )
            }
        }
        if let lives = snapshot.payloadJson["lives"] {
            parts.append(
                PlayInsightsL10n.format(
                    "playinsights.vitals.lives_left_format",
                    "%@ lives left",
                    "\(lives)"
                )
            )
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private static func averageDamageText(_ value: Double?) -> String {
        guard let value else { return "0" }
        return "\(Int(value.rounded()))"
    }

    static func preferredPrimaryText(base: String?, record: PlayInsightsStoredGameRecord) -> String? {
        switch record.supportedGame {
        case .onePiece:
            return sanitizedLocationSummary(record.latestLocationSummary) ?? base
        case .dragonBallAdvancedAdventure:
            return nil
        default:
            return base
        }
    }

    private static func sanitizedLocationSummary(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("Loc ") {
            return String(trimmed.dropFirst(4))
        }
        return trimmed
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
            secondary: sma2StageSummaryText(level)
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        guard let snapshot else { return nil }
        let map = snapshot.payloadJson["map", default: 0]
        let level = snapshot.payloadJson["level", default: 0]
        let stageSummary = sma2StageSummaryText(level)
        let primary = sma2StageLabel(level).map {
            "\(sma2MapName(map)) • \(PlayInsightsL10n.format("playinsights.progress.stage_format", "Stage %@", $0))"
        } ?? sma2MapName(map)
        return CurrentRunSummary(
            primary: primary,
            secondary: stageSummary,
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

    func makeContinuePlayingSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> ContinuePlayingSmartSummary? {
        guard let currentRun = makeCurrentRunSummary(snapshot: snapshot, stats: stats) else { return nil }
        return ContinuePlayingSmartSummary(
            primaryProgressLine: currentRun.primary,
            supportingStateLine: currentRun.secondary,
            badgeText: currentRun.badge
        )
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

    func makeContinuePlayingSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> ContinuePlayingSmartSummary? {
        guard let currentRun = makeCurrentRunSummary(snapshot: snapshot, stats: stats) else { return nil }
        return ContinuePlayingSmartSummary(
            primaryProgressLine: currentRun.primary,
            supportingStateLine: PlayInsightsL10n.string("playinsights.continue_playing.route_active", "Current route active"),
            badgeText: currentRun.badge
        )
    }
}

private struct MetroidFusionTelemetryFormatter: GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary? {
        guard let snapshot else { return nil }
        return ProgressSummary(
            primary: metroidFusionLocationTitle(snapshot),
            secondary: metroidFusionAreaDisplayName(snapshot)
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        guard let snapshot else { return nil }
        return CurrentRunSummary(
            primary: metroidFusionLocationTitle(snapshot),
            secondary: metroidFusionAreaDisplayName(snapshot),
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

    func makeContinuePlayingSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> ContinuePlayingSmartSummary? {
        guard let currentRun = makeCurrentRunSummary(snapshot: snapshot, stats: stats) else { return nil }
        return ContinuePlayingSmartSummary(
            primaryProgressLine: currentRun.primary,
            supportingStateLine: currentRun.secondary,
            badgeText: currentRun.badge
        )
    }
}

private struct MetroidZeroMissionTelemetryFormatter: GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary? {
        guard let snapshot else { return nil }
        return ProgressSummary(
            primary: metroidZeroMissionLocationTitle(snapshot),
            secondary: metroidZeroMissionAreaDisplayName(snapshot)
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        guard let snapshot else { return nil }
        return CurrentRunSummary(
            primary: metroidZeroMissionLocationTitle(snapshot),
            secondary: metroidZeroMissionAreaDisplayName(snapshot),
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

    func makeContinuePlayingSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> ContinuePlayingSmartSummary? {
        guard let currentRun = makeCurrentRunSummary(snapshot: snapshot, stats: stats) else { return nil }
        return ContinuePlayingSmartSummary(
            primaryProgressLine: currentRun.primary,
            supportingStateLine: currentRun.secondary,
            badgeText: currentRun.badge
        )
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

    func makeContinuePlayingSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> ContinuePlayingSmartSummary? {
        guard let snapshot else { return nil }
        return ContinuePlayingSmartSummary(
            primaryProgressLine: PlayInsightsL10n.format("playinsights.progress.visited_areas_format", "Visited %@ areas", "\(visitedAreas(snapshot))"),
            supportingStateLine: PlayInsightsL10n.string("playinsights.current_run.exploration_active", "Exploration active"),
            badgeText: PlayInsightsL10n.string("playinsights.style.explorer.title", "Explorer")
        )
    }
}

private struct OnePieceTelemetryFormatter: GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary? {
        guard let snapshot else { return nil }
        return ProgressSummary(
            primary: onePieceNamedLocationSummary(snapshot) ?? onePieceProgressTitle(snapshot),
            secondary: onePieceStateSummary(snapshot)
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        guard let snapshot else { return nil }
        return CurrentRunSummary(
            primary: onePieceNamedLocationSummary(snapshot) ?? onePieceProgressTitle(snapshot),
            secondary: onePieceRunSummary(snapshot),
            badge: PlayInsightsL10n.string("playinsights.badge.combat_live", "Combat Live")
        )
    }

    func makePerformanceInsight(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String? {
        if comparison.isImproving {
            return PlayInsightsL10n.string("playinsights.insight.more_consistent", "Your recent runs look more consistent.")
        }
        if comparison.hasRiskyPattern {
            return PlayInsightsL10n.string("playinsights.insight.risky_sections", "You tend to push forward through risky sections.")
        }
        if let snapshot, snapshot.payloadJson["health", default: 0] == 0 {
            return PlayInsightsL10n.string("playinsights.insight.recovery_needed", "Your last tracked state ended in recovery.")
        }
        return PlayInsightsL10n.string("playinsights.insight.progress_tracked_recent", "Your progress is being tracked across recent sessions.")
    }

    func makePlayStyle(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> PlayStyleSummary? {
        if comparison.hasRiskyPattern {
            return PlayStyleSummary(
                title: PlayInsightsL10n.string("playinsights.style.risk_taker.title", "Risk Taker"),
                bullet1: PlayInsightsL10n.string("playinsights.style.risk_taker.combat_body", "You keep momentum through combat-heavy routes."),
                bullet2: nil
            )
        }
        if let snapshot,
           snapshot.payloadJson["special", default: 0] > 0,
           (stats.currentSessionDamageEvents ?? 0) <= 2 {
            return PlayStyleSummary(
                title: PlayInsightsL10n.string("playinsights.style.precision_player.title", "Precision Player"),
                bullet1: PlayInsightsL10n.string("playinsights.style.precision_player.body", "Precise control with minimal damage taken."),
                bullet2: nil
            )
        }
        return nil
    }
}

private struct DragonBallAdvancedAdventureTelemetryFormatter: GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary? {
        guard let snapshot else { return nil }
        return ProgressSummary(
            primary: dragonBallNamedLocationSummary(snapshot) ?? dragonBallProgressTitle(snapshot),
            secondary: dragonBallStateSummary(snapshot)
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        guard let snapshot else { return nil }
        return CurrentRunSummary(
            primary: dragonBallNamedLocationSummary(snapshot) ?? dragonBallProgressTitle(snapshot),
            secondary: dragonBallStateSummary(snapshot),
            badge: PlayInsightsL10n.string("playinsights.badge.combat_live", "Combat Live")
        )
    }

    func makePerformanceInsight(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String? {
        if comparison.isImproving {
            return PlayInsightsL10n.string("playinsights.insight.more_consistent", "Your recent runs look more consistent.")
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
                bullet1: PlayInsightsL10n.string("playinsights.style.risk_taker.combat_body", "You keep momentum through combat-heavy routes."),
                bullet2: nil
            )
        }
        if comparison.isImproving {
            return PlayStyleSummary(
                title: PlayInsightsL10n.string("playinsights.style.precision_player.title", "Precision Player"),
                bullet1: PlayInsightsL10n.string("playinsights.style.precision_player.body", "Precise control with minimal damage taken."),
                bullet2: nil
            )
        }
        return nil
    }
}

private struct KingdomHeartsChainOfMemoriesTelemetryFormatter: GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary? {
        guard let snapshot else { return nil }
        return ProgressSummary(
            primary: kingdomHeartsLevelSummary(snapshot),
            secondary: kingdomHeartsHealthSummary(snapshot)
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        guard let snapshot else { return nil }
        return CurrentRunSummary(
            primary: "\(kingdomHeartsLevelSummary(snapshot)) • \(kingdomHeartsHealthSummary(snapshot))",
            secondary: kingdomHeartsRunSummary(snapshot),
            badge: PlayInsightsL10n.string("playinsights.badge.deck_ready", "Deck Ready")
        )
    }

    func makePerformanceInsight(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String? {
        if comparison.isImproving {
            return PlayInsightsL10n.string("playinsights.insight.improving_recent", "You’re improving in recent sessions.")
        }
        if comparison.isHardTitle {
            return PlayInsightsL10n.string("playinsights.insight.remains_hardest", "This remains one of your hardest games.")
        }
        if comparison.hasRiskyPattern {
            return PlayInsightsL10n.string("playinsights.insight.high_pressure_deck", "Recent fights are landing under heavy pressure.")
        }
        return PlayInsightsL10n.string("playinsights.insight.progress_tracked_recent", "Your progress is being tracked across recent sessions.")
    }

    func makePlayStyle(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> PlayStyleSummary? {
        if comparison.hasRiskyPattern {
            return PlayStyleSummary(
                title: PlayInsightsL10n.string("playinsights.style.persistent_challenger.title", "Persistent Challenger"),
                bullet1: PlayInsightsL10n.string("playinsights.style.persistent_challenger.body", "You keep pushing through repeat attempts."),
                bullet2: nil
            )
        }
        if let snapshot,
           snapshot.payloadJson["cp", default: 0] > 0,
           (stats.currentSessionDamageEvents ?? 0) <= 3 {
            return PlayStyleSummary(
                title: PlayInsightsL10n.string("playinsights.style.precision_player.title", "Precision Player"),
                bullet1: PlayInsightsL10n.string("playinsights.style.precision_player.body", "Precise control with minimal damage taken."),
                bullet2: nil
            )
        }
        return nil
    }
}

private struct ZeldaMinishCapTelemetryFormatter: GameTelemetryFormatter {
    func makeProgressSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> ProgressSummary? {
        guard let snapshot else { return nil }
        return ProgressSummary(
            primary: zeldaMinishCapAreaSummary(snapshot),
            secondary: zeldaMinishCapHealthSummary(snapshot)
        )
    }

    func makeCurrentRunSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary) -> CurrentRunSummary? {
        guard let snapshot else { return nil }
        return CurrentRunSummary(
            primary: zeldaMinishCapAreaSummary(snapshot),
            secondary: zeldaMinishCapHealthSummary(snapshot),
            badge: PlayInsightsL10n.string("playinsights.badge.exploration", "Exploration")
        )
    }

    func makePerformanceInsight(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> String? {
        if comparison.isExplorationLed {
            return PlayInsightsL10n.string("playinsights.insight.steady_exploration", "Your recent runs are focused on steady exploration.")
        }
        if comparison.isImproving {
            return PlayInsightsL10n.string("playinsights.insight.improving_recent", "You’re improving in recent sessions.")
        }
        if comparison.hasRiskyPattern {
            return PlayInsightsL10n.string("playinsights.insight.risky_sections", "You tend to push forward through risky sections.")
        }
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

    func makeContinuePlayingSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> ContinuePlayingSmartSummary? {
        ContinuePlayingSmartSummary(
            primaryProgressLine: PlayInsightsL10n.string("playinsights.progress.progress_tracked", "Progress tracked"),
            supportingStateLine: PlayInsightsL10n.string("playinsights.progress.current_state_available", "Current state available"),
            badgeText: PlayInsightsL10n.string("playinsights.badge.tracked", "Tracked")
        )
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

    func makeContinuePlayingSummary(snapshot: GameSpecificTelemetrySnapshot?, stats: GameEventStatsSummary, comparison: PlayInsightsComparison) -> ContinuePlayingSmartSummary? {
        ContinuePlayingSmartSummary(
            primaryProgressLine: PlayInsightsL10n.string("playinsights.continue_playing.castle_progress_tracked", "Castle progress tracked"),
            supportingStateLine: PlayInsightsL10n.string("playinsights.continue_playing.current_route_available", "Current route available"),
            badgeText: PlayInsightsL10n.string("playinsights.badge.tracked", "Tracked")
        )
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
    if let label = sma2StageLabel(level) {
        return "\(sma2MapName(map)) \(label)"
    }
    return sma2MapName(map)
}

private func sma2StageLabel(_ level: UInt16) -> String? {
    switch level {
    case 0x00: return "1"
    case 0x15: return "2A"
    default: return nil
    }
}

private func sma2StageSummaryText(_ level: UInt16) -> String {
    sma2StageLabel(level).map {
        PlayInsightsL10n.format("playinsights.progress.stage_format", "Stage %@", $0)
    } ?? ""
}

private func onePieceNamedLocationSummary(_ snapshot: GameSpecificTelemetrySnapshot) -> String? {
    guard let progressState = snapshot.payloadJson["progressState"] else { return nil }
    return onePieceLocationName(Int(progressState))
}

private func onePieceProgressTitle(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    let special = snapshot.payloadJson["special", default: 0]
    let state = snapshot.payloadJson["state", default: 0]
    if snapshot.payloadJson["health", default: 0] == 0 {
        return PlayInsightsL10n.string("playinsights.progress.recovering_after_defeat", "Recovering after defeat")
    }
    if special > 0 || state > 0 {
        return PlayInsightsL10n.string("playinsights.progress.combat_in_progress", "Combat in progress")
    }
    return PlayInsightsL10n.string("playinsights.progress.adventure_in_progress", "Adventure in progress")
}

private func onePieceStateSummary(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    let special = snapshot.payloadJson["special", default: 0]
    if special > 0 {
        return PlayInsightsL10n.string("playinsights.current_run.combat_active", "Combat active")
    }
    let state = snapshot.payloadJson["state", default: 0]
    if state > 0 {
        return PlayInsightsL10n.string("playinsights.current_run.combat_active", "Combat active")
    }
    return PlayInsightsL10n.string("playinsights.current_run.adventure_active", "Adventure active")
}

private func onePieceRunSummary(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    let special = snapshot.payloadJson["special", default: 0]
    if special > 0 {
        return PlayInsightsL10n.string("playinsights.current_run.combat_active", "Combat active")
    }
    if snapshot.payloadJson["state", default: 0] > 0 {
        return PlayInsightsL10n.string("playinsights.current_run.combat_active", "Combat active")
    }
    return PlayInsightsL10n.string("playinsights.current_run.adventure_active", "Adventure active")
}

private func dragonBallStateSummary(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    if snapshot.payloadJson["health", default: 0] == 0 {
        return PlayInsightsL10n.string("playinsights.current_run.recovering_after_defeat", "Recovering after defeat")
    }
    if snapshot.payloadJson["state", default: 0] > 0 {
        return PlayInsightsL10n.string("playinsights.current_run.combat_active", "Combat active")
    }
    return PlayInsightsL10n.string("playinsights.current_run.adventure_active", "Adventure active")
}

private func dragonBallNamedLocationSummary(_ snapshot: GameSpecificTelemetrySnapshot) -> String? {
    guard let stage = snapshot.payloadJson["stage"] else { return nil }
    return dragonBallLocationName(Int(stage))
}

private func dragonBallProgressTitle(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    if snapshot.payloadJson["health", default: 0] == 0 {
        return PlayInsightsL10n.string("playinsights.progress.recovering_after_defeat", "Recovering after defeat")
    }
    if snapshot.payloadJson["state", default: 0] > 0 {
        return PlayInsightsL10n.string("playinsights.progress.combat_in_progress", "Combat in progress")
    }
    return PlayInsightsL10n.string("playinsights.progress.adventure_in_progress", "Adventure in progress")
}

func dragonBallLocationName(_ stage: Int) -> String? {
    return PlayInsightsL10n.string("playinsights.progress.adventure_in_progress", "Adventure in Progress")
}

func onePieceLocationName(_ progressState: Int) -> String? {
    switch progressState {
    case 0x307D:
        return "Port Town"
    case 0x2BA1:
        return "Navy Base"
    default:
        return nil
    }
}

private func metroidFusionLocationTitle(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    let area = Int(snapshot.payloadJson["area", default: 0])
    let room = Int(snapshot.payloadJson["room", default: 0])
    if let roomName = metroidFusionRoomName(area: area, room: room) {
        return roomName
    }
    return metroidFusionAreaDisplayName(area: area)
}

private func metroidZeroMissionLocationTitle(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    let area = Int(snapshot.payloadJson["area", default: 0])
    let room = Int(snapshot.payloadJson["room", default: 0])
    if let roomName = metroidZeroMissionRoomName(area: area, room: room) {
        return roomName
    }
    return metroidZeroMissionAreaDisplayName(area: area)
}

private func metroidZeroMissionAreaDisplayName(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    metroidZeroMissionAreaDisplayName(area: Int(snapshot.payloadJson["area", default: 0]))
}

private func metroidZeroMissionAreaDisplayName(area: Int) -> String {
    switch area {
    case 0x00: return "Brinstar"
    case 0x01: return "Kraid"
    case 0x02: return "Norfair"
    case 0x03: return "Ridley"
    case 0x04: return "Tourian"
    case 0x05: return "Crateria"
    case 0x06: return "Chozodia"
    default:
        return PlayInsightsL10n.format("playinsights.progress.area_format", "Area %@", "\(max(1, area))")
    }
}

private func metroidZeroMissionRoomName(area: Int, room: Int) -> String? {
    nil
}

private func metroidFusionAreaDisplayName(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    metroidFusionAreaDisplayName(area: Int(snapshot.payloadJson["area", default: 0]))
}

private func metroidFusionAreaDisplayName(area: Int) -> String {
    switch area {
    case 0x00: return "Main Deck"
    case 0x01: return "Sector 1 (SRX)"
    case 0x02: return "Sector 2 (TRO)"
    case 0x03: return "Sector 3 (PYR)"
    case 0x04: return "Sector 4 (AQA)"
    case 0x05: return "Sector 5 (ARC)"
    case 0x06: return "Sector 6 (NOC)"
    case 0x07: return "Restricted Lab"
    default:
        return PlayInsightsL10n.format("playinsights.progress.sector_format", "Sector %@", "\(max(1, area))")
    }
}

private func metroidFusionRoomName(area: Int, room: Int) -> String? {
    switch (area, room) {
    case (0x04, 0x01): return "Sector 4 Main Hall"
    case (0x04, 0x02): return "Save Room Station 4"
    case (0x04, 0x03): return "Navigation Room Station 4"
    case (0x04, 0x05): return "Data Room (AQA)"
    case (0x04, 0x06): return "Sector 4 Access"
    case (0x04, 0x07): return "Main Research Pool"
    case (0x04, 0x08): return "Main Aquarium"
    case (0x04, 0x09): return "Aquarium Hall"
    case (0x04, 0x0A): return "Booster Hall"
    case (0x04, 0x0E): return "Water Tank Storage"
    case (0x04, 0x14): return "Main Seabed"
    case (0x04, 0x1A): return "AQA Security Access Shaft"
    case (0x04, 0x1D): return "Secret Aquarium"
    case (0x04, 0x1E): return "Recharge Room Station 4"
    case (0x04, 0x23): return "AQA Security Roof"
    case (0x04, 0x25): return "AQA Maintenance Tunnel"
    case (0x04, 0x26): return "AQA Maintenance Access"
    case (0x04, 0x2B): return "Testing Tank"
    default: return nil
    }
}

private func kingdomHeartsLevelSummary(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    let level = max(1, Int(snapshot.payloadJson["level", default: 1]))
    return "Level \(level)"
}

private func kingdomHeartsHealthSummary(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    let health = snapshot.payloadJson["health", default: 0]
    let maxHealth = max(health, snapshot.payloadJson["maxHealth", default: health])
    return "HP \(health)/\(maxHealth)"
}

private func kingdomHeartsRunSummary(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    let cp = snapshot.payloadJson["cp", default: 0]
    if cp > 0 {
        return "CP \(cp) equipped"
    }
    let state = snapshot.payloadJson["state", default: 0]
    if state > 0 {
        return "Combat state \(state)"
    }
    return PlayInsightsL10n.string("playinsights.progress.current_state_available", "Current state available")
}

private func zeldaMinishCapAreaSummary(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    let map = snapshot.payloadJson["map"].map(playInsightsHex8(_:)) ?? "--"
    let room = snapshot.payloadJson["room"].map(playInsightsHex8(_:)) ?? "--"
    return "Area \(map) • Room \(room)"
}

private func zeldaMinishCapHealthSummary(_ snapshot: GameSpecificTelemetrySnapshot) -> String {
    let health = snapshot.payloadJson["health", default: 0]
    let maxHealth = max(health, snapshot.payloadJson["maxHealth", default: health])
    return "HP \(health)/\(maxHealth)"
}

private func playInsightsHex8(_ value: UInt16) -> String {
    String(format: "%02X", Int(value & 0xFF))
}
