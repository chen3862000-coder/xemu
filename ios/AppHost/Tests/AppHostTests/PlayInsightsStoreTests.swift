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
                        "level": 0x15
                    ]
                ),
                latestLocationSummary: "Loc Donut Plains • level 15"
            )
        )

        let summary = try XCTUnwrap(store.summary(for: "sma2"))
        XCTAssertTrue(summary.playInsightsEnabled)
        XCTAssertEqual(summary.progressPrimaryValue, "Donut Plains")
        XCTAssertEqual(summary.progressSecondaryValue, "Stage 2A")
        XCTAssertEqual(summary.currentRunPrimary, "Donut Plains • Stage 2A")
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
                    payloadJson: ["map": 0x01, "level": 0x00]
                ),
                latestLocationSummary: "Loc Donut Plains • level 00"
            )
        )

        let initialSummary = try XCTUnwrap(store.summary(for: "sma2"))
        XCTAssertEqual(initialSummary.progressPrimaryValue, "Donut Plains")
        XCTAssertEqual(initialSummary.progressSecondaryValue, "Stage 1")
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
                    payloadJson: ["map": 0x01, "level": 0x15]
                ),
                latestLocationSummary: "Loc Donut Plains • level 15"
            )
        )

        let refreshedSummary = try XCTUnwrap(store.summary(for: "sma2"))
        XCTAssertEqual(refreshedSummary.progressPrimaryValue, "Donut Plains")
        XCTAssertEqual(refreshedSummary.progressSecondaryValue, "Stage 2A")
        XCTAssertEqual(refreshedSummary.currentRunPrimary, "Donut Plains • Stage 2A")
    }
}
