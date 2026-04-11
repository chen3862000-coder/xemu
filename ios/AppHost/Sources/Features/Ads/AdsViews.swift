import SwiftUI

struct SponsoredNativeCard: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let ad: NativeAdPayload
    let onAppearImpression: () -> Void
    let onTapCTA: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Text(ad.footnote)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.Text.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppColors.Surface.cardElevated, in: Capsule())

                Spacer()

                Text(ad.advertiser)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.Text.tertiary)
                    .lineLimit(1)
            }

            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.accentGradient)
                    .frame(width: 72, height: 72)
                    .overlay {
                        Image(systemName: ad.systemImageName)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    Text(ad.headline)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.Text.primary)
                        .lineLimit(2)

                    Text(ad.body)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.Text.secondary)
                        .lineLimit(3)
                }
            }

            HStack {
                Text(L10n.string("ads.card.helper", languageManager: languageManager))
                    .font(.caption)
                    .foregroundStyle(AppColors.Text.tertiary)
                Spacer()
                Button(ad.callToAction, action: onTapCTA)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.primary)
                    .controlSize(.small)
            }
        }
        .padding(18)
        .background(AppColors.Surface.cardPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(AppColors.Border.subtle, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: AppColors.Shadow.card, radius: 12, x: 0, y: 8)
        .onAppear(perform: onAppearImpression)
    }
}

struct RewardedUnlockSheet: View {
    @EnvironmentObject private var languageManager: LanguageManager
    let title: String
    let message: String
    let rewardLabel: String
    let onWatchAd: () -> Void
    let onGoPro: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(AppColors.Border.subtle)
                .frame(width: 44, height: 5)
                .padding(.top, 12)

            VStack(spacing: 10) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.body)
                    .foregroundStyle(AppColors.Text.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button(L10n.format("ads.reward.watch_button", rewardLabel, languageManager: languageManager), action: onWatchAd)
                    .buttonStyle(.borderedProminent)
                    .tint(AppColors.primary)
                Button(L10n.string("ads.cta.go_pro", languageManager: languageManager), action: onGoPro)
                    .buttonStyle(.bordered)
            }

            Text(L10n.string("ads.reward.footer", languageManager: languageManager))
                .font(.caption)
                .foregroundStyle(AppColors.Text.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(AppColors.Background.appPrimary)
    }
}

struct PrivacyAndAdsSettingsView: View {
    @EnvironmentObject private var adsPolicyController: AdsPolicyController
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var selectedRewardPlacement: AdPlacement?

    var body: some View {
        List {
            Section(L10n.string("ads.plan.section", languageManager: languageManager)) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(
                            adsPolicyController.isProUser
                                ? L10n.string("ads.plan.pro.title", languageManager: languageManager)
                                : L10n.string("ads.plan.free.title", languageManager: languageManager)
                        )
                            .font(.headline)
                        Text(adsPolicyController.isProUser
                             ? L10n.string("ads.plan.pro.subtitle", languageManager: languageManager)
                             : L10n.string("ads.plan.free.subtitle", languageManager: languageManager))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(
                        adsPolicyController.isProUser
                            ? L10n.string("ads.plan.badge.pro", languageManager: languageManager)
                            : L10n.string("ads.plan.badge.free", languageManager: languageManager)
                    )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppColors.Surface.cardElevated, in: Capsule())
                }
                .padding(.vertical, 4)
            }

            if !adsPolicyController.isProUser {
                Section(L10n.string("ads.privacy.section", languageManager: languageManager)) {
                    SwiftUI.Toggle(
                        L10n.string("ads.personalized.toggle", languageManager: languageManager),
                        isOn: Binding(
                            get: { adsPolicyController.personalizedAdsEnabled },
                            set: { adsPolicyController.setPersonalizedAdsEnabled($0) }
                        )
                    )

                    Text(L10n.string("ads.personalized.helper", languageManager: languageManager))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(L10n.string("ads.guardrails", languageManager: languageManager))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section(L10n.string("ads.rewarded.section", languageManager: languageManager)) {
                    ForEach([AdPlacement.rewardedExtraSaveSlot, .rewardedShellTrial]) { placement in
                        if let state = adsPolicyController.offerState(for: placement) {
                            Button {
                                selectedRewardPlacement = placement
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(state.title)
                                            .font(.headline)
                                            .foregroundStyle(AppColors.Text.primary)
                                        Spacer()
                                        if let activeUntil = state.activeUntil, activeUntil > Date() {
                                            Text(L10n.string("ads.reward.active", languageManager: languageManager))
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(AppColors.success)
                                        }
                                    }
                                    Text(state.message)
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.Text.secondary)
                                    Text(state.rewardLabel)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(AppColors.Text.tertiary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle(L10n.string("ads.privacy.nav", languageManager: languageManager))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.insetGrouped)
#endif
        .sheet(item: $selectedRewardPlacement) { placement in
            if let state = adsPolicyController.offerState(for: placement) {
                RewardedUnlockSheet(
                    title: state.title,
                    message: state.message,
                    rewardLabel: state.rewardLabel,
                    onWatchAd: {
                        Task {
                            await adsPolicyController.redeemReward(for: placement)
                            selectedRewardPlacement = nil
                        }
                    },
                    onGoPro: {
                        selectedRewardPlacement = nil
                    }
                )
                .presentationDetents([.medium])
                .environmentObject(languageManager)
            }
        }
        .alert(
            L10n.string("ads.status.title", languageManager: languageManager),
            isPresented: Binding(
                get: { adsPolicyController.statusMessage != nil },
                set: { _ in adsPolicyController.dismissStatusMessage() }
            )
        ) {
            Button(L10n.string("common.ok", languageManager: languageManager), role: .cancel) {
                adsPolicyController.dismissStatusMessage()
            }
        } message: {
            Text(adsPolicyController.statusMessage ?? "")
        }
    }
}
