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

    func testMetroidZeroMissionProfileMatchesROMHeaderTitle() {
        let profile = MarioGameProfile.activeProfile(
            title: "ZEROMISSIONE",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.metroidZeroMission.id)
    }

    func testDragonBallAdvancedAdventureProfileMatchesCanonicalTitle() {
        let profile = MarioGameProfile.activeProfile(
            title: "Dragon Ball: Advanced Adventure",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.dragonBallAdvancedAdventure.id)
    }

    func testDragonBallAdvancedAdventureProfileMatchesROMHeaderTitle() {
        let profile = MarioGameProfile.activeProfile(
            title: "DRAGONBALLAA",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.dragonBallAdvancedAdventure.id)
    }

    func testDragonBallAdvancedAdventureProfileMatchesKnownROMHash() {
        let profile = MarioGameProfile.activeProfile(
            title: "Dragon Ball",
            platform: .GBA,
            romHash: "015ab2129d6f4315b92b32fa29d8cead7195a51951945d87fbcc6f07149811c5"
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.dragonBallAdvancedAdventure.id)
    }

    func testCastlevaniaAriaOfSorrowProfileMatchesCanonicalTitle() {
        let profile = MarioGameProfile.activeProfile(
            title: "Castlevania: Aria of Sorrow",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.castlevaniaAriaOfSorrow.id)
    }

    func testCastlevaniaCircleOfTheMoonProfileMatchesCanonicalTitle() {
        let profile = MarioGameProfile.activeProfile(
            title: "Castlevania: Circle of the Moon",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.castlevaniaCircleOfTheMoon.id)
    }

    func testCastlevaniaHarmonyOfDissonanceProfileMatchesCanonicalTitle() {
        let profile = MarioGameProfile.activeProfile(
            title: "Castlevania: Harmony of Dissonance",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.castlevaniaHarmonyOfDissonance.id)
    }

    func testOnePieceProfileMatchesCanonicalTitle() {
        let profile = MarioGameProfile.activeProfile(
            title: "Shonen Jump's One Piece",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.onePiece.id)
    }

    func testKingdomHeartsChainOfMemoriesProfileMatchesCanonicalTitle() {
        let profile = MarioGameProfile.activeProfile(
            title: "Kingdom Hearts: Chain of Memories",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.kingdomHeartsChainOfMemories.id)
    }

    func testZeldaMinishCapProfileMatchesCanonicalTitle() {
        let profile = MarioGameProfile.activeProfile(
            title: "The Legend of Zelda: The Minish Cap",
            platform: .GBA,
            romHash: ""
        )

        XCTAssertEqual(profile?.id, MarioGameProfile.zeldaMinishCap.id)
    }

}
