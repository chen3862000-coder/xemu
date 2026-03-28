import XCTest
@testable import Xemu

final class MemoryAddressDiscoveryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MemoryAddressDiscovery.shared.clearCache()
    }

    override func tearDown() {
        MemoryAddressDiscovery.shared.clearCache()
        super.tearDown()
    }

    func testDiscoveryStatsReflectCachedEntries() async {
        let discovery = MemoryAddressDiscovery.shared

        let addresses = await discovery.discoverAddresses(
            for: "Super Mario Advance",
            platform: .GBA,
            romHash: "abc123"
        )

        XCTAssertNotNil(addresses)
        let stats = discovery.getDiscoveryStats()
        XCTAssertGreaterThanOrEqual(stats.totalGamesCached, 1)
        XCTAssertNotEqual(stats.lastDiscoveryTime, .distantPast)
    }

    func testValidateAddressesUpdatesSuccessRate() {
        let discovery = MemoryAddressDiscovery.shared
        let addresses = CachedMemoryAddresses(
            livesAddress: 0,
            healthAddress: nil,
            powerUpAddress: nil,
            levelAddress: nil,
            scoreAddress: nil,
            lastUpdate: Date()
        )

        XCTAssertTrue(discovery.validateAddresses(addresses, for: "Test Game", saveStateData: Data([3, 0, 0])))

        let stats = discovery.getDiscoveryStats()
        XCTAssertEqual(stats.validationSuccessRate, 1.0)
    }
}
