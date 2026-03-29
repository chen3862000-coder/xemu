import XCTest
import CoreData
@testable import Xemu

@MainActor
final class PlayInsightsStoreTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("play-insights-")
            .appendingPathExtension(UUID().uuidString)
    }

    override func tearDown() {
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        tempURL = nil
        super.tearDown()
    }

    func testSMA2SummaryBuildsFriendlyProgressAndCards() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let end = Date(timeIntervalSince1970: 1_700_000_500)

        store.recordSession(
            .init(
                gameId: "sma2",
                gameTitle: "Super Mario Advance 2",
                system: "gba",
                supportedGame: .superMarioAdvance2,
                startedAt: end.addingTimeInterval(-900),
                endedAt: end,
                durationSeconds: 900,
                deaths: 6,
                damageEvents: 9,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "sma2",
                    timestamp: end,
                    payloadType: PlayInsightsSupportedGame.superMarioAdvance2.profileID,
                    payloadJson: [
                        "map": 0x01,
                        "level": 0x15,
                        "lives": 4
                    ]
                ),
                latestLocationSummary: "Loc Donut Plains • level 15"
            )
        )

        let summary = try XCTUnwrap(store.summary(for: "sma2"))
        XCTAssertTrue(summary.playInsightsEnabled)
        XCTAssertEqual(summary.progressPrimaryValue, "Donut Plains")
        XCTAssertEqual(summary.progressSecondaryValue, "Stage 2A • 4 lives left")
        XCTAssertEqual(summary.currentRunPrimary, "Donut Plains • Stage 2A")
        XCTAssertEqual(summary.currentRunSecondary, "Stage 2A • 4 lives left")
        XCTAssertEqual(summary.currentRunBadge, "Platforming")
        XCTAssertEqual(summary.deathsPrimaryValue, "6")
        XCTAssertEqual(summary.damagePrimaryValue, "9")
    }

    func testGlobalSummaryRanksHardestGamesAndBuildsCards() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let now = Date(timeIntervalSince1970: 1_700_100_000)

        store.recordSession(
            .init(
                gameId: "sma2",
                gameTitle: "Super Mario Advance 2",
                system: "gba",
                supportedGame: .superMarioAdvance2,
                startedAt: now.addingTimeInterval(-1_000),
                endedAt: now.addingTimeInterval(-100),
                durationSeconds: 900,
                deaths: 12,
                damageEvents: 20,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "sma2",
                    timestamp: now,
                    payloadType: PlayInsightsSupportedGame.superMarioAdvance2.profileID,
                    payloadJson: ["map": 0x01, "level": 0x15]
                ),
                latestLocationSummary: nil
            )
        )
        store.recordSession(
            .init(
                gameId: "aria",
                gameTitle: "Castlevania: Aria of Sorrow",
                system: "gba",
                supportedGame: .castlevaniaAriaOfSorrow,
                startedAt: now.addingTimeInterval(-700),
                endedAt: now,
                durationSeconds: 700,
                deaths: 4,
                damageEvents: 7,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "aria",
                    timestamp: now,
                    payloadType: PlayInsightsSupportedGame.castlevaniaAriaOfSorrow.profileID,
                    payloadJson: ["visitedAreas": 0b0011_1111]
                ),
                latestLocationSummary: nil
            )
        )

        let persistence = PersistenceController(inMemory: true)
        let context = persistence.viewContext
        let sma2Entry = ROMLibraryEntry(context: context)
        sma2Entry.id = UUID()
        sma2Entry.title = "Super Mario Advance 2"
        sma2Entry.system = "gba"
        sma2Entry.checksum = "sma2"
        sma2Entry.lastPlayedAt = now.addingTimeInterval(-100)

        let ariaEntry = ROMLibraryEntry(context: context)
        ariaEntry.id = UUID()
        ariaEntry.title = "Castlevania: Aria of Sorrow"
        ariaEntry.system = "gba"
        ariaEntry.checksum = "aria"
        ariaEntry.lastPlayedAt = now

        let summary = store.globalSummary(for: [sma2Entry, ariaEntry])

        XCTAssertEqual(summary.supportedGamesPlayed, 2)
        XCTAssertEqual(summary.totalDeaths, 16)
        XCTAssertEqual(summary.hardestGames.first?.gameId, "sma2")
        XCTAssertEqual(summary.supportedGameCards.count, 2)
        XCTAssertEqual(summary.activeRuns.first?.gameId, "aria")
    }

    func testRefreshLiveSnapshotUpdatesSMA2StageBeforeSessionEnd() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let initial = Date(timeIntervalSince1970: 1_700_200_000)

        store.refreshLiveSnapshot(
            .init(
                gameId: "sma2",
                gameTitle: "Super Mario Advance 2",
                system: "gba",
                supportedGame: .superMarioAdvance2,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "sma2",
                    timestamp: initial,
                    payloadType: PlayInsightsSupportedGame.superMarioAdvance2.profileID,
                    payloadJson: ["map": 0x01, "level": 0x00, "lives": 5]
                ),
                latestLocationSummary: "Loc Donut Plains • level 00"
            )
        )

        let initialSummary = try XCTUnwrap(store.summary(for: "sma2"))
        XCTAssertEqual(initialSummary.progressPrimaryValue, "Donut Plains")
        XCTAssertEqual(initialSummary.progressSecondaryValue, "Stage 1 • 5 lives left")
        XCTAssertEqual(initialSummary.currentRunPrimary, "Donut Plains • Stage 1")

        store.refreshLiveSnapshot(
            .init(
                gameId: "sma2",
                gameTitle: "Super Mario Advance 2",
                system: "gba",
                supportedGame: .superMarioAdvance2,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "sma2",
                    timestamp: initial.addingTimeInterval(10),
                    payloadType: PlayInsightsSupportedGame.superMarioAdvance2.profileID,
                    payloadJson: ["map": 0x01, "level": 0x15, "lives": 4]
                ),
                latestLocationSummary: "Loc Donut Plains • level 15"
            )
        )

        let refreshedSummary = try XCTUnwrap(store.summary(for: "sma2"))
        XCTAssertEqual(refreshedSummary.progressPrimaryValue, "Donut Plains")
        XCTAssertEqual(refreshedSummary.progressSecondaryValue, "Stage 2A • 4 lives left")
        XCTAssertEqual(refreshedSummary.currentRunPrimary, "Donut Plains • Stage 2A")
    }

    func testRefreshLiveSnapshotUsesNeutralSMA2StageTextForUnknownRawLevel() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let initial = Date(timeIntervalSince1970: 1_700_200_100)

        store.refreshLiveSnapshot(
            .init(
                gameId: "sma2-unknown",
                gameTitle: "Super Mario Advance 2",
                system: "gba",
                supportedGame: .superMarioAdvance2,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "sma2-unknown",
                    timestamp: initial,
                    payloadType: PlayInsightsSupportedGame.superMarioAdvance2.profileID,
                    payloadJson: ["map": 0x01, "level": 0x25, "lives": 5]
                ),
                latestLocationSummary: "Loc Donut Plains • level 25"
            )
        )

        let summary = try XCTUnwrap(store.summary(for: "sma2-unknown"))
        XCTAssertEqual(summary.progressPrimaryValue, "Donut Plains")
        XCTAssertEqual(summary.progressSecondaryValue, "5 lives left")
        XCTAssertEqual(summary.currentRunPrimary, "Donut Plains")
        XCTAssertEqual(summary.currentRunSecondary, "5 lives left")
    }

    func testContinuePlayingSummaryUsesGameSpecificSmartContext() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let now = Date(timeIntervalSince1970: 1_700_300_000)

        store.recordSession(
            .init(
                gameId: "aria",
                gameTitle: "Castlevania: Aria of Sorrow",
                system: "gba",
                supportedGame: .castlevaniaAriaOfSorrow,
                startedAt: now.addingTimeInterval(-600),
                endedAt: now,
                durationSeconds: 600,
                deaths: 0,
                damageEvents: 0,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "aria",
                    timestamp: now,
                    payloadType: PlayInsightsSupportedGame.castlevaniaAriaOfSorrow.profileID,
                    payloadJson: ["visitedAreas": 0b0011_1111]
                ),
                latestLocationSummary: nil
            )
        )

        let summary = try XCTUnwrap(store.continuePlayingSummary(for: "aria"))
        XCTAssertEqual(summary.primaryProgressLine, "Visited 6 areas")
        XCTAssertEqual(summary.supportingStateLine, "Exploration active")
        XCTAssertEqual(summary.badgeText, "Explorer")
    }

    func testRefreshLiveSnapshotPreservesKnownLocationSummaryWhenNewSnapshotHasNone() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let now = Date(timeIntervalSince1970: 1_700_300_250)

        store.refreshLiveSnapshot(
            .init(
                gameId: "dbaa-live",
                gameTitle: "Dragon Ball: Advanced Adventure",
                system: "gba",
                supportedGame: .dragonBallAdvancedAdventure,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "dbaa-live",
                    timestamp: now,
                    payloadType: PlayInsightsSupportedGame.dragonBallAdvancedAdventure.profileID,
                    payloadJson: ["state": 0x02, "health": 164, "maxHealth": 255, "lives": 3]
                ),
                latestLocationSummary: "Pilaf Castle"
            )
        )

        store.refreshLiveSnapshot(
            .init(
                gameId: "dbaa-live",
                gameTitle: "Dragon Ball: Advanced Adventure",
                system: "gba",
                supportedGame: .dragonBallAdvancedAdventure,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "dbaa-live",
                    timestamp: now.addingTimeInterval(10),
                    payloadType: PlayInsightsSupportedGame.dragonBallAdvancedAdventure.profileID,
                    payloadJson: ["state": 0x02, "health": 150, "maxHealth": 255, "lives": 3]
                ),
                latestLocationSummary: nil
            )
        )

        let summary = try XCTUnwrap(store.summary(for: "dbaa-live"))
        XCTAssertEqual(summary.progressPrimaryValue, "Pilaf Castle")

        let continueSummary = try XCTUnwrap(store.continuePlayingSummary(for: "dbaa-live"))
        XCTAssertEqual(continueSummary.primaryProgressLine, "Pilaf Castle")
    }

    func testOnePieceSummaryBuildsHealthForwardProgressCards() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let now = Date(timeIntervalSince1970: 1_700_300_500)

        store.recordSession(
            .init(
                gameId: "onepiece",
                gameTitle: "One Piece",
                system: "gba",
                supportedGame: .onePiece,
                startedAt: now.addingTimeInterval(-720),
                endedAt: now,
                durationSeconds: 720,
                deaths: 1,
                damageEvents: 3,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "onepiece",
                    timestamp: now,
                    payloadType: PlayInsightsSupportedGame.onePiece.profileID,
                    payloadJson: [
                        "health": 84,
                        "lives": 3,
                        "progressState": 0x307D,
                        "special": 12,
                        "state": 2
                    ]
                ),
                latestLocationSummary: nil
            )
        )

        let summary = try XCTUnwrap(store.summary(for: "onepiece"))
        XCTAssertEqual(summary.progressPrimaryValue, "Port Town")
        XCTAssertEqual(summary.progressSecondaryValue, "Combat active • HP 84 • 3 lives left")
        XCTAssertEqual(summary.currentRunPrimary, "Port Town")
        XCTAssertEqual(summary.currentRunSecondary, "Combat active • HP 84 • 3 lives left")
        XCTAssertEqual(summary.currentRunBadge, "Combat Live")

        let continueSummary = try XCTUnwrap(store.continuePlayingSummary(for: "onepiece"))
        XCTAssertEqual(continueSummary.primaryProgressLine, "Port Town")
        XCTAssertEqual(continueSummary.supportingStateLine, "HP 84 • 3 lives left")
        XCTAssertEqual(continueSummary.badgeText, "Combat Live")
    }

    func testDragonBallSummaryBuildsCurrentStateCards() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let now = Date(timeIntervalSince1970: 1_700_301_250)

        store.recordSession(
            .init(
                gameId: "dbaa",
                gameTitle: "Dragon Ball: Advanced Adventure",
                system: "gba",
                supportedGame: .dragonBallAdvancedAdventure,
                startedAt: now.addingTimeInterval(-840),
                endedAt: now,
                durationSeconds: 840,
                deaths: 1,
                damageEvents: 4,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "dbaa",
                    timestamp: now,
                    payloadType: PlayInsightsSupportedGame.dragonBallAdvancedAdventure.profileID,
                    payloadJson: [
                        "state": 0x02,
                        "health": 164,
                        "maxHealth": 255,
                        "lives": 3
                    ]
                ),
                latestLocationSummary: "Pilaf Castle"
            )
        )

        let summary = try XCTUnwrap(store.summary(for: "dbaa"))
        XCTAssertEqual(summary.progressPrimaryValue, "Pilaf Castle")
        XCTAssertEqual(summary.progressSecondaryValue, "Combat active • HP 164/255 • 3 lives left")
        XCTAssertEqual(summary.currentRunPrimary, "Pilaf Castle")
        XCTAssertEqual(summary.currentRunSecondary, "Combat active • HP 164/255 • 3 lives left")
        XCTAssertEqual(summary.currentRunBadge, "Combat Live")

        let continueSummary = try XCTUnwrap(store.continuePlayingSummary(for: "dbaa"))
        XCTAssertEqual(continueSummary.primaryProgressLine, "Pilaf Castle")
        XCTAssertEqual(continueSummary.supportingStateLine, "HP 164/255 • 3 lives left")
        XCTAssertEqual(continueSummary.badgeText, "Combat Live")
    }

    func testDragonBallSummaryUsesMappedGokusHouseLocationFromPayload() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let now = Date(timeIntervalSince1970: 1_700_301_260)

        store.recordSession(
            .init(
                gameId: "dbaa-goku-house",
                gameTitle: "Dragon Ball: Advanced Adventure",
                system: "gba",
                supportedGame: .dragonBallAdvancedAdventure,
                startedAt: now.addingTimeInterval(-300),
                endedAt: now,
                durationSeconds: 300,
                deaths: 0,
                damageEvents: 0,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "dbaa-goku-house",
                    timestamp: now,
                    payloadType: PlayInsightsSupportedGame.dragonBallAdvancedAdventure.profileID,
                    payloadJson: [
                        "stage": 0x4F2C,
                        "state": 0x00,
                        "health": 206,
                        "maxHealth": 512,
                        "lives": 3
                    ]
                ),
                latestLocationSummary: nil
            )
        )

        let summary = try XCTUnwrap(store.summary(for: "dbaa-goku-house"))
        XCTAssertEqual(summary.progressPrimaryValue, "Goku's House")

        let continueSummary = try XCTUnwrap(store.continuePlayingSummary(for: "dbaa-goku-house"))
        XCTAssertEqual(continueSummary.primaryProgressLine, "Goku's House")
    }

    func testOnePieceSummaryUsesMappedNavyBaseLocation() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let now = Date(timeIntervalSince1970: 1_700_301_350)

        store.recordSession(
            .init(
                gameId: "onepiece-navy-base",
                gameTitle: "One Piece",
                system: "gba",
                supportedGame: .onePiece,
                startedAt: now.addingTimeInterval(-420),
                endedAt: now,
                durationSeconds: 420,
                deaths: 0,
                damageEvents: 1,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "onepiece-navy-base",
                    timestamp: now,
                    payloadType: PlayInsightsSupportedGame.onePiece.profileID,
                    payloadJson: [
                        "health": 1024,
                        "lives": 2,
                        "progressState": 0x2BA1,
                        "special": 3,
                        "state": 1
                    ]
                ),
                latestLocationSummary: nil
            )
        )

        let summary = try XCTUnwrap(store.summary(for: "onepiece-navy-base"))
        XCTAssertEqual(summary.progressPrimaryValue, "Navy Base")

        let continueSummary = try XCTUnwrap(store.continuePlayingSummary(for: "onepiece-navy-base"))
        XCTAssertEqual(continueSummary.primaryProgressLine, "Navy Base")
    }

    func testKingdomHeartsSummaryBuildsCurrentRunContext() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let now = Date(timeIntervalSince1970: 1_700_301_000)

        store.recordSession(
            .init(
                gameId: "khcom",
                gameTitle: "Kingdom Hearts: Chain of Memories",
                system: "gba",
                supportedGame: .kingdomHeartsChainOfMemories,
                startedAt: now.addingTimeInterval(-900),
                endedAt: now,
                durationSeconds: 900,
                deaths: 2,
                damageEvents: 5,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "khcom",
                    timestamp: now,
                    payloadType: PlayInsightsSupportedGame.kingdomHeartsChainOfMemories.profileID,
                    payloadJson: [
                        "level": 14,
                        "health": 108,
                        "maxHealth": 132,
                        "cp": 275,
                        "state": 1
                    ]
                ),
                latestLocationSummary: nil
            )
        )

        let summary = try XCTUnwrap(store.summary(for: "khcom"))
        XCTAssertEqual(summary.progressPrimaryValue, "Level 14")
        XCTAssertEqual(summary.progressSecondaryValue, "HP 108/132")
        XCTAssertEqual(summary.currentRunPrimary, "Level 14 • HP 108/132")
        XCTAssertEqual(summary.currentRunSecondary, "CP 275 equipped • HP 108/132")
        XCTAssertEqual(summary.currentRunBadge, "Deck Ready")

        let continueSummary = try XCTUnwrap(store.continuePlayingSummary(for: "khcom"))
        XCTAssertEqual(continueSummary.primaryProgressLine, "Level 14 • HP 108/132")
        XCTAssertEqual(continueSummary.supportingStateLine, "HP 108/132")
        XCTAssertEqual(continueSummary.badgeText, "Deck Ready")
    }

    func testZeldaMinishCapSummaryBuildsAreaAndHealthContext() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let now = Date(timeIntervalSince1970: 1_700_301_500)

        store.recordSession(
            .init(
                gameId: "zelda-mc",
                gameTitle: "The Legend of Zelda: The Minish Cap",
                system: "gba",
                supportedGame: .zeldaMinishCap,
                startedAt: now.addingTimeInterval(-1_200),
                endedAt: now,
                durationSeconds: 1_200,
                deaths: 1,
                damageEvents: 2,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "zelda-mc",
                    timestamp: now,
                    payloadType: PlayInsightsSupportedGame.zeldaMinishCap.profileID,
                    payloadJson: [
                        "map": 0x03,
                        "room": 0x1C,
                        "health": 7,
                        "maxHealth": 10
                    ]
                ),
                latestLocationSummary: nil
            )
        )

        let summary = try XCTUnwrap(store.summary(for: "zelda-mc"))
        XCTAssertEqual(summary.progressPrimaryValue, "Area 03 • Room 1C")
        XCTAssertEqual(summary.progressSecondaryValue, "HP 7/10")
        XCTAssertEqual(summary.currentRunPrimary, "Area 03 • Room 1C")
        XCTAssertEqual(summary.currentRunSecondary, "HP 7/10")
        XCTAssertEqual(summary.currentRunBadge, "Exploration")

        let continueSummary = try XCTUnwrap(store.continuePlayingSummary(for: "zelda-mc"))
        XCTAssertEqual(continueSummary.primaryProgressLine, "Area 03 • Room 1C")
        XCTAssertEqual(continueSummary.supportingStateLine, "HP 7/10")
        XCTAssertEqual(continueSummary.badgeText, "Exploration")
    }

    func testMetroidFusionSummaryBuildsNamedAreaAndRoomContext() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let now = Date(timeIntervalSince1970: 1_700_301_750)

        store.recordSession(
            .init(
                gameId: "metroid-fusion",
                gameTitle: "Metroid Fusion",
                system: "gba",
                supportedGame: .metroidFusion,
                startedAt: now.addingTimeInterval(-900),
                endedAt: now,
                durationSeconds: 900,
                deaths: 0,
                damageEvents: 1,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "metroid-fusion",
                    timestamp: now,
                    payloadType: PlayInsightsSupportedGame.metroidFusion.profileID,
                    payloadJson: [
                        "area": 0x04,
                        "room": 0x1A,
                        "health": 34,
                        "maxHealth": 99
                    ]
                ),
                latestLocationSummary: nil
            )
        )

        let summary = try XCTUnwrap(store.summary(for: "metroid-fusion"))
        XCTAssertEqual(summary.progressPrimaryValue, "AQA Security Access Shaft")
        XCTAssertEqual(summary.progressSecondaryValue, "Sector 4 (AQA) • HP 34/99")
        XCTAssertEqual(summary.currentRunPrimary, "AQA Security Access Shaft")
        XCTAssertEqual(summary.currentRunSecondary, "Sector 4 (AQA) • HP 34/99")
        XCTAssertEqual(summary.currentRunBadge, "Exploration")

        let continueSummary = try XCTUnwrap(store.continuePlayingSummary(for: "metroid-fusion"))
        XCTAssertEqual(continueSummary.primaryProgressLine, "AQA Security Access Shaft")
        XCTAssertEqual(continueSummary.supportingStateLine, "HP 34/99")
        XCTAssertEqual(continueSummary.badgeText, "Exploration")
    }

    func testMetroidZeroMissionSummaryBuildsAreaAndHealthContext() throws {
        let store = PlayInsightsStore(fileURL: tempURL)
        let now = Date(timeIntervalSince1970: 1_700_301_900)

        store.recordSession(
            .init(
                gameId: "metroid-zero",
                gameTitle: "Metroid: Zero Mission",
                system: "gba",
                supportedGame: .metroidZeroMission,
                startedAt: now.addingTimeInterval(-840),
                endedAt: now,
                durationSeconds: 840,
                deaths: 1,
                damageEvents: 3,
                snapshot: GameSpecificTelemetrySnapshot(
                    gameId: "metroid-zero",
                    timestamp: now,
                    payloadType: PlayInsightsSupportedGame.metroidZeroMission.profileID,
                    payloadJson: [
                        "area": 0x06,
                        "room": 0x1C,
                        "health": 34,
                        "maxHealth": 99
                    ]
                ),
                latestLocationSummary: nil
            )
        )

        let summary = try XCTUnwrap(store.summary(for: "metroid-zero"))
        XCTAssertEqual(summary.progressPrimaryValue, "Chozodia")
        XCTAssertEqual(summary.progressSecondaryValue, "Chozodia • HP 34/99")
        XCTAssertEqual(summary.currentRunPrimary, "Chozodia")
        XCTAssertEqual(summary.currentRunSecondary, "Chozodia • HP 34/99")
        XCTAssertEqual(summary.currentRunBadge, "Exploration")

        let continueSummary = try XCTUnwrap(store.continuePlayingSummary(for: "metroid-zero"))
        XCTAssertEqual(continueSummary.primaryProgressLine, "Chozodia")
        XCTAssertEqual(continueSummary.supportingStateLine, "HP 34/99")
        XCTAssertEqual(continueSummary.badgeText, "Exploration")
    }
}
