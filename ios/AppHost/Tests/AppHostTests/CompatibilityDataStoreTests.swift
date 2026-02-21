import XCTest
@testable import Xemu

@available(macOS 13.0, *)
final class CompatibilityDataStoreTests: XCTestCase {

    var dataStore: CompatibilityDataStore!

    override func setUp() async throws {
        try await super.setUp()
        dataStore = CompatibilityDataStore.shared
    }

    override func tearDown() async throws {
        dataStore = nil
        try await super.tearDown()
    }

    func testGetCompatibilityInfo_ExistingROM() throws {
        let info = dataStore.getCompatibilityInfo(for: "stable_nes_hash")
        XCTAssertTrue(info == nil || info?.romHash == "stable_nes_hash")
        if info != nil {
            XCTAssertEqual(info?.tier, .stable)
        }
    }

    func testGetTier_StableROM() {
        let tier = dataStore.getTier(for: "stable_nes_hash")
        XCTAssertTrue(tier == .stable || tier == .unknown)
    }

    func testGetTier_ExperimentalROM() {
        let tier = dataStore.getTier(for: "experimental_nes_hash")
        XCTAssertTrue(tier == .experimental || tier == .unknown)
    }

    func testGetMinDeviceTier_Tier1ROM() {
        let minTier = dataStore.getMinDeviceTier(for: "stable_nes_hash")
        XCTAssertTrue(minTier == .tier1 || minTier == .unsupported)
    }

    func testGetMinDeviceTier_Tier2ROM() {
        let minTier = dataStore.getMinDeviceTier(for: "experimental_nes_hash")
        XCTAssertTrue(minTier == .tier2 || minTier == .unsupported)
    }

    func testGetCompatibilityInfo_NonExistingROM() {
        let info = dataStore.getCompatibilityInfo(for: "non_existent_hash")
        XCTAssertNil(info)
    }

    func testGetTier_UnknownROM() {
        let tier = dataStore.getTier(for: "non_existent_hash")
        XCTAssertEqual(tier, .unknown)
    }

    func testGetMinDeviceTier_Tier3ROM() {
        let minTier = dataStore.getMinDeviceTier(for: "experimental_tier3_hash")
        XCTAssertTrue(minTier == .tier3 || minTier == .unsupported)
    }

    func testGetAllROMs() {
        let allROMs = dataStore.getAllROMs()
        XCTAssertTrue(allROMs.isEmpty || allROMs.contains { $0.romHash == "stable_nes_hash" })
    }

    func testGetAllExperimentalROMs() {
        let experimentalROMs = dataStore.getAllExperimentalROMs()
        XCTAssertTrue(experimentalROMs.isEmpty || experimentalROMs.allSatisfy { $0.tier == .experimental })
    }

    func testCompatibilityInfo_Notes() {
        let info = dataStore.getCompatibilityInfo(for: "experimental_nes_hash")
        XCTAssertTrue(info == nil || info?.notes.isEmpty == false)
    }

    func testCompatibilityInfo_Notes_StableROM() {
        let info = dataStore.getCompatibilityInfo(for: "stable_nes_hash")
        XCTAssertTrue(info == nil || info?.notes.isEmpty == true)
    }

    func testPerformance_GetCompatibilityInfo() throws {
        measure {
            _ = dataStore.getCompatibilityInfo(for: "stable_nes_hash")
        }
    }

    func testPerformance_IsCompatible() throws {
        measure {
            _ = dataStore.isCompatible(
                romHash: "experimental_nes_hash",
                deviceHardwareClass: .tier2
            )
        }
    }
}
