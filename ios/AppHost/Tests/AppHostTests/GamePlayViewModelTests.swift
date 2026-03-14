import XCTest
@testable import Xemu

@MainActor
final class GamePlayViewModelTests: XCTestCase {
    func testNDSFrameDimensionsMatchExpectedLayouts() {
        let stacked = GamePlayViewModel.ndsFrameDimensions(for: .stacked)
        XCTAssertEqual(stacked.width, 256)
        XCTAssertEqual(stacked.height, 384)

        let sideBySide = GamePlayViewModel.ndsFrameDimensions(for: .sideBySide)
        XCTAssertEqual(sideBySide.width, 512)
        XCTAssertEqual(sideBySide.height, 192)

        let topOnly = GamePlayViewModel.ndsFrameDimensions(for: .topOnly)
        XCTAssertEqual(topOnly.width, 256)
        XCTAssertEqual(topOnly.height, 192)
    }

    func testResolvedNDSDisplayLayoutUsesRenderedStackedFrames() {
        let resolved = GamePlayViewModel.resolvedNDSDisplayLayout(
            renderedWidth: 256,
            renderedHeight: 384,
            fallback: .sideBySide
        )

        XCTAssertEqual(resolved, .stacked)
    }

    func testResolvedNDSDisplayLayoutUsesRenderedSideBySideFrames() {
        let resolved = GamePlayViewModel.resolvedNDSDisplayLayout(
            renderedWidth: 512,
            renderedHeight: 192,
            fallback: .stacked
        )

        XCTAssertEqual(resolved, .sideBySide)
    }

    func testResolvedNDSDisplayLayoutFallsBackForSingleScreenFrames() {
        let resolved = GamePlayViewModel.resolvedNDSDisplayLayout(
            renderedWidth: 256,
            renderedHeight: 192,
            fallback: .bottomOnly
        )

        XCTAssertEqual(resolved, .bottomOnly)
    }
}
