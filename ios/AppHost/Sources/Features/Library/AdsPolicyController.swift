import Foundation
import UserNotifications
#if canImport(SwiftUI)
import SwiftUI
#endif

@MainActor final class AdsPolicyController: ObservableObject {
    enum AdPlacement {
        case libraryBanner
        case preLaunchInterstitial
        case interstitial
    }

    @Published var shouldShowLibraryBanner = false
    @Published var adFreeUntil: Date?
    @Published var entitlementStatus: EntitlementDisplayStatus = .unknown

    private let entitlementService: EntitlementService
    private let preferences: AdPreferences

    @MainActor init(entitlementService: EntitlementService? = nil, preferences: AdPreferences? = nil) {
        self.entitlementService = entitlementService ?? MockEntitlementService.shared
        self.preferences = preferences ?? AdPreferences.shared
        loadAdPreferences()
    }

    func shouldShowAd(for placement: AdPlacement) -> Bool {
        if hasAdFreeEntitlement() {
            return false
        }

        switch placement {
        case .libraryBanner:
            return preferences.libraryBannerEnabled && !isAdFreePeriod()
        case .preLaunchInterstitial:
            return preferences.preLaunchInterstitialEnabled && shouldShowPreLaunch()
        case .interstitial:
            return preferences.interstitialEnabled && shouldShowInterstitial()
        }
    }

    func markAdShown(for placement: AdPlacement) {
        switch placement {
        case .libraryBanner:
            preferences.lastBannerShown = Date()
        case .preLaunchInterstitial:
            preferences.lastPreLaunchShown = Date()
        case .interstitial:
            preferences.lastInterstitialShown = Date()
        }

        saveAdPreferences()
    }

    func recordAdLoadFailed(for placement: AdPlacement) {
        switch placement {
        case .libraryBanner:
            preferences.bannerFailureCount += 1
        case .preLaunchInterstitial:
            preferences.preLaunchFailureCount += 1
        case .interstitial:
            preferences.interstitialFailureCount += 1
        }

        saveAdPreferences()
    }

    func schedulePreLaunchAd(completion: @escaping (Bool) -> Void) {
        if shouldShowAd(for: .preLaunchInterstitial) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.showAd(.preLaunchInterstitial) {
                    completion($0)
                }
            }
        } else {
            completion(true)
        }
    }

    func requestAdPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Ad permission error: \(error)")
            }
            completion(granted)
        }
    }

    private func showAd(_ placement: AdPlacement, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.markAdShown(for: placement)
            completion(true)
        }
    }

    private func hasAdFreeEntitlement() -> Bool {
        switch entitlementStatus {
        case .active:
            return true
        case .inactive, .unknown:
            return false
        }
    }

    private func isAdFreePeriod() -> Bool {
        guard let adFreeUntil = adFreeUntil else { return false }
        return Date() < adFreeUntil
    }

    private func shouldShowPreLaunch() -> Bool {
        guard let lastShown = preferences.lastPreLaunchShown else { return true }

        let timeSinceLastAd = Date().timeIntervalSince(lastShown)
        let interval = TimeInterval(preferences.preLaunchAdIntervalMinutes * 60)

        return timeSinceLastAd >= interval
    }

    private func shouldShowInterstitial() -> Bool {
        guard let lastShown = preferences.lastInterstitialShown else { return false }

        let timeSinceLastAd = Date().timeIntervalSince(lastShown)
        let interval = TimeInterval(preferences.interstitialAdIntervalMinutes * 60)

        return timeSinceLastAd >= interval
    }

    private func loadAdPreferences() {
        if let data = UserDefaults.standard.data(forKey: "adPreferences"),
           let decoded = try? JSONDecoder().decode(AdPreferencesData.self, from: data) {
            preferences.updateFrom(decoded)
        }
    }

    private func saveAdPreferences() {
        let data = AdPreferencesData(from: preferences)
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: "adPreferences")
        }
    }

    func refreshEntitlementStatus() {
        Task {
            let status = await entitlementService.checkEntitlementStatus()
            await MainActor.run {
                self.entitlementStatus = status
            }
        }
    }
}

private struct AdPreferencesData: Codable {
    let libraryBannerEnabled: Bool
    let preLaunchInterstitialEnabled: Bool
    let interstitialEnabled: Bool
    let preLaunchAdIntervalMinutes: Int
    let interstitialAdIntervalMinutes: Int
    let lastBannerShown: Date?
    let lastPreLaunchShown: Date?
    let lastInterstitialShown: Date?
    var bannerFailureCount: Int
    var preLaunchFailureCount: Int
    var interstitialFailureCount: Int
    
