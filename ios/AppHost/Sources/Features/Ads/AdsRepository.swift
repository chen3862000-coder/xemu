import Foundation

protocol AdRepository: Sendable {
    func loadNativeAd(for placement: AdPlacement) async throws -> NativeAdPayload
    func loadRewardedAd(for placement: AdPlacement) async throws -> RewardedAdPayload
}

enum MockAdRepositoryError: Error {
    case unsupportedPlacement
}

struct MockAdRepository: AdRepository {
    func loadNativeAd(for placement: AdPlacement) async throws -> NativeAdPayload {
        switch placement {
        case .homeFeedNative:
            return NativeAdPayload(
                placement: placement,
                headline: L10n.string("ads.mock.home.headline"),
                body: L10n.string("ads.mock.home.body"),
                advertiser: L10n.string("ads.mock.home.advertiser"),
                callToAction: L10n.string("ads.cta.browse"),
                systemImageName: "shippingbox.fill",
                footnote: L10n.string("ads.sponsored")
            )
        case .libraryGridNative:
            return NativeAdPayload(
                placement: placement,
                headline: L10n.string("ads.mock.library.headline"),
                body: L10n.string("ads.mock.library.body"),
                advertiser: L10n.string("ads.mock.library.advertiser"),
                callToAction: L10n.string("ads.cta.learn_more"),
                systemImageName: "books.vertical.fill",
                footnote: L10n.string("ads.sponsored")
            )
        default:
            throw MockAdRepositoryError.unsupportedPlacement
        }
    }

    func loadRewardedAd(for placement: AdPlacement) async throws -> RewardedAdPayload {
        switch placement {
        case .rewardedExtraSaveSlot:
            return RewardedAdPayload(
                placement: placement,
                title: L10n.string("ads.reward.extra_save_slot.title"),
                message: L10n.string("ads.reward.extra_save_slot.message"),
                rewardLabel: L10n.string("ads.reward.extra_save_slot.label"),
                duration: 24 * 60 * 60
            )
        case .rewardedShellTrial:
            return RewardedAdPayload(
                placement: placement,
                title: L10n.string("ads.reward.shell_trial.title"),
                message: L10n.string("ads.reward.shell_trial.message"),
                rewardLabel: L10n.string("ads.reward.shell_trial.label"),
                duration: 6 * 60 * 60
            )
        default:
            throw MockAdRepositoryError.unsupportedPlacement
        }
    }
}
