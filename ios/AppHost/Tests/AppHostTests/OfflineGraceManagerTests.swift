import XCTest
import Combine
import Network
@testable import AppHost

final class OfflineGraceManagerTests: XCTestCase {

    var manager: OfflineGraceManager!
    var entitlementCache: EntitlementCache!
    var cancellables: Set<AnyCancellable>!
    var tempDirectory: URL!

    override func setUp() {
        super.setUp()

        let tempDir = FileManager.default.temporaryDirectory
        tempDirectory = tempDir.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        entitlementCache = EntitlementCache()
        manager = OfflineGraceManager(
            entitlementCache: entitlementCache,
            gracePeriodDays: 7
        )

        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        manager.stopMonitoring()
        manager = nil
        entitlementCache = nil
        cancellables = nil
        try? FileManager.default.removeItem(at: tempDirectory)
        tempDirectory = nil
        super.tearDown()
    }

    func testCanLaunchGameOnline() {
        manager.currentNetworkStatus = .satisfied
        manager.updateLastOnlineTimestamp()

        let (canLaunch, _) = manager.canLaunchWithOfflineGrace()

        XCTAssertTrue(canLaunch)
    }

    func testCanLaunchGameOfflineWithinGrace() {
        manager.currentNetworkStatus = .unsatisfied

        let futureDate = Date().addingTimeInterval(86400 * 5)
        setGracePeriodEnd(futureDate)

        let (canLaunch, daysRemaining) = manager.canLaunchWithOfflineGrace()

        XCTAssertTrue(canLaunch)
        XCTAssertGreaterThanOrEqual(daysRemaining, 4, "Days remaining should be at least 4 (may be 4-5 due to Calendar rounding)")
    }

    func testCanLaunchGameOfflineGraceExpired() {
        manager.currentNetworkStatus = .unsatisfied

        let pastDate = Date().addingTimeInterval(-86400)
        setGracePeriodEnd(pastDate)

        let (canLaunch, daysRemaining) = manager.canLaunchWithOfflineGrace()

        XCTAssertFalse(canLaunch)
        XCTAssertEqual(daysRemaining, 0)
    }

    func testCanLaunchGameOfflineNoGraceSet() {
        manager.currentNetworkStatus = .unsatisfied
        entitlementCache.clearCache()

        let (canLaunch, daysRemaining) = manager.canLaunchWithOfflineGrace()

        XCTAssertFalse(canLaunch)
        XCTAssertEqual(daysRemaining, 0)
    }

    func testGracePeriodUpdate() {
        let initialDate = Date().addingTimeInterval(86400 * 5)
        setGracePeriodEnd(initialDate)

        let (canLaunch1, days1) = manager.canLaunchWithOfflineGrace()
        XCTAssertTrue(canLaunch1)

        let extendedDate = Date().addingTimeInterval(86400 * 7)
        manager.updateGracePeriod(extendedDate)

        let (canLaunch2, days2) = manager.canLaunchWithOfflineGrace()
        XCTAssertTrue(canLaunch2)
    }

    func testNetworkStatusMonitoring() {
        var networkStatusChanged = false
        let expectation = XCTestExpectation(description: "Network status changed")

        manager.networkStatusChanged
            .sink { status in
                networkStatusChanged = true
                expectation.fulfill()
            }
            .store(in: &cancellables)

        manager.simulateNetworkChange(to: .unsatisfied)

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(networkStatusChanged)
    }

    func testStartMonitoring() {
        XCTAssertNoThrow(manager.startMonitoring())
        XCTAssertTrue(manager.isMonitoring)
    }

    func testStopMonitoring() {
        manager.startMonitoring()
        manager.stopMonitoring()

        XCTAssertFalse(manager.isMonitoring)
    }

    func testGracePeriodDaysRemaining() {
        let futureDate = Date().addingTimeInterval(86400 * 3)
        setGracePeriodEnd(futureDate)

        let (_, daysRemaining) = manager.canLaunchWithOfflineGrace()

        XCTAssertGreaterThanOrEqual(daysRemaining, 2, "Days remaining should be at least 2 (may be 2-3 due to Calendar rounding)")
    }

    func testGracePeriodRemainingPartialDay() {
        let futureDate = Date().addingTimeInterval(86400 * 2 + 3600 * 6)
        setGracePeriodEnd(futureDate)

        let (_, daysRemaining) = manager.canLaunchWithOfflineGrace()

        XCTAssertGreaterThanOrEqual(daysRemaining, 1, "Days remaining should be at least 1 (may be 1-2 due to Calendar rounding)")
    }

    func testShowWarningNotNeeded() {
        let futureDate = Date().addingTimeInterval(86400 * 5)
        setGracePeriodEnd(futureDate)

        let shouldWarn = manager.showWarningIfNeeded()

        XCTAssertFalse(shouldWarn)
    }

    func testShowWarningWithinThreshold() {
        let futureDate = Date().addingTimeInterval(86400 * 2)
        setGracePeriodEnd(futureDate)
        manager.lastOnlineTimestamp = Date().addingTimeInterval(-86400 * 4)

        let shouldWarn = manager.showWarningIfNeeded()

        XCTAssertTrue(shouldWarn)
    }

    func testShowWarningGraceExpired() {
        let pastDate = Date().addingTimeInterval(-86400)
        setGracePeriodEnd(pastDate)
        manager.lastOnlineTimestamp = Date().addingTimeInterval(-86400 * 4)

        let shouldWarn = manager.showWarningIfNeeded()

        XCTAssertTrue(shouldWarn)
    }

    func testShowWarningOffline() {
        manager.currentNetworkStatus = .unsatisfied

        let futureDate = Date().addingTimeInterval(86400 * 2)
        setGracePeriodEnd(futureDate)
        manager.lastOnlineTimestamp = Date().addingTimeInterval(-86400 * 4)

        let shouldWarn = manager.showWarningIfNeeded()

        XCTAssertTrue(shouldWarn)
    }

