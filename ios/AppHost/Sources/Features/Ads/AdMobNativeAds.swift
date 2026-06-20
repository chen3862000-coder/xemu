import SwiftUI

#if os(iOS) && canImport(GoogleMobileAds)
import GoogleMobileAds
import UIKit

enum AdMobBootstrap {
    private static var started = false

    @MainActor
    static func startIfAvailable() {
        guard !started else { return }
        started = true
        MobileAds.shared.start()
    }
}

struct AdMobNativeCardSlot: View {
    let adUnitID: String
    let onImpression: () -> Void
    let onClick: () -> Void

    @StateObject private var viewModel: AdMobNativeCardViewModel

    init(
        adUnitID: String,
        onImpression: @escaping () -> Void,
        onClick: @escaping () -> Void
    ) {
        self.adUnitID = adUnitID
        self.onImpression = onImpression
        self.onClick = onClick
        _viewModel = StateObject(wrappedValue: AdMobNativeCardViewModel(adUnitID: adUnitID))
    }

    var body: some View {
        Group {
            if let nativeAd = viewModel.nativeAd {
                AdMobNativeAdView(
                    nativeAd: nativeAd,
                    onImpression: onImpression,
                    onClick: onClick
                )
                .frame(minHeight: 180)
            } else if viewModel.loadFailed {
                SponsoredNativeUnavailableCard()
            } else {
                SponsoredNativeLoadingCard()
            }
        }
        .task {
            await MainActor.run {
                AdMobBootstrap.startIfAvailable()
                viewModel.loadIfNeeded()
            }
        }
    }
}

@MainActor
private final class AdMobNativeCardViewModel: ObservableObject {
    @Published var nativeAd: NativeAd?
    @Published var loadFailed = false

    private let adUnitID: String
    private var loader: AdLoader?
    private var delegateProxy: AdMobNativeLoaderDelegate?

    init(adUnitID: String) {
        self.adUnitID = adUnitID
    }

    func loadIfNeeded() {
        guard nativeAd == nil, loader == nil, !loadFailed else { return }

        let options = NativeAdViewAdOptions()
        let loader = AdLoader(
            adUnitID: adUnitID,
            rootViewController: AdMobRootViewControllerResolver.topViewController(),
            adTypes: [.native],
            options: [options]
        )

        let delegateProxy = AdMobNativeLoaderDelegate(
            onReceive: { [weak self] ad in
                self?.nativeAd = ad
                self?.loader = nil
                self?.delegateProxy = nil
            },
            onFailure: { [weak self] in
                self?.loadFailed = true
                self?.loader = nil
                self?.delegateProxy = nil
            }
        )

        self.loader = loader
        self.delegateProxy = delegateProxy
        loader.delegate = delegateProxy
        loader.load(Request())
    }
}

private final class AdMobNativeLoaderDelegate: NSObject, NativeAdLoaderDelegate, AdLoaderDelegate {
    private let onReceive: (NativeAd) -> Void
    private let onFailure: () -> Void

    init(
        onReceive: @escaping (NativeAd) -> Void,
        onFailure: @escaping () -> Void
    ) {
        self.onReceive = onReceive
        self.onFailure = onFailure
    }

    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        onReceive(nativeAd)
    }

    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: any Error) {
        onFailure()
    }
}

private struct AdMobNativeAdView: UIViewRepresentable {
    let nativeAd: NativeAd
    let onImpression: () -> Void
    let onClick: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onImpression: onImpression, onClick: onClick)
    }

    func makeUIView(context: Context) -> NativeAdView {
        let view = NativeAdCardUIKitView()
        view.nativeAd = nativeAd
        nativeAd.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: NativeAdView, context: Context) {
        guard let view = uiView as? NativeAdCardUIKitView else { return }
        view.nativeAd = nativeAd
        nativeAd.delegate = context.coordinator
    }

    final class Coordinator: NSObject, NativeAdDelegate {
        private let onImpression: () -> Void
        private let onClick: () -> Void

        init(onImpression: @escaping () -> Void, onClick: @escaping () -> Void) {
            self.onImpression = onImpression
            self.onClick = onClick
        }

        nonisolated func nativeAdDidRecordImpression(_ nativeAd: NativeAd) {
            Task { @MainActor in
                onImpression()
            }
        }

        nonisolated func nativeAdDidRecordClick(_ nativeAd: NativeAd) {
            Task { @MainActor in
                onClick()
            }
        }
    }
}

