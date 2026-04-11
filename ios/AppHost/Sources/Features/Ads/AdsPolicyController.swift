import Foundation
import SwiftUI

enum DeveloperMembershipOverride: String, CaseIterable, Identifiable {
    case system
    case free
    case pro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "Live"
        case .free:
            return "Force Free"
        case .pro:
            return "Force Pro"
        }
    }
}

@MainActor
protocol EntitlementService: AnyObject {
    func checkEntitlementStatus() async -> EntitlementDisplayStatus
}

@MainActor
final class CachedEntitlementService: EntitlementService {
    static let shared = CachedEntitlementService()

    private let entitlementCache: EntitlementCache
    private let userDefaults: UserDefaults

    init(entitlementCache: EntitlementCache = .shared, userDefaults: UserDefaults = .standard) {
        self.entitlementCache = entitlementCache
        self.userDefaults = userDefaults
    }

    func checkEntitlementStatus() async -> EntitlementDisplayStatus {
        let override = DeveloperMembershipOverride(
            rawValue: userDefaults.string(forKey: "settings.dev.membershipOverride") ?? ""
        ) ?? .system

        switch override {
        case .free:
            return .inactive
        case .pro:
            return .active
        case .system:
            break
        }

        if userDefaults.bool(forKey: "proUnlocked")
            || entitlementCache.hasActiveEntitlement(.removeAds)
            || entitlementCache.hasActiveEntitlement(.proBundle) {
            return .active
        }

        return .inactive
    }
}

@MainActor
final class MockEntitlementService: EntitlementService {
    private let statusProvider: () -> EntitlementDisplayStatus

    init(status: EntitlementDisplayStatus = .inactive) {
        self.statusProvider = { status }
    }

    init(statusProvider: @escaping () -> EntitlementDisplayStatus) {
        self.statusProvider = statusProvider
    }

    func checkEntitlementStatus() async -> EntitlementDisplayStatus {
        statusProvider()
    }
}

@MainActor
final class AdPreferences: ObservableObject {
    @MainActor static let shared = AdPreferences()

    @Published var homeFeedEnabled = true
    @Published var libraryFeedEnabled = true
    @Published var rewardedEnabled = true
    @Published var personalizedAdsEnabled = false
    @Published var extraSaveSlotRewardUntil: Date?
    @Published var shellTrialRewardUntil: Date?

    private let storageKey: String?

    init(storageKey: String? = "ads.preferences") {
        self.storageKey = storageKey
        load()
    }

