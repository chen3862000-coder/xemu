import XCTest
import Combine
@testable import AppHost

@MainActor
final class AdsPolicyControllerTests: XCTestCase {

    var controller: AdsPolicyController!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        controller = AdsPolicyController()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        controller = nil
        cancellables = nil
        super.tearDown()
    }

    func testAdPlacementLibraryBanner() {
        let placement = AdsPolicyController.AdPlacement.libraryBanner
        let canShow = controller.shouldShowAd(for: placement)
        XCTAssertTrue(canShow)
    }

    func testAdPlacementInterstitial() {
        let placement = AdsPolicyController.AdPlacement.interstitial
        let canShow = controller.shouldShowAd(for: placement)
        XCTAssertFalse(canShow)
    }

    func testMarkAdShown() {
        let placement = AdsPolicyController.AdPlacement.interstitial
        controller.markAdShown(for: placement)
        let canShowAgain = controller.shouldShowAd(for: placement)
        XCTAssertFalse(canShowAgain)
    }

    func testRecordAdLoadFailed() {
        let placement = AdsPolicyController.AdPlacement.preLaunchInterstitial
        controller.recordAdLoadFailed(for: placement)
    }

    func testResetToDefaults() {
        controller.markAdShown(for: .interstitial)
        let canShowBefore = controller.shouldShowAd(for: .interstitial)
        XCTAssertFalse(canShowBefore)
    }
}
