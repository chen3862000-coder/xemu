import XCTest
@testable import Xemu

final class MarioGameProfileTests: XCTestCase {
    func testSuperMarioAdvance2ProfileMatchesCanonicalTitle() {
        let profile = MarioGameProfile.activeProfile(
            title: "Super Mario Advance 2: Super Mario World",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.sma2SuperMarioWorld.id)
    }

    func testSuperMarioAdvance2ProfileMatchesNormalizedROMHash() {
        let profile = MarioGameProfile.activeProfile(
            title: "Mario",
            platform: .GBA,
            romHash: "super_mario_advance_2_europe"
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.sma2SuperMarioWorld.id)
    }

    func testProfilesIgnoreNonGBAPlatforms() {
        let profile = MarioGameProfile.activeProfile(
            title: "Super Mario Advance 2",
            platform: .GB,
            romHash: ""
        )

        XCTAssertNil(profile)
    }

    func testGameBoyProfilesDoNotCaptureGBAAdvanceTitles() {
        let profile = MarioGameProfile.activeProfile(
            title: "Super Mario Advance",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.superMarioAdvance.id)
    }

    func testMetroidFusionProfileMatchesMetroid4USATitle() {
        let profile = MarioGameProfile.activeProfile(
            title: "METROID4USA",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.metroidFusion.id)
    }

    func testCastlevaniaAriaOfSorrowProfileMatchesCanonicalTitle() {
        let profile = MarioGameProfile.activeProfile(
            title: "Castlevania: Aria of Sorrow",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.castlevaniaAriaOfSorrow.id)
    }

}
