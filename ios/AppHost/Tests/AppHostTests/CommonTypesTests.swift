import XCTest
@testable import Xemu

final class CommonTypesTests: XCTestCase {

    func testPlatformEnumCases() {
        XCTAssertEqual(Platform.NES.rawValue, "NES")
        XCTAssertEqual(Platform.GB.rawValue, "GB")
        XCTAssertEqual(Platform.GBA.rawValue, "GBA")
        XCTAssertEqual(Platform.GENESIS.rawValue, "GENESIS")
        XCTAssertEqual(Platform.NDS.rawValue, "NDS")
        XCTAssertEqual(Platform.PS1.rawValue, "PS1")
        XCTAssertEqual(Platform.PS2.rawValue, "PS2")
        XCTAssertEqual(Platform._3DS.rawValue, "3DS")
    }

    func testPlatformEnumDecoding() {
        XCTAssertEqual(Platform(rawValue: "NES"), .NES)
        XCTAssertEqual(Platform(rawValue: "GB"), .GB)
        XCTAssertEqual(Platform(rawValue: "GBA"), .GBA)
        XCTAssertEqual(Platform(rawValue: "GENESIS"), .GENESIS)
        XCTAssertEqual(Platform(rawValue: "NDS"), .NDS)
        XCTAssertEqual(Platform(rawValue: "PS1"), .PS1)
        XCTAssertEqual(Platform(rawValue: "PS2"), .PS2)
        XCTAssertEqual(Platform(rawValue: "3DS"), ._3DS)
        XCTAssertNil(Platform(rawValue: "UNKNOWN"))
    }

    func testTierEnumCases() {
        XCTAssertEqual(Tier.stable.rawValue, "stable")
        XCTAssertEqual(Tier.experimental.rawValue, "experimental")
        XCTAssertEqual(Tier.unknown.rawValue, "unknown")
    }

    func testCompletionStateEnumCases() {
        XCTAssertEqual(CompletionState.notStarted.rawValue, "NotStarted")
        XCTAssertEqual(CompletionState.inProgress.rawValue, "InProgress")
        XCTAssertEqual(CompletionState.completed.rawValue, "Completed")
        XCTAssertEqual(CompletionState.mastered.rawValue, "Mastered")
    }

    func testSessionModeEnumCases() {
        XCTAssertEqual(SessionMode.singlePlayer.rawValue, "SinglePlayer")
        XCTAssertEqual(SessionMode.legit.rawValue, "Legit")
        XCTAssertEqual(SessionMode.multiplayerHost.rawValue, "MultiplayerHost")
        XCTAssertEqual(SessionMode.multiplayerGuest.rawValue, "MultiplayerGuest")
    }

    func testSessionVerdictEnumCases() {
        XCTAssertEqual(SessionVerdict.pending.rawValue, "Pending")
        XCTAssertEqual(SessionVerdict.valid.rawValue, "Valid")
        XCTAssertEqual(SessionVerdict.invalid.rawValue, "Invalid")
        XCTAssertEqual(SessionVerdict.flagged.rawValue, "Flagged")
    }

    func testEntitlementStatusEnumCases() {
        XCTAssertEqual(EntitlementStatus.active.rawValue, "Active")
        XCTAssertEqual(EntitlementStatus.revoked.rawValue, "Revoked")
        XCTAssertEqual(EntitlementStatus.refunded.rawValue, "Refunded")
        XCTAssertEqual(EntitlementStatus.expired.rawValue, "Expired")
    }

    func testProductCodeEnumCases() {
        XCTAssertEqual(ProductCode.removeAds.rawValue, "REMOVE_ADS")
        XCTAssertEqual(ProductCode.experimentalPack.rawValue, "EXPERIMENTAL_PACK")
        XCTAssertEqual(ProductCode.proBundle.rawValue, "PRO_BUNDLE")
    }

    func testHardwareClassEnumCases() {
        XCTAssertEqual(HardwareClass.tier1.rawValue, "Tier1")
        XCTAssertEqual(HardwareClass.tier2.rawValue, "Tier2")
        XCTAssertEqual(HardwareClass.tier3.rawValue, "Tier3")
        XCTAssertEqual(HardwareClass.unsupported.rawValue, "Unsupported")
    }
}
