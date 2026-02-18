import XCTest
import Combine
@testable import AppHost

@MainActor
final class ExperimentalGatingManagerTests: XCTestCase {

    var gatingManager: ExperimentalGatingManager!
    var entitlementCache: EntitlementCache!
    var dataStore: CompatibilityDataStore!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        gatingManager = ExperimentalGatingManager.shared
        entitlementCache = EntitlementCache()
        dataStore = CompatibilityDataStore.shared
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        gatingManager = nil
        entitlementCache = nil
        dataStore = nil
        cancellables = nil
        super.tearDown()
    }

    func testSingletonInstance() {
        let instance1 = ExperimentalGatingManager.shared
        let instance2 = ExperimentalGatingManager.shared
        XCTAssertTrue(instance1 === instance2)
    }

    func testCheckDeviceSupportReturnsValidClass() {
        let hardwareClass = gatingManager.checkDeviceSupport()

        XCTAssertNotNil(hardwareClass, "Device support should return a valid hardware class")
    }

    func testCheckDeviceSupportReturnsValidClasses() {
        let hardwareClass = gatingManager.checkDeviceSupport()

        let validClasses: [HardwareClass] = [.tier1, .tier2, .tier3, .unsupported]
        XCTAssertTrue(validClasses.contains(hardwareClass), "Hardware class should be one of the valid options")
    }

    func testHardwareTierComparison() {
        let tier1 = HardwareClass.tier1
        let tier2 = HardwareClass.tier2
        let tier3 = HardwareClass.tier3

        XCTAssertLessThan(tier1, tier2, "Tier 1 should be less than Tier 2")
        XCTAssertLessThan(tier2, tier3, "Tier 2 should be less than Tier 3")
    }

    func testExperimentalGatingResultInitialization() {
        let result = ExperimentalGatingResult(
            isAllowed: true,
            reason: "entitled",
            requiredEntitlement: nil
        )

        XCTAssertTrue(result.isAllowed)
        XCTAssertEqual(result.reason, "entitled")
        XCTAssertNil(result.requiredEntitlement)
    }

    func testExperimentalGatingResultWithRequiredEntitlement() {
        let result = ExperimentalGatingResult(
            isAllowed: false,
            reason: "missing_entitlement",
            requiredEntitlement: .experimentalPack
        )

        XCTAssertFalse(result.isAllowed)
        XCTAssertEqual(result.reason, "missing_entitlement")
        XCTAssertEqual(result.requiredEntitlement, .experimentalPack)
    }
}