private final class NativeAdCardUIKitView: NativeAdView {
    private let footnoteLabel = UILabel()
    private let advertiserLabel = UILabel()
    private let headlineLabel = UILabel()
    private let bodyLabel = UILabel()
    private let ctaButton = UIButton(type: .system)
    private let iconContainer = UIView()
    private let iconImageView = UIImageView()
    private let stack = UIStackView()
    private let headerStack = UIStackView()
    private let rowStack = UIStackView()
    private let textStack = UIStackView()
    private let footerStack = UIStackView()
    private let helperLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        layer.cornerRadius = 24
        layer.masksToBounds = true
        backgroundColor = UIColor(Color(AppColors.Surface.cardPrimary))
        layer.borderWidth = 1
        layer.borderColor = UIColor(Color(AppColors.Border.subtle)).cgColor

        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = 8

        footnoteLabel.font = .preferredFont(forTextStyle: .caption2)
        footnoteLabel.textColor = UIColor(Color(AppColors.Text.secondary))
        footnoteLabel.backgroundColor = UIColor(Color(AppColors.Surface.cardElevated))
        footnoteLabel.layer.cornerRadius = 10
        footnoteLabel.layer.masksToBounds = true
        footnoteLabel.textAlignment = .center

        advertiserLabel.font = .preferredFont(forTextStyle: .caption1)
        advertiserLabel.textColor = UIColor(Color(AppColors.Text.tertiary))
        advertiserLabel.textAlignment = .right

        rowStack.axis = .horizontal
        rowStack.alignment = .top
        rowStack.spacing = 14

        iconContainer.backgroundColor = UIColor(Color(AppColors.primary))
        iconContainer.layer.cornerRadius = 18
        iconContainer.layer.masksToBounds = true
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 72),
            iconContainer.heightAnchor.constraint(equalToConstant: 72)
        ])

        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconImageView)
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 44),
            iconImageView.heightAnchor.constraint(lessThanOrEqualToConstant: 44)
        ])

        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 6

        headlineLabel.font = .preferredFont(forTextStyle: .headline)
        headlineLabel.numberOfLines = 2
        headlineLabel.textColor = UIColor(Color(AppColors.Text.primary))

        bodyLabel.font = .preferredFont(forTextStyle: .subheadline)
        bodyLabel.numberOfLines = 3
        bodyLabel.textColor = UIColor(Color(AppColors.Text.secondary))

        helperLabel.font = .preferredFont(forTextStyle: .caption1)
        helperLabel.numberOfLines = 2
        helperLabel.textColor = UIColor(Color(AppColors.Text.tertiary))
        helperLabel.text = L10n.string("ads.admob.helper")

        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.cornerStyle = .capsule
        buttonConfig.baseBackgroundColor = UIColor(Color(AppColors.primary))
        buttonConfig.baseForegroundColor = .white
        buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        ctaButton.configuration = buttonConfig
        ctaButton.titleLabel?.font = .preferredFont(forTextStyle: .caption1)
        ctaButton.isUserInteractionEnabled = false

        footerStack.axis = .horizontal
        footerStack.alignment = .center
        footerStack.spacing = 12

        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        headerStack.addArrangedSubview(footnoteLabel)
        headerStack.addArrangedSubview(spacer)
        headerStack.addArrangedSubview(advertiserLabel)

        textStack.addArrangedSubview(headlineLabel)
        textStack.addArrangedSubview(bodyLabel)

        rowStack.addArrangedSubview(iconContainer)
        rowStack.addArrangedSubview(textStack)

        let footerSpacer = UIView()
        footerSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        footerStack.addArrangedSubview(helperLabel)
        footerStack.addArrangedSubview(footerSpacer)
        footerStack.addArrangedSubview(ctaButton)

        stack.addArrangedSubview(headerStack)
        stack.addArrangedSubview(rowStack)
        stack.addArrangedSubview(footerStack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18)
        ])

        headlineView = headlineLabel
        bodyView = bodyLabel
        callToActionView = ctaButton
        advertiserView = advertiserLabel
        iconView = iconImageView
    }

    override var nativeAd: NativeAd? {
        didSet {
            applyNativeAd()
        }
    }

    private func applyNativeAd() {
        guard let nativeAd else { return }

        headlineLabel.text = nativeAd.headline
        bodyLabel.text = nativeAd.body
        advertiserLabel.text = nativeAd.advertiser
        footnoteLabel.text = "  \(L10n.string("ads.sponsored"))  "

        if let iconImage = nativeAd.icon?.image {
            iconImageView.image = iconImage
            iconImageView.tintColor = nil
            iconContainer.backgroundColor = UIColor(Color(AppColors.Surface.cardElevated))
        } else {
            iconImageView.image = UIImage(systemName: "megaphone.fill")
            iconImageView.tintColor = .white
            iconContainer.backgroundColor = UIColor(Color(AppColors.primary))
        }

        ctaButton.configuration?.title = nativeAd.callToAction ?? L10n.string("ads.cta.learn_more")
        ctaButton.isHidden = nativeAd.callToAction == nil
        nativeAd.rootViewController = AdMobRootViewControllerResolver.topViewController()
    }
}