    init(from preferences: AdPreferences) {
        self.libraryBannerEnabled = preferences.libraryBannerEnabled
        self.preLaunchInterstitialEnabled = preferences.preLaunchInterstitialEnabled
        self.interstitialEnabled = preferences.interstitialEnabled
        self.preLaunchAdIntervalMinutes = preferences.preLaunchAdIntervalMinutes
        self.interstitialAdIntervalMinutes = preferences.interstitialAdIntervalMinutes
        self.lastBannerShown = preferences.lastBannerShown
        self.lastPreLaunchShown = preferences.lastPreLaunchShown
        self.lastInterstitialShown = preferences.lastInterstitialShown
        self.bannerFailureCount = preferences.bannerFailureCount
        self.preLaunchFailureCount = preferences.preLaunchFailureCount
        self.interstitialFailureCount = preferences.interstitialFailureCount
    }
    
    func apply(to preferences: AdPreferences) {
        preferences.libraryBannerEnabled = libraryBannerEnabled
        preferences.preLaunchInterstitialEnabled = preLaunchInterstitialEnabled
        preferences.interstitialEnabled = interstitialEnabled
        preferences.preLaunchAdIntervalMinutes = preLaunchAdIntervalMinutes
        preferences.interstitialAdIntervalMinutes = interstitialAdIntervalMinutes
        preferences.lastBannerShown = lastBannerShown
        preferences.lastPreLaunchShown = lastPreLaunchShown
        preferences.lastInterstitialShown = lastInterstitialShown
        preferences.bannerFailureCount = bannerFailureCount
        preferences.preLaunchFailureCount = preLaunchFailureCount
        preferences.interstitialFailureCount = interstitialFailureCount
    }
}

final class AdPreferences: ObservableObject {
    @MainActor static let shared = AdPreferences()

    @Published var libraryBannerEnabled = true
    @Published var preLaunchInterstitialEnabled = true
    @Published var interstitialEnabled = true

    @Published var preLaunchAdIntervalMinutes: Int = 5
    @Published var interstitialAdIntervalMinutes: Int = 10

    @Published var lastBannerShown: Date?
    @Published var lastPreLaunchShown: Date?
    @Published var lastInterstitialShown: Date?

    @Published var bannerFailureCount = 0
    @Published var preLaunchFailureCount = 0
    @Published var interstitialFailureCount = 0

    private init() {}

    fileprivate func updateFrom(_ data: AdPreferencesData) {
        libraryBannerEnabled = data.libraryBannerEnabled
        preLaunchInterstitialEnabled = data.preLaunchInterstitialEnabled
        interstitialEnabled = data.interstitialEnabled
        preLaunchAdIntervalMinutes = data.preLaunchAdIntervalMinutes
        interstitialAdIntervalMinutes = data.interstitialAdIntervalMinutes
        lastBannerShown = data.lastBannerShown
        lastPreLaunchShown = data.lastPreLaunchShown
        lastInterstitialShown = data.lastInterstitialShown
        bannerFailureCount = data.bannerFailureCount
        preLaunchFailureCount = data.preLaunchFailureCount
        interstitialFailureCount = data.interstitialFailureCount
    }

    func resetToDefaults() {
        libraryBannerEnabled = true
        preLaunchInterstitialEnabled = true
        interstitialEnabled = true
        preLaunchAdIntervalMinutes = 5
        interstitialAdIntervalMinutes = 10
        lastBannerShown = nil
        lastPreLaunchShown = nil
        lastInterstitialShown = nil
        bannerFailureCount = 0
        preLaunchFailureCount = 0
        interstitialFailureCount = 0
        UserDefaults.standard.removeObject(forKey: "adPreferences")
    }
}

enum EntitlementDisplayStatus {
    case active
    case inactive
    case unknown
}

@MainActor protocol EntitlementService: AnyObject {
    static var shared: Self { get }
    func checkEntitlementStatus() async -> EntitlementDisplayStatus
}

@MainActor final class MockEntitlementService: EntitlementService {
    static let shared = MockEntitlementService()

    private init() {}

    func checkEntitlementStatus() async -> EntitlementDisplayStatus {
        return .inactive
    }
}
