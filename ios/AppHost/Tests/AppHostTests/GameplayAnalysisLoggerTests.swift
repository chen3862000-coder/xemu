import XCTest
@testable import Xemu

final class GameplayAnalysisLoggerTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: "settings.dev.gameplayEventLogging")
    }

    func testIsEnabledReadsDeveloperToggle() {
        UserDefaults.standard.set(true, forKey: "settings.dev.gameplayEventLogging")

        XCTAssertTrue(GameplayAnalysisLogger.isEnabled)

        UserDefaults.standard.set(false, forKey: "settings.dev.gameplayEventLogging")

        XCTAssertFalse(GameplayAnalysisLogger.isEnabled)
    }
}