    func save() {
        guard let storageKey else { return }
        let payload = AdPreferencesData(
            homeFeedEnabled: homeFeedEnabled,
            libraryFeedEnabled: libraryFeedEnabled,
            rewardedEnabled: rewardedEnabled,
            personalizedAdsEnabled: personalizedAdsEnabled,
            extraSaveSlotRewardUntil: extraSaveSlotRewardUntil,
            shellTrialRewardUntil: shellTrialRewardUntil
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func resetToDefaults() {
        homeFeedEnabled = true
        libraryFeedEnabled = true
        rewardedEnabled = true
        personalizedAdsEnabled = false
        extraSaveSlotRewardUntil = nil
        shellTrialRewardUntil = nil

        if let storageKey {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }

    private func load() {
        guard let storageKey,
              let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(AdPreferencesData.self, from: data) else {
            return
        }

        homeFeedEnabled = decoded.homeFeedEnabled
        libraryFeedEnabled = decoded.libraryFeedEnabled
        rewardedEnabled = decoded.rewardedEnabled
        personalizedAdsEnabled = decoded.personalizedAdsEnabled
        extraSaveSlotRewardUntil = decoded.extraSaveSlotRewardUntil
        shellTrialRewardUntil = decoded.shellTrialRewardUntil
    }
}

private struct AdPreferencesData: Codable {
    let homeFeedEnabled: Bool
    let libraryFeedEnabled: Bool
    let rewardedEnabled: Bool
    let personalizedAdsEnabled: Bool
    let extraSaveSlotRewardUntil: Date?
    let shellTrialRewardUntil: Date?
}

protocol AdPolicyEvaluating: Sendable {
    func canRequestAd(_ context: AdContext) -> Bool
    func canRenderAd(_ context: AdContext) -> Bool
}

struct AdPolicyEngine: AdPolicyEvaluating {
    func canRequestAd(_ context: AdContext) -> Bool {
        guard !context.isPro else { return false }
        guard context.sessionSeconds >= AdRules.minSecondsBeforeFirstAd else { return false }
        guard context.adsShownThisSession < AdRules.maxImpressionsPerSession else { return false }
        guard context.timeSinceLastAd >= AdRules.minSecondsBetweenImpressions else { return false }
        guard !context.hasActiveGameplaySession else { return false }
        guard !context.gameplayCooldownActive else { return false }
        return true
    }

    func canRenderAd(_ context: AdContext) -> Bool {
        switch context.placement {
        case .homeFeedNative, .libraryGridNative:
            return canRequestAd(context)
        case .pauseBanner:
            return canRequestAd(context) && context.surface == .pause && (context.pauseDuration ?? 0) >= 3
        case .rewardedExtraSaveSlot, .rewardedShellTrial:
            guard !context.isPro else { return false }
            guard context.rewardedShownThisSession < AdRules.maxRewardedPerSession else { return false }
            return true
        }
    }
}

@MainActor
final class AdsPolicyController: ObservableObject {
    @Published private(set) var nativeSlots: [AdPlacement: NativeAdPayload] = [:]
    @Published private(set) var rewardedStates: [AdPlacement: RewardedOfferState] = [:]
    @Published private(set) var entitlementStatus: EntitlementDisplayStatus = .unknown
    @Published private(set) var shouldSuggestProUpgrade = false
    @Published private(set) var statusMessage: String?

    private let repository: AdRepository
    private let entitlementService: EntitlementService
    private let preferences: AdPreferences
    private let policy: AdPolicyEvaluating
    private let now: () -> Date

    private var sessionStartedAt: Date
    private var lastAdImpressionAt: Date?
    private var adsShownThisSession = 0
    private var rewardedShownThisSession = 0
    private var hasActiveGameplaySession = false
    private var gameplayCooldownUntil: Date?
    private var pendingNativeLoadTasks: [AdPlacement: Task<Void, Never>] = [:]

    convenience init() {
        self.init(
            repository: MockAdRepository(),
            entitlementService: CachedEntitlementService.shared,
            preferences: .shared,
            policy: AdPolicyEngine(),
            now: Date.init
        )
    }

    init(
        repository: AdRepository,
        entitlementService: EntitlementService,
        preferences: AdPreferences,
        policy: AdPolicyEvaluating,
        now: @escaping () -> Date
    ) {
        self.repository = repository
        self.entitlementService = entitlementService
        self.preferences = preferences
        self.policy = policy
        self.now = now
        self.sessionStartedAt = now()
        refreshRewardedStates()
    }

    var isProUser: Bool {
        entitlementStatus == .active
    }

    var adProviderMode: DeveloperAdProviderMode {
        DeveloperAdProviderMode(
            rawValue: UserDefaults.standard.string(forKey: "settings.dev.adProviderMode") ?? ""
        ) ?? .mock
    }

    var personalizedAdsEnabled: Bool {
        preferences.personalizedAdsEnabled
    }

    func beginNewSession() {
        cancelPendingNativeLoadTasks()
        sessionStartedAt = now()
        lastAdImpressionAt = nil
        adsShownThisSession = 0
        rewardedShownThisSession = 0
        shouldSuggestProUpgrade = false
        statusMessage = nil
    }

    func reloadEntitlementStatus() async {
        entitlementStatus = await entitlementService.checkEntitlementStatus()
    }

    func refreshEntitlementStatus() {
        Task {
            await reloadEntitlementStatus()
        }
    }

    func setPersonalizedAdsEnabled(_ enabled: Bool) {
        preferences.personalizedAdsEnabled = enabled
        preferences.save()
    }

    func noteGameplayStarted() {
        hasActiveGameplaySession = true
    }

    func noteGameplayEnded() {
        hasActiveGameplaySession = false
        gameplayCooldownUntil = now().addingTimeInterval(AdRules.gameplayCooldownAfterExit)
    }

    func shouldShowAd(for placement: AdPlacement, on surface: AppSurface) -> Bool {
        let context = makeContext(placement: placement, surface: surface)

        switch placement {
        case .homeFeedNative:
            return preferences.homeFeedEnabled && policy.canRenderAd(context)
        case .libraryGridNative:
            return preferences.libraryFeedEnabled && policy.canRenderAd(context)
        case .rewardedExtraSaveSlot, .rewardedShellTrial:
            return preferences.rewardedEnabled && policy.canRenderAd(context)
        case .pauseBanner:
            return false
        }
    }

    func prepareNativeAd(for placement: AdPlacement, on surface: AppSurface) async {
        guard nativeSlots[placement] == nil else { return }
        guard !isProUser else { return }

        if pendingNativeLoadTasks[placement] != nil {
            return
        }

        guard shouldShowAd(for: placement, on: surface) else {
            scheduleDeferredNativeLoad(for: placement, on: surface)
            return
        }

        do {
            nativeSlots[placement] = try await repository.loadNativeAd(for: placement)
        } catch {
            statusMessage = L10n.string("ads.status.content_unavailable")
        }
    }

    func markImpression(for placement: AdPlacement) {
        guard placement.format != .rewarded else { return }
        lastAdImpressionAt = now()
        adsShownThisSession += 1

        if adsShownThisSession >= 3 {
            shouldSuggestProUpgrade = true
        }
    }

    func markClick(for placement: AdPlacement) {
        if placement == .homeFeedNative || placement == .libraryGridNative {
            statusMessage = L10n.string("ads.status.opening_sponsored")
        }
    }

    func shouldInsertLibraryAd(afterContentIndex index: Int, totalCount: Int, hasScrolledPastFirstViewport: Bool) -> Bool {
        guard hasScrolledPastFirstViewport else { return false }
        guard totalCount >= AdRules.minimumLibraryCountForAds else { return false }
        guard index % AdRules.libraryInsertionInterval == 0 else { return false }
        return shouldShowAd(for: .libraryGridNative, on: .library)
    }

    func offerState(for placement: AdPlacement) -> RewardedOfferState? {
        rewardedStates[placement]
    }

    func redeemReward(for placement: AdPlacement) async {
        guard shouldShowAd(for: placement, on: .settings) else { return }

        do {
            let reward = try await repository.loadRewardedAd(for: placement)
            rewardedShownThisSession += 1
            let expiry = now().addingTimeInterval(reward.duration)

            switch placement {
            case .rewardedExtraSaveSlot:
                preferences.extraSaveSlotRewardUntil = expiry
            case .rewardedShellTrial:
                preferences.shellTrialRewardUntil = expiry
            default:
                break
            }

            preferences.save()
            refreshRewardedStates()
            shouldSuggestProUpgrade = true
            statusMessage = L10n.format("ads.status.reward_unlocked", reward.rewardLabel)
        } catch {
            statusMessage = L10n.string("ads.status.reward_unavailable")
        }
    }

    func dismissStatusMessage() {
        statusMessage = nil
    }

    private func refreshRewardedStates() {
        rewardedStates = [
            .rewardedExtraSaveSlot: RewardedOfferState(
                placement: .rewardedExtraSaveSlot,
                title: L10n.string("ads.offer.extra_save_slot.title"),
                message: L10n.string("ads.offer.extra_save_slot.message"),
                rewardLabel: L10n.string("ads.offer.extra_save_slot.label"),
                activeUntil: preferences.extraSaveSlotRewardUntil
            ),
            .rewardedShellTrial: RewardedOfferState(
                placement: .rewardedShellTrial,
                title: L10n.string("ads.offer.shell_trial.title"),
                message: L10n.string("ads.offer.shell_trial.message"),
                rewardLabel: L10n.string("ads.offer.shell_trial.label"),
                activeUntil: preferences.shellTrialRewardUntil
            )
        ]
    }

    private func makeContext(placement: AdPlacement, surface: AppSurface) -> AdContext {
        let currentDate = now()
        let sessionSeconds = currentDate.timeIntervalSince(sessionStartedAt)
        let timeSinceLastAd = currentDate.timeIntervalSince(lastAdImpressionAt ?? .distantPast)
        let gameplayCooldownActive = gameplayCooldownUntil.map { currentDate < $0 } ?? false

        return AdContext(
            placement: placement,
            surface: surface,
            isPro: isProUser,
            sessionSeconds: sessionSeconds,
            timeSinceLastAd: timeSinceLastAd,
            adsShownThisSession: adsShownThisSession,
            rewardedShownThisSession: rewardedShownThisSession,
            hasActiveGameplaySession: hasActiveGameplaySession,
            gameplayCooldownActive: gameplayCooldownActive,
            pauseDuration: nil
        )
    }

    private func scheduleDeferredNativeLoad(for placement: AdPlacement, on surface: AppSurface) {
        guard pendingNativeLoadTasks[placement] == nil else { return }

        let retryDelay = max(secondsUntilAmbientAdEligibility(on: surface), 1)
        pendingNativeLoadTasks[placement] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.pendingNativeLoadTasks[placement] = nil
            await self.prepareNativeAd(for: placement, on: surface)
        }
    }

    private func secondsUntilAmbientAdEligibility(on surface: AppSurface) -> TimeInterval {
        let currentDate = now()
        var delays: [TimeInterval] = []

        let sessionElapsed = currentDate.timeIntervalSince(sessionStartedAt)
        delays.append(max(AdRules.minSecondsBeforeFirstAd - sessionElapsed, 0))

        if let lastAdImpressionAt {
            let sinceLastImpression = currentDate.timeIntervalSince(lastAdImpressionAt)
            delays.append(max(AdRules.minSecondsBetweenImpressions - sinceLastImpression, 0))
        }

        if let gameplayCooldownUntil {
            delays.append(max(gameplayCooldownUntil.timeIntervalSince(currentDate), 0))
        }

        if hasActiveGameplaySession || surface == .gameplay {
            delays.append(AdRules.gameplayCooldownAfterExit)
        }

        return delays.max() ?? 0
    }

    private func cancelPendingNativeLoadTasks() {
        for task in pendingNativeLoadTasks.values {
            task.cancel()
        }
        pendingNativeLoadTasks.removeAll()
    }
}