private enum AdMobRootViewControllerResolver {
    @MainActor
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let keyWindow = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)

        var controller = keyWindow?.rootViewController
        while let presented = controller?.presentedViewController {
            controller = presented
        }
        return controller
    }
}

@MainActor
final class AdMobRewardedPresentationBridge: NSObject {
    @MainActor static let shared = AdMobRewardedPresentationBridge()

    private var continuation: CheckedContinuation<RewardedAdPresentationResult, Never>?
    private var rewardedAd: RewardedAd?

    func present(adUnitID: String) async -> RewardedAdPresentationResult {
        guard continuation == nil else { return .cancelled }
        guard let rootViewController = AdMobRootViewControllerResolver.topViewController() else {
            return .unavailable
        }

        AdMobBootstrap.startIfAvailable()

        return await withCheckedContinuation { continuation in
            self.continuation = continuation

            RewardedAd.load(with: adUnitID, request: Request()) { [weak self] ad, error in
                guard let self else {
                    continuation.resume(returning: .unavailable)
                    return
                }

                guard error == nil, let ad else {
                    self.finishRewardPresentation(.unavailable)
                    return
                }

                self.rewardedAd = ad
                ad.fullScreenContentDelegate = self
                ad.present(from: rootViewController) { [weak self] in
                    self?.finishRewardPresentation(.completed)
                }
            }
        }
    }

    private func finishRewardPresentation(_ result: RewardedAdPresentationResult) {
        rewardedAd = nil
        continuation?.resume(returning: result)
        continuation = nil
    }
}

extension AdMobRewardedPresentationBridge: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        finishRewardPresentation(.cancelled)
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        finishRewardPresentation(.unavailable)
    }
}
#else
enum AdMobBootstrap {
    @MainActor
    static func startIfAvailable() {}
}

struct AdMobNativeCardSlot: View {
    let adUnitID: String
    let onImpression: () -> Void
    let onClick: () -> Void

    var body: some View {
        SponsoredNativeUnavailableCard()
    }
}

@MainActor
final class AdMobRewardedPresentationBridge {
    @MainActor static let shared = AdMobRewardedPresentationBridge()

    private init() {}

    func present(adUnitID: String) async -> RewardedAdPresentationResult {
        .unavailable
    }
}
#endif

struct SponsoredNativeLoadingCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(AppColors.Surface.cardSecondary)
            .frame(minHeight: 224)
            .overlay(
                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("ads.sponsored"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.Text.tertiary)
                    RoundedRectangle(cornerRadius: 14)
                        .fill(AppColors.Surface.cardElevated)
                        .frame(height: 90)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.Surface.cardElevated)
                        .frame(height: 14)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppColors.Surface.cardElevated)
                        .frame(width: 160, height: 14)
                }
                .padding(18)
            )
            .redacted(reason: .placeholder)
    }
}

struct SponsoredNativeUnavailableCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.string("ads.sponsored"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.Text.tertiary)

            Text(L10n.string("ads.admob.unavailable.title"))
                .font(.headline)
                .foregroundStyle(AppColors.Text.primary)

            Text(L10n.string("ads.admob.unavailable.message"))
                .font(.subheadline)
                .foregroundStyle(AppColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(AppColors.Surface.cardPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.Border.subtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
