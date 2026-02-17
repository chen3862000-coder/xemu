import Foundation
import UserNotifications

final class AdsPolicyController: ObservableObject {
    enum AdPlacement {
        case libraryBanner
        case preLaunchInterstitial
        case interstitial
    }

    @Published var shouldShowLibraryBanner = false
    @Published var adFreeUntil: Date?
    @Published var entitlementStatus: EntitlementStatus = .unknown

    private let entitlementService: EntitlementService
    private let preferences: AdPreferences

    init(entitlementService: EntitlementService = .shared, preferences: AdPreferences = .shared) {
        self.entitlementService = entitlementService
        self.preferences = preferences
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
        guard let lastShown = preferences.lastInterstitialShown else { return true }

        let timeSinceLastAd = Date().timeIntervalSince(lastShown)
        let interval = TimeInterval(preferences.interstitialAdIntervalMinutes * 60)

        return timeSinceLastAd >= interval
    }

    private func loadAdPreferences() {
        if let data = UserDefaults.standard.data(forKey: "adPreferences"),
           let decoded = try? JSONDecoder().decode(AdPreferences.self, from: data) {
            preferences.updateFrom(decoded)
        }
    }

    private func saveAdPreferences() {
        if let data = try? JSONEncoder().encode(preferences) {
            UserDefaults.standard.set(data, forKey: "adPreferences")
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

final class AdPreferences: Codable, ObservableObject {
    static let shared = AdPreferences()

    @Published var libraryBannerEnabled = true
    @Published var preLaunchInterstitialEnabled = true
    @Published var interstitialEnabled = true

    @Published var preLaunchAdIntervalMinutes: Int = 5
    @Published var interstitialAdIntervalMinutes: Int = 10

    @Published var lastBannerShown: Date?
    @Published var lastPreLaunchShown: Date?
    @Published var lastInterstitialShown: Date?

    private init() {}

    func updateFrom(_ other: AdPreferences) {
        libraryBannerEnabled = other.libraryBannerEnabled
        preLaunchInterstitialEnabled = other.preLaunchInterstitialEnabled
        interstitialEnabled = other.interstitialEnabled
        preLaunchAdIntervalMinutes = other.preLaunchAdIntervalMinutes
        interstitialAdIntervalMinutes = other.interstitialAdIntervalMinutes
        lastBannerShown = other.lastBannerShown
        lastPreLaunchShown = other.lastPreLaunchShown
        lastInterstitialShown = other.lastInterstitialShown
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
    }
}

enum EntitlementStatus {
    case active
    case inactive
    case unknown
}

protocol EntitlementService {
    func checkEntitlementStatus() async -> EntitlementStatus
}

final class MockEntitlementService: EntitlementService {
    static let shared = MockEntitlementService()

    private init() {}

    func checkEntitlementStatus() async -> EntitlementStatus {
        return .inactive
    }
}
