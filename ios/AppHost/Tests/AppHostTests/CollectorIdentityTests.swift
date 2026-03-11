import XCTest
@testable import Xemu

final class CollectorIdentityTests: XCTestCase {
    func testNormalizedSystemCodeMapsGameBoyAliasesToGBC() {
        let aliases = ["gb", "GBC", " GB/GBC ", "game boy", "Game Boy + Color"]
        for alias in aliases {
            XCTAssertEqual(SubpageUI.CollectorIdentity.normalizedSystemCode(alias), "gbc")
        }
    }

    func testNormalizedSystemCodeMapsGBAAndNDSAliases() {
        XCTAssertEqual(SubpageUI.CollectorIdentity.normalizedSystemCode("game boy advance"), "gba")
        XCTAssertEqual(SubpageUI.CollectorIdentity.normalizedSystemCode("Nintendo DS"), "nds")
    }

    func testNormalizedSystemCodeTrimsLowercasesAndPassesUnknownThrough() {
        XCTAssertEqual(SubpageUI.CollectorIdentity.normalizedSystemCode("  sFc  "), "sfc")
        XCTAssertEqual(SubpageUI.CollectorIdentity.normalizedSystemCode(nil), "")
    }

    func testAccentHexReturnsExpectedPaletteValues() {
        XCTAssertEqual(SubpageUI.CollectorIdentity.accentHex(forSystem: "gb"), SubpageUI.CollectorIdentity.gbHex)
        XCTAssertEqual(SubpageUI.CollectorIdentity.accentHex(forSystem: "GBA"), SubpageUI.CollectorIdentity.gbaHex)
        XCTAssertEqual(SubpageUI.CollectorIdentity.accentHex(forSystem: "nds"), SubpageUI.CollectorIdentity.ndsHex)
    }

    func testAccentHexUsesFallbackForUnknownSystems() {
        XCTAssertEqual(SubpageUI.CollectorIdentity.accentHex(forSystem: "ps1"), SubpageUI.CollectorIdentity.fallbackHex)
        XCTAssertEqual(SubpageUI.CollectorIdentity.accentHex(forSystem: nil), SubpageUI.CollectorIdentity.fallbackHex)
    }

    func testCollectorCardCoverAspectRatioUsesBoxArtProportions() {
        XCTAssertEqual(AllGamesCard.collectorCoverAspectRatio, 0.75, accuracy: 0.000_1)
    }

    func testCollectorShelfGroupingKeepsSupportedSystemsInCollectorOrder() {
        let systems = ["nds", "gba", "gb", "ps1", "gbc"]
        XCTAssertEqual(
            CollectorShelfGrouping.orderedSectionKeys(for: systems),
            ["gbc", "gba", "nds", "ps1"]
        )
    }

    func testCollectorShelfGroupingMapsAliasesToFriendlyTitles() {
        XCTAssertEqual(CollectorShelfGrouping.sectionKey(for: "Game Boy"), "gbc")
        XCTAssertEqual(CollectorShelfGrouping.sectionKey(for: "Game Boy Advance"), "gba")
        XCTAssertEqual(CollectorShelfGrouping.sectionTitle(for: "gbc"), "Game Boy + Color Collection")
        XCTAssertEqual(CollectorShelfGrouping.sectionTitle(for: "nds"), "Nintendo DS Collection")
    }
}
