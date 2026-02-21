import XCTest
import Combine
import Network
@testable import Xemu

@MainActor
final class OfflineGraceManagerTests: XCTestCase {

    var manager: OfflineGraceManager!
    var entitlementCache: EntitlementCache!
    var deviceProfileCache: DeviceProfileCache!

    override func setUp() {
        super.setUp()
        entitlementCache = EntitlementCache()
        deviceProfileCache = DeviceProfileCache.shared
        manager = OfflineGraceManager(
            entitlementCache: entitlementCache,
            deviceProfileCache: deviceProfileCache
        )
    }

    override func tearDown() {
        manager = nil
        entitlementCache = nil
        deviceProfileCache = nil
        super.tearDown()
    }

    func testCanLaunchGameNoGracePeriod() {
        manager.gracePeriodEnd = nil
        let canLaunch = manager.canLaunchGame()
        XCTAssertFalse(canLaunch)
    }

    func testCanLaunchGameWithinGracePeriod() {
        let futureDate = Date().addingTimeInterval(86400 * 5)
        manager.gracePeriodEnd = futureDate
        let canLaunch = manager.canLaunchGame()
        XCTAssertTrue(canLaunch)
    }

    func testCanLaunchGameGraceExpired() {
        let pastDate = Date().addingTimeInterval(-86400)
        manager.gracePeriodEnd = pastDate
        let canLaunch = manager.canLaunchGame()
        XCTAssertFalse(canLaunch)
    }

    func testCanLaunchWithOfflineGraceNoGracePeriod() {
        manager.gracePeriodEnd = nil
        let (canLaunch, daysRemaining) = manager.canLaunchWithOfflineGrace()
        XCTAssertFalse(canLaunch)
        XCTAssertEqual(daysRemaining, 0)
    }

    func testCanLaunchWithOfflineGraceWithinPeriod() {
        let futureDate = Date().addingTimeInterval(86400 * 5)
        manager.gracePeriodEnd = futureDate
        let (canLaunch, daysRemaining) = manager.canLaunchWithOfflineGrace()
        XCTAssertTrue(canLaunch)
        XCTAssertGreaterThan(daysRemaining, 0)
    }

    func testCanLaunchWithOfflineGraceExpired() {
        let pastDate = Date().addingTimeInterval(-86400)
        manager.gracePeriodEnd = pastDate
        let (canLaunch, daysRemaining) = manager.canLaunchWithOfflineGrace()
        XCTAssertFalse(canLaunch)
        XCTAssertLessThanOrEqual(daysRemaining, 0)
    }

    func testDaysRemainingCalculation() {
        let futureDate = Date().addingTimeInterval(86400 * 3)
        manager.gracePeriodEnd = futureDate
        let (canLaunch, daysRemaining) = manager.canLaunchWithOfflineGrace()
        XCTAssertTrue(canLaunch)
        XCTAssertGreaterThanOrEqual(daysRemaining, 2)
    }

    func testStartMonitoring() {
        XCTAssertNoThrow(manager.startMonitoring())
    }

    func testStopMonitoring() {
        manager.startMonitoring()
        XCTAssertNoThrow(manager.stopMonitoring())
    }

    func testIsOfflinePublished() {
        manager.isOffline = true
        XCTAssertTrue(manager.isOffline)
    }

    func testGracePeriodEndPublished() {
        let futureDate = Date().addingTimeInterval(86400)
        manager.gracePeriodEnd = futureDate
        XCTAssertNotNil(manager.gracePeriodEnd)
    }

    func testDaysRemainingPublished() {
        manager.daysRemaining = 5
        XCTAssertEqual(manager.daysRemaining, 5)
    }

    func testShouldShowWarningPublished() {
        manager.shouldShowWarning = true
        XCTAssertTrue(manager.shouldShowWarning)
    }

    func testWarningMessagePublished() {
        manager.warningMessage = "Test warning"
        XCTAssertEqual(manager.warningMessage, "Test warning")
    }
}
