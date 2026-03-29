import XCTest
@testable import Xemu

final class PlayerProgressStoreTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("player-progress-")
            .appendingPathExtension(UUID().uuidString)
    }

    override func tearDown() {
        if let tempURL {
            try? FileManager.default.removeItem(at: tempURL)
        }
        tempURL = nil
        super.tearDown()
    }

    func testRecordSessionUnlocksPowerOnAndFirstHour() {
        let store = PlayerProgressStore(fileURL: tempURL)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        let firstUnlocks = store.recordSession(
            gameID: "mario",
            gameTitle: "Mario",
            system: "gba",
            startTime: start,
            endTime: start.addingTimeInterval(1_800),
            durationSeconds: 1_800
        )
        XCTAssertTrue(firstUnlocks.contains(where: { $0.id == "power-on" }))
        XCTAssertFalse(firstUnlocks.contains(where: { $0.id == "first-hour" }))

        let secondUnlocks = store.recordSession(
            gameID: "mario",
            gameTitle: "Mario",
            system: "gba",
            startTime: start.addingTimeInterval(2_000),
            endTime: start.addingTimeInterval(4_100),
            durationSeconds: 2_100
        )
        XCTAssertTrue(secondUnlocks.contains(where: { $0.id == "first-hour" }))
        XCTAssertEqual(store.currentSnapshot().sessions.count, 2)
    }

    func testSessionAndGameMilestonesUnlock() {
        let store = PlayerProgressStore(fileURL: tempURL)
        let base = Date(timeIntervalSince1970: 1_700_100_000)

        for index in 0..<10 {
            let gameID: String
            switch index % 3 {
            case 0: gameID = "zelda"
            case 1: gameID = "metroid"
            default: gameID = "kirby"
            }
            _ = store.recordSession(
                gameID: gameID,
                gameTitle: gameID,
                system: "nds",
                startTime: base.addingTimeInterval(Double(index) * 700),
                endTime: base.addingTimeInterval(Double(index) * 700 + 600),
                durationSeconds: 600
            )
        }

        let snapshot = store.currentSnapshot()
        XCTAssertEqual(snapshot.sessions.count, 10)
        XCTAssertNotNil(snapshot.unlockedAchievementDates["dedicated-player"])
        XCTAssertNotNil(snapshot.unlockedAchievementDates["game-sampler"])
    }

    func testPersistenceAcrossStoreInstances() {
        let base = Date(timeIntervalSince1970: 1_700_200_000)
        let firstStore = PlayerProgressStore(fileURL: tempURL)
        _ = firstStore.recordSession(
            gameID: "pokemon",
            gameTitle: "Pokemon",
            system: "gb",
            startTime: base,
            endTime: base.addingTimeInterval(3_700),
            durationSeconds: 3_700
        )

        let secondStore = PlayerProgressStore(fileURL: tempURL)
        let snapshot = secondStore.currentSnapshot()
        XCTAssertEqual(snapshot.sessions.count, 1)
        XCTAssertNotNil(snapshot.unlockedAchievementDates["power-on"])
        XCTAssertNotNil(snapshot.unlockedAchievementDates["first-hour"])
    }

    func testAchievementDefinitionUsesProvidedLanguageManager() {
        let suiteName = "PlayerProgressStoreTests.Language.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let languageManager = LanguageManager(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["zh-Hans"] }
        )
        languageManager.setLanguage(.zhHans)

        let definition = PlayerProgressStore.achievementDefinitions.first { $0.id == "power-on" }
        XCTAssertEqual(definition?.localizedTitle(languageManager: languageManager), "开机启动")
        XCTAssertEqual(definition?.localizedDetail(languageManager: languageManager), "启动你的第一款复古游戏")
    }
}
