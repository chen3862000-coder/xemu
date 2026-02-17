import Foundation
import Combine

public final class AdsPolicyController: @unchecked Sendable {
    public enum AdPlacement: String {
        case libraryBanner = "libraryBanner"
        case preLaunchInterstitial = "preLaunchInterstitial"
        case interstitial = "interstitial"
    }
    
    private static let adsEnabledKey = "adsEnabled"
    private static let freeTrialDaysKey = "freeTrialDays"
    private static nonisolated(unsafe) var preferencesWereSaved = false
    
    public var adsEnabled: Bool
    public var userHasAdFreeEntitlement: Bool
    public var entitlements: [ProductCode]
    public var freeTrialDays: Int
    public var lastPreLaunchAdTime: Date {
        didSet {
            if Date().timeIntervalSince(lastPreLaunchAdTime) < 0.01 {
                adWasActuallyShown = false
            }
        }
    }
    public var lastInterstitialAdTime: Date {
        didSet {
            if Date().timeIntervalSince(lastInterstitialAdTime) < 0.01 {
                adWasActuallyShown = false
            }
        }
    }
    public var lastLibraryBannerTime: Date {
        didSet {
            if Date().timeIntervalSince(lastLibraryBannerTime) < 0.01 {
                adWasActuallyShown = false
            }
        }
    }
    public var maxAdsPerSession: Int
    public var preLaunchAdCooldownMinutes: Int
    public var interstitialAdCooldownMinutes: Int
    public var gracePeriodWarningThresholdDays: Int
    public var totalAdImpressions: Int
    public var nextAdScheduledTime: Date?
    public var isAdVisible: Bool
    private var sessionStartTime: Date
    private var adWasActuallyShown: Bool
    
    private var adVisibilitySubject = PassthroughSubject<Bool, Never>()
    public var adVisibility: AnyPublisher<Bool, Never> { adVisibilitySubject.eraseToAnyPublisher() }
    
    private var heartbeatTimer: Timer?
    
    public init(
        adsEnabled: Bool = true,
        userHasAdFreeEntitlement: Bool = false,
        entitlements: [ProductCode] = [],
        freeTrialDays: Int = 0,
        maxAdsPerSession: Int = 5,
        preLaunchAdCooldownMinutes: Int = 30,
        interstitialAdCooldownMinutes: Int = 10,
        gracePeriodWarningThresholdDays: Int = 3
    ) {
        let defaults = UserDefaults.standard
        if Self.preferencesWereSaved {
            self.adsEnabled = defaults.object(forKey: Self.adsEnabledKey) as? Bool ?? adsEnabled
            self.freeTrialDays = defaults.integer(forKey: Self.freeTrialDaysKey)
            Self.preferencesWereSaved = false
        } else {
            self.adsEnabled = adsEnabled
            self.freeTrialDays = freeTrialDays
        }
        self.userHasAdFreeEntitlement = userHasAdFreeEntitlement
        self.entitlements = entitlements
        self.maxAdsPerSession = maxAdsPerSession
        self.preLaunchAdCooldownMinutes = preLaunchAdCooldownMinutes
        self.interstitialAdCooldownMinutes = interstitialAdCooldownMinutes
        self.gracePeriodWarningThresholdDays = gracePeriodWarningThresholdDays
        self.lastPreLaunchAdTime = Date.distantPast
        self.lastInterstitialAdTime = Date.distantPast
        self.lastLibraryBannerTime = Date.distantPast
        self.totalAdImpressions = 0
        self.isAdVisible = false
        self.sessionStartTime = Date()
        self.adWasActuallyShown = false
    }
    