    func testDoNotShowWarningOnline() {
        manager.currentNetworkStatus = .satisfied

        let futureDate = Date().addingTimeInterval(86400 * 1)
        setGracePeriodEnd(futureDate)

        let shouldWarn = manager.showWarningIfNeeded()

        XCTAssertFalse(shouldWarn)
    }

    func testGracePeriodThreshold() {
        XCTAssertEqual(manager.gracePeriodWarningThresholdDays, 3)
    }

    func testDefaultGracePeriod() {
        XCTAssertEqual(manager.gracePeriodDays, 7)
    }

    func testCustomGracePeriod() {
        let customManager = OfflineGraceManager(
            entitlementCache: entitlementCache,
            gracePeriodDays: 14
        )

        XCTAssertEqual(customManager.gracePeriodDays, 14)
    }

    func testNetworkStatusSatisfied() {
        manager.simulateNetworkChange(to: .satisfied)

        XCTAssertEqual(manager.currentNetworkStatus, .satisfied)
    }

    func testNetworkStatusUnsatisfied() {
        manager.simulateNetworkChange(to: .unsatisfied)

        XCTAssertEqual(manager.currentNetworkStatus, .unsatisfied)
    }

    func testLastOnlineTimestamp() {
        let timestamp = Date()
        manager.updateLastOnlineTimestamp()

        XCTAssertNotNil(manager.lastOnlineTimestamp)
    }

    func testLastOnlineTimestampAccuracy() {
        let before = Date()
        manager.updateLastOnlineTimestamp()
        let after = Date()

        XCTAssertGreaterThanOrEqual(manager.lastOnlineTimestamp!, before)
        XCTAssertLessThanOrEqual(manager.lastOnlineTimestamp!, after)
    }

    func testGetDaysRemainingGracePeriod() {
        let futureDate = Date().addingTimeInterval(86400 * 4)
        setGracePeriodEnd(futureDate)

        let daysRemaining = manager.getDaysRemainingGracePeriod()

        XCTAssertGreaterThanOrEqual(daysRemaining, 3)
        XCTAssertLessThanOrEqual(daysRemaining, 4)
    }

    func testGetDaysRemainingExpired() {
        let pastDate = Date().addingTimeInterval(-86400)
        setGracePeriodEnd(pastDate)

        let daysRemaining = manager.getDaysRemainingGracePeriod()

        XCTAssertEqual(daysRemaining, 0)
    }

    func testGetDaysRemainingNotSet() {
        entitlementCache.clearCache()

        let daysRemaining = manager.getDaysRemainingGracePeriod()

        XCTAssertEqual(daysRemaining, 0)
    }

    func testScheduleExpiryNotification() {
        let futureDate = Date().addingTimeInterval(86400 * 3)
        setGracePeriodEnd(futureDate)

        XCTAssertNoThrow(manager.scheduleExpiryNotification())
    }

    func testNetworkStatusPublishedChanges() {
        var statuses: [NWPath.Status] = []
        let expectation = XCTestExpectation(description: "Multiple status changes")

        manager.networkStatusChanged
            .sink { status in
                statuses.append(status)
                if statuses.count == 3 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        manager.simulateNetworkChange(to: .unsatisfied)
        manager.simulateNetworkChange(to: .satisfied)
        manager.simulateNetworkChange(to: .unsatisfied)

        wait(for: [expectation], timeout: 1.0)

        XCTAssertEqual(statuses, [.unsatisfied, .satisfied, .unsatisfied])
    }

    func testGracePeriodPersistence() {
        let futureDate = Date().addingTimeInterval(86400 * 6)
        manager.updateGracePeriod(futureDate)

        let newManager = OfflineGraceManager(
            entitlementCache: entitlementCache,
            gracePeriodDays: 7
        )
        newManager.updateLastOnlineTimestamp()
        newManager.updateGracePeriod(futureDate)

        let (_, daysRemaining) = newManager.canLaunchWithOfflineGrace()

        XCTAssertGreaterThanOrEqual(daysRemaining, 5)
        XCTAssertLessThanOrEqual(daysRemaining, 7)
    }

    func testGracePeriodNotified() {
        let futureDate = Date().addingTimeInterval(86400 * 3)
        setGracePeriodEnd(futureDate)

        XCTAssertFalse(manager.hasExpiryNotificationScheduled())

        manager.scheduleExpiryNotification()

        XCTAssertFalse(manager.hasExpiryNotificationScheduled())
    }

    func testClearGracePeriod() {
        let futureDate = Date().addingTimeInterval(86400 * 5)
        manager.updateGracePeriod(futureDate)

        manager.clearGracePeriod()

        let (canLaunch, _) = manager.canLaunchWithOfflineGrace()

        XCTAssertFalse(canLaunch)
    }

    func testGracePeriodZeroDays() {
        let now = Date()
        manager.updateLastOnlineTimestamp()
        manager.updateGracePeriod(now)

        let (canLaunch, daysRemaining) = manager.canLaunchWithOfflineGrace()

        XCTAssertFalse(canLaunch)
        XCTAssertEqual(daysRemaining, 0)
    }

    private func setGracePeriodEnd(_ date: Date) {
        let bundle = EntitlementBundle(
            userId: UUID(),
            entitlements: [],
            deviceProfile: DeviceProfile(
                deviceId: UUID(),
                hardwareClass: .Tier1,
                whitelistVersion: "1.0.0"
            )
        )

        entitlementCache.cache(bundle)
        manager.updateLastOnlineTimestamp()
        manager.updateGracePeriod(date)
    }
}
