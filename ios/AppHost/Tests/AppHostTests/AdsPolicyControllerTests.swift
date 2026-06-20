import XCTest
@testable import Xemu

@MainActor
final class AdsPolicyControllerTests: XCTestCase {
    private var preferences: AdPreferences!
    private var now = Date(timeIntervalSince1970: 1_000)

    override func setUp() {
        super.setUp()
        preferences = AdPreferences(storageKey: nil)
        preferences.resetToDefaults()
    }

    override func tearDown() {
        preferences = nil
        super.tearDown()
    }

    func testNativeAdsWaitUntilTwoMinutesIntoSession() async {
        let controller = makeController()
        await controller.reloadEntitlementStatus()

        XCTAssertFalse(controller.shouldShowAd(for: .homeFeedNative, on: .home))

        now.addTimeInterval(121)

        XCTAssertTrue(controller.shouldShowAd(for: .homeFeedNative, on: .home))
    }

    func testProUsersNeverSeeAds() async {
        let controller = makeController(entitlementService: MockEntitlementService(status: .active))
        await controller.reloadEntitlementStatus()
        now.addTimeInterval(121)

        XCTAssertFalse(controller.shouldShowAd(for: .homeFeedNative, on: .home))
        XCTAssertFalse(controller.shouldShowAd(for: .rewardedExtraSaveSlot, on: .settings))
    }

    func testLibraryAdInsertionRequiresScrollAndEnoughItems() async {
        let controller = makeController()
        await controller.reloadEntitlementStatus()
        now.addTimeInterval(121)

        XCTAssertFalse(controller.shouldInsertLibraryAd(afterContentIndex: 16, totalCount: 24, hasScrolledPastFirstViewport: false))
        XCTAssertFalse(controller.shouldInsertLibraryAd(afterContentIndex: 16, totalCount: 12, hasScrolledPastFirstViewport: true))
        XCTAssertTrue(controller.shouldInsertLibraryAd(afterContentIndex: 16, totalCount: 24, hasScrolledPastFirstViewport: true))
    }

    func testThirdImpressionTriggersProUpsell() async {
        let controller = makeController()
        await controller.reloadEntitlementStatus()
        now.addTimeInterval(121)

        controller.markImpression(for: .homeFeedNative)
        now.addTimeInterval(91)
        controller.markImpression(for: .libraryGridNative)
        now.addTimeInterval(91)
        controller.markImpression(for: .homeFeedNative)

        XCTAssertTrue(controller.shouldSuggestProUpgrade)
    }

    func testRewardedRedemptionStoresTemporaryUnlock() async {
        let controller = makeController()
        await controller.reloadEntitlementStatus()

        XCTAssertNil(controller.offerState(for: .rewardedExtraSaveSlot)?.activeUntil)

        await controller.redeemReward(for: .rewardedExtraSaveSlot)

        XCTAssertNotNil(controller.offerState(for: .rewardedExtraSaveSlot)?.activeUntil)
        XCTAssertTrue(controller.shouldSuggestProUpgrade)
    }

    func testGameplayCooldownBlocksAmbientAds() async {
        let controller = makeController()
        await controller.reloadEntitlementStatus()
        now.addTimeInterval(180)

        controller.noteGameplayStarted()
        controller.noteGameplayEnded()

        XCTAssertFalse(controller.shouldShowAd(for: .homeFeedNative, on: .home))

        now.addTimeInterval(AdRules.gameplayCooldownAfterExit + 1)

        XCTAssertTrue(controller.shouldShowAd(for: .homeFeedNative, on: .home))
    }

    func testDeveloperOverrideCanForceFreeOrPro() async {
        let defaults = UserDefaults(suiteName: "AdsPolicyControllerTests.\(#function)")!
        defaults.removePersistentDomain(forName: "AdsPolicyControllerTests.\(#function)")
        let entitlementCache = EntitlementCache()
        let service = CachedEntitlementService(entitlementCache: entitlementCache, userDefaults: defaults)

        defaults.set(DeveloperMembershipOverride.pro.rawValue, forKey: "settings.dev.membershipOverride")
        let forcedProStatus = await service.checkEntitlementStatus()
        XCTAssertEqual(forcedProStatus, .active)

        defaults.set(DeveloperMembershipOverride.free.rawValue, forKey: "settings.dev.membershipOverride")
        let forcedFreeStatus = await service.checkEntitlementStatus()
        XCTAssertEqual(forcedFreeStatus, .inactive)

        defaults.removeObject(forKey: "settings.dev.membershipOverride")
    }

    private func makeController(
        entitlementService: EntitlementService? = nil,
        rewardedPresenter: RewardedAdPresenting = MockRewardedAdPresenter(result: .completed)
    ) -> AdsPolicyController {
        AdsPolicyController(
            repository: MockAdRepository(),
            rewardedPresenter: rewardedPresenter,
            entitlementService: entitlementService ?? MockEntitlementService(status: .inactive),
            preferences: preferences,
            policy: AdPolicyEngine(),
            now: { self.now }
        )
    }
}
