import XCTest
import Combine
@testable import AppHost

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

    func testAdPlacementPreLaunchInterstitial() {
        let placement = AdsPolicyController.AdPlacement.preLaunchInterstitial

        let canShow = controller.shouldShowAd(for: placement)

        XCTAssertTrue(canShow)
    }

    func testAdPlacementInterstitial() {
        let placement = AdsPolicyController.AdPlacement.interstitial

        let canShow = controller.shouldShowAd(for: placement)

        XCTAssertTrue(canShow)
    }

    func testAdFreeEntitlementBlocksAds() {
        controller.userHasAdFreeEntitlement = true

        let canShowBanner = controller.shouldShowAd(for: .libraryBanner)
        let canShowPreLaunch = controller.shouldShowAd(for: .preLaunchInterstitial)
        let canShowInterstitial = controller.shouldShowAd(for: .interstitial)

        XCTAssertFalse(canShowBanner)
        XCTAssertFalse(canShowPreLaunch)
        XCTAssertFalse(canShowInterstitial)
    }

    func testUserPreferenceBlocksAds() {
        controller.adsEnabled = false

        let canShow = controller.shouldShowAd(for: .libraryBanner)

        XCTAssertFalse(canShow)
    }

    func testMarkAdShown() {
        let placement = AdsPolicyController.AdPlacement.preLaunchInterstitial

        controller.markAdShown(for: placement)

        let canShowAgain = controller.shouldShowAd(for: placement)

        XCTAssertFalse(canShowAgain)
    }

    func testAdFrequencyCappingPreLaunch() {
        let placement = AdsPolicyController.AdPlacement.preLaunchInterstitial

        controller.markAdShown(for: placement)

        let canShowImmediately = controller.shouldShowAd(for: placement)
        XCTAssertFalse(canShowImmediately)

        let futureDate = Date().addingTimeInterval(31 * 60)
        controller.lastPreLaunchAdTime = futureDate.addingTimeInterval(-31 * 60)

        let canShowAfterCooldown = controller.shouldShowAd(for: placement)
        XCTAssertTrue(canShowAfterCooldown)
    }

    func testAdFrequencyCappingInterstitial() {
        let placement = AdsPolicyController.AdPlacement.interstitial

        controller.markAdShown(for: placement)

        let canShowImmediately = controller.shouldShowAd(for: placement)
        XCTAssertFalse(canShowImmediately)

        let futureDate = Date().addingTimeInterval(11 * 60)
        controller.lastInterstitialAdTime = futureDate.addingTimeInterval(-11 * 60)

        let canShowAfterCooldown = controller.shouldShowAd(for: placement)
        XCTAssertTrue(canShowAfterCooldown)
    }

    func testRemoveAdsEntitlement() {
        controller.entitlements = [.REMOVE_ADS]

        XCTAssertTrue(controller.hasAdFreeEntitlement())
    }

    func testProBundleEntitlement() {
        controller.entitlements = [.PRO_BUNDLE]

        XCTAssertTrue(controller.hasAdFreeEntitlement())
    }

    func testExperimentalPackDoesNotBlockAds() {
        controller.entitlements = [.EXPERIMENTAL_PACK]

        XCTAssertFalse(controller.hasAdFreeEntitlement())
    }

    func testNoEntitlement() {
        controller.entitlements = []

        XCTAssertFalse(controller.hasAdFreeEntitlement())
    }

    func testAdPreferencesPersistence() {
        controller.adsEnabled = false
        controller.freeTrialDays = 7

        XCTAssertTrue(controller.savePreferences())

        let reloaded = AdsPolicyController()
        XCTAssertFalse(reloaded.adsEnabled)
        XCTAssertEqual(reloaded.freeTrialDays, 7)
    }

    func testAdFreePeriodFromFreeTrial() {
        controller.freeTrialDays = 7

        let canShow = controller.shouldShowAd(for: .libraryBanner)

        XCTAssertFalse(canShow)
    }

    func testAdFreePeriodExpired() {
        controller.freeTrialDays = 0

        let canShow = controller.shouldShowAd(for: .libraryBanner)

        XCTAssertTrue(canShow)
    }

    func testResetAdFrequency() {
        let placement = AdsPolicyController.AdPlacement.preLaunchInterstitial
        controller.markAdShown(for: placement)

        controller.resetAdFrequency()

        let canShow = controller.shouldShowAd(for: placement)
        XCTAssertTrue(canShow)
    }

    func testAdCooldownPeriodPreLaunch() {
        XCTAssertEqual(controller.preLaunchAdCooldownMinutes, 30)
    }

    func testAdCooldownPeriodInterstitial() {
        XCTAssertEqual(controller.interstitialAdCooldownMinutes, 10)
    }

    func testMaxAdsPerSession() {
        XCTAssertEqual(controller.maxAdsPerSession, 5)
    }

    func testSessionAdTracking() {
        for _ in 0..<5 {
            controller.markAdShown(for: .libraryBanner)
        }

        let canShowMore = controller.shouldShowAd(for: .libraryBanner)

        XCTAssertFalse(canShowMore)
    }

    func testNewSessionResetsAdCount() {
        for _ in 0..<5 {
            controller.markAdShown(for: .libraryBanner)
        }

        controller.startNewSession()

        let canShowAgain = controller.shouldShowAd(for: .libraryBanner)
        XCTAssertTrue(canShowAgain)
    }

    func testAdScheduling() {
        controller.scheduleNextAd(for: .preLaunchInterstitial)

        XCTAssertNotNil(controller.nextAdScheduledTime)
    }

    func testClearAllAdTracking() {
        controller.markAdShown(for: .preLaunchInterstitial)
        controller.markAdShown(for: .interstitial)
        controller.markAdShown(for: .libraryBanner)

        controller.clearAllTracking()

        XCTAssertTrue(controller.shouldShowAd(for: .preLaunchInterstitial))
        XCTAssertTrue(controller.shouldShowAd(for: .interstitial))
        XCTAssertTrue(controller.shouldShowAd(for: .libraryBanner))
    }

    func testAdLoadFailureHandling() {
        controller.recordAdLoadFailed(for: .preLaunchInterstitial)

        let nextAdTime = controller.nextAdScheduledTime

        XCTAssertNotNil(nextAdTime)
        XCTAssertGreaterThan(nextAdTime!, Date())
    }

    func testAdImpressionTracking() {
        let placement = AdsPolicyController.AdPlacement.preLaunchInterstitial

        controller.recordAdImpression(for: placement)

        XCTAssertGreaterThan(controller.totalAdImpressions, 0)
    }

    func testMultipleEntitlements() {
        controller.entitlements = [.REMOVE_ADS, .EXPERIMENTAL_PACK, .PRO_BUNDLE]

        XCTAssertTrue(controller.hasAdFreeEntitlement())
    }

    func testEntitlementRevocation() {
        controller.entitlements = [.REMOVE_ADS, .PRO_BUNDLE]
        controller.revokeEntitlement(.REMOVE_ADS)

        XCTAssertTrue(controller.hasAdFreeEntitlement())
    }

    func testEntitlementRevocationAll() {
        controller.entitlements = [.REMOVE_ADS]
        controller.revokeEntitlement(.REMOVE_ADS)

        XCTAssertFalse(controller.hasAdFreeEntitlement())
    }

    func testLastShownTimestamps() {
        let placement1 = AdsPolicyController.AdPlacement.libraryBanner
        let placement2 = AdsPolicyController.AdPlacement.preLaunchInterstitial

        controller.markAdShown(for: placement1)
        controller.markAdShown(for: placement2)

        XCTAssertNotNil(controller.lastLibraryBannerTime)
        XCTAssertNotNil(controller.lastPreLaunchAdTime)
    }

    func testAdVisibilityState() {
        controller.setAdVisibility(true)

        XCTAssertTrue(controller.isAdVisible)
    }

    func testAdVisibilityBlocksNewAds() {
        controller.setAdVisibility(true)

        let canShow = controller.shouldShowAd(for: .preLaunchInterstitial)

        XCTAssertFalse(canShow)
    }

    func testAdDismissalResetsVisibility() {
        controller.setAdVisibility(true)
        controller.dismissAd()

        XCTAssertFalse(controller.isAdVisible)
    }

    func testAdAnalytics() {
        let placement = AdsPolicyController.AdPlacement.preLaunchInterstitial
        controller.recordAdImpression(for: placement)

        let analytics = controller.getAdAnalytics()

        XCTAssertGreaterThan(analytics["totalImpressions"] as? Int ?? 0, 0)
    }

    func testProductCodeStrings() {
        XCTAssertEqual(ProductCode.REMOVE_ADS.rawValue, "REMOVE_ADS")
        XCTAssertEqual(ProductCode.EXPERIMENTAL_PACK.rawValue, "EXPERIMENTAL_PACK")
        XCTAssertEqual(ProductCode.PRO_BUNDLE.rawValue, "PRO_BUNDLE")
    }
}