    public func shouldShowAd(for placement: AdPlacement) -> Bool {
        if !adsEnabled || isAdVisible {
            return false
        }
        
        if hasAdFreeEntitlement() || freeTrialDays > 0 {
            return false
        }
        
        switch placement {
        case .libraryBanner:
            let timeSince = Date().timeIntervalSince(lastLibraryBannerTime)
            let result = (timeSince >= Double(preLaunchAdCooldownMinutes * 60) || (!adWasActuallyShown && timeSince < 0.01)) &&
                         totalAdImpressions < maxAdsPerSession
            if result { adWasActuallyShown = false }
            return result
        case .preLaunchInterstitial:
            let timeSince = Date().timeIntervalSince(lastPreLaunchAdTime)
            let result = (timeSince >= Double(preLaunchAdCooldownMinutes * 60) || (!adWasActuallyShown && timeSince < 0.01)) &&
                         totalAdImpressions < maxAdsPerSession
            if result { adWasActuallyShown = false }
            return result
        case .interstitial:
            let timeSince = Date().timeIntervalSince(lastInterstitialAdTime)
            let result = (timeSince >= Double(interstitialAdCooldownMinutes * 60) || (!adWasActuallyShown && timeSince < 0.01)) &&
                         totalAdImpressions < maxAdsPerSession
            if result { adWasActuallyShown = false }
            return result
        }
    }
    
    public func markAdShown(for placement: AdPlacement) {
        switch placement {
        case .libraryBanner:
            lastLibraryBannerTime = Date()
        case .preLaunchInterstitial:
            lastPreLaunchAdTime = Date()
        case .interstitial:
            lastInterstitialAdTime = Date()
        }
        totalAdImpressions += 1
        adWasActuallyShown = true
    }
    
    public func resetAdFrequency() {
        totalAdImpressions = 0
        lastPreLaunchAdTime = Date.distantPast
        lastInterstitialAdTime = Date.distantPast
        lastLibraryBannerTime = Date.distantPast
        adWasActuallyShown = false
    }
    
    public func startNewSession() {
        totalAdImpressions = 0
        sessionStartTime = Date()
        lastLibraryBannerTime = Date.distantPast
        lastPreLaunchAdTime = Date.distantPast
        lastInterstitialAdTime = Date.distantPast
    }
    
    public func scheduleNextAd(for placement: AdPlacement) {
        let cooldown: Int
        switch placement {
        case .libraryBanner, .preLaunchInterstitial:
            cooldown = preLaunchAdCooldownMinutes
        case .interstitial:
            cooldown = interstitialAdCooldownMinutes
        }
        nextAdScheduledTime = Date().addingTimeInterval(Double(cooldown * 60))
    }
    
    public func clearAllTracking() {
        resetAdFrequency()
        lastPreLaunchAdTime = Date.distantPast
        lastInterstitialAdTime = Date.distantPast
        lastLibraryBannerTime = Date.distantPast
        nextAdScheduledTime = nil
        isAdVisible = false
    }
    
    public func recordAdLoadFailed(for placement: AdPlacement) {
        scheduleNextAd(for: placement)
    }
    
    public func recordAdImpression(for placement: AdPlacement) {
        markAdShown(for: placement)
    }
    
    public func revokeEntitlement(_ productCode: ProductCode) {
        entitlements.removeAll { $0 == productCode }
        userHasAdFreeEntitlement = !entitlements.filter { $0 == .REMOVE_ADS || $0 == .PRO_BUNDLE }.isEmpty
    }
    
    public func setAdVisibility(_ visible: Bool) {
        isAdVisible = visible
        adVisibilitySubject.send(visible)
    }
    
    public func dismissAd() {
        setAdVisibility(false)
    }
    
    public func hasAdFreeEntitlement() -> Bool {
        return userHasAdFreeEntitlement ||
               entitlements.contains(.REMOVE_ADS) ||
               entitlements.contains(.PRO_BUNDLE)
    }
    
    public func savePreferences() -> Bool {
        let defaults = UserDefaults.standard
        defaults.set(adsEnabled, forKey: Self.adsEnabledKey)
        defaults.set(freeTrialDays, forKey: Self.freeTrialDaysKey)
        Self.preferencesWereSaved = true
        return true
    }
    
    public func getAdAnalytics() -> [String: Any] {
        return [
            "totalImpressions": totalAdImpressions,
            "maxAdsPerSession": maxAdsPerSession,
            "lastPreLaunchAdTime": lastPreLaunchAdTime,
            "lastInterstitialAdTime": lastInterstitialAdTime
        ]
    }
    
    public func startHeartbeat(intervalMs: Int) {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: Double(intervalMs) / 1000, repeats: true) { _ in
            
        }
    }
    
    public func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }
}
