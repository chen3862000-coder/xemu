import Foundation

enum DeveloperAdProviderMode: String, CaseIterable, Identifiable {
    case mock
    case adMobTest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mock:
            return "Mock Ads"
        case .adMobTest:
            return "AdMob Test Ads"
        }
    }
}

enum AdPlacement: String, CaseIterable, Identifiable, Sendable {
    case homeFeedNative
    case libraryGridNative
    case rewardedExtraSaveSlot
    case rewardedShellTrial
    case pauseBanner

    var id: String { rawValue }

    var format: AdFormat {
        switch self {
        case .homeFeedNative, .libraryGridNative:
            return .native
        case .rewardedExtraSaveSlot, .rewardedShellTrial:
            return .rewarded
        case .pauseBanner:
            return .banner
        }
    }
}

enum AdFormat: String, Sendable {
    case native
    case banner
    case rewarded
}

enum AppSurface: String, Sendable {
    case home
    case library
    case pause
    case settings
    case gameplay
}

struct AdContext: Sendable {
    let placement: AdPlacement
    let surface: AppSurface
    let isPro: Bool
    let sessionSeconds: TimeInterval
    let timeSinceLastAd: TimeInterval
    let adsShownThisSession: Int
    let rewardedShownThisSession: Int
    let hasActiveGameplaySession: Bool
    let gameplayCooldownActive: Bool
    let pauseDuration: TimeInterval?
}

struct AdRules {
    static let minSecondsBeforeFirstAd: TimeInterval = 120
    static let minSecondsBetweenImpressions: TimeInterval = 90
    static let gameplayCooldownAfterExit: TimeInterval = 90
    static let maxImpressionsPerSession = 5
    static let maxRewardedPerSession = 4
    static let libraryInsertionInterval = 16
    static let minimumLibraryCountForAds = 20
}

enum AdMobTestConfig {
    static let appID = "ca-app-pub-3940256099942544~1458002511"
    static let nativeAdUnitID = "ca-app-pub-3940256099942544/3986624511"
    static let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
}

struct NativeAdPayload: Equatable, Sendable {
    let placement: AdPlacement
    let headline: String
    let body: String
    let advertiser: String
    let callToAction: String
    let systemImageName: String
    let footnote: String
}

struct RewardedAdPayload: Equatable, Sendable {
    let placement: AdPlacement
    let title: String
    let message: String
    let rewardLabel: String
    let duration: TimeInterval
}

struct RewardedOfferState: Equatable, Sendable {
    let placement: AdPlacement
    let title: String
    let message: String
    let rewardLabel: String
    let activeUntil: Date?
}

enum EntitlementDisplayStatus {
    case active
    case inactive
    case unknown
}
