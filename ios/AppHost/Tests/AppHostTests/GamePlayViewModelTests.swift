import XCTest
@testable import Xemu

@MainActor
final class GamePlayViewModelTests: XCTestCase {
    func testNDSFrameDimensionsMatchExpectedLayouts() {
        let stacked = GamePlayViewModel.ndsFrameDimensions(for: .stacked)
        XCTAssertEqual(stacked.width, 256)
        XCTAssertEqual(stacked.height, 384)

        let sideBySide = GamePlayViewModel.ndsFrameDimensions(for: .sideBySide)
        XCTAssertEqual(sideBySide.width, 512)
        XCTAssertEqual(sideBySide.height, 192)

        let topOnly = GamePlayViewModel.ndsFrameDimensions(for: .topOnly)
        XCTAssertEqual(topOnly.width, 256)
        XCTAssertEqual(topOnly.height, 192)
    }

    func testResolvedNDSDisplayLayoutUsesRenderedStackedFrames() {
        let resolved = GamePlayViewModel.resolvedNDSDisplayLayout(
            renderedWidth: 256,
            renderedHeight: 384,
            fallback: .sideBySide
        )

        XCTAssertEqual(resolved, .stacked)
    }

    func testResolvedNDSDisplayLayoutUsesRenderedSideBySideFrames() {
        let resolved = GamePlayViewModel.resolvedNDSDisplayLayout(
            renderedWidth: 512,
            renderedHeight: 192,
            fallback: .stacked
        )

        XCTAssertEqual(resolved, .sideBySide)
    }

    func testResolvedNDSDisplayLayoutFallsBackForSingleScreenFrames() {
        let resolved = GamePlayViewModel.resolvedNDSDisplayLayout(
            renderedWidth: 256,
            renderedHeight: 192,
            fallback: .bottomOnly
        )

        XCTAssertEqual(resolved, .bottomOnly)
    }

    func testEffectiveDisplayPlatformPreservesExplicitGBCLaunches() {
        let resolved = GamePlayViewModel.effectiveDisplayPlatform(
            requestedPlatform: .GBC,
            isCGBModeDetected: false
        )

        XCTAssertEqual(resolved, .GBC)
    }

    func testEffectiveDisplayPlatformUpgradesGBLaunchesWhenCGBModeIsDetected() {
        let resolved = GamePlayViewModel.effectiveDisplayPlatform(
            requestedPlatform: .GB,
            isCGBModeDetected: true
        )

        XCTAssertEqual(resolved, .GBC)
    }

    func testEffectiveDisplayPlatformKeepsPlainGBLaunchesAsGB() {
        let resolved = GamePlayViewModel.effectiveDisplayPlatform(
            requestedPlatform: .GB,
            isCGBModeDetected: false
        )

        XCTAssertEqual(resolved, .GB)
    }

    func testShouldEnablePostProcessingKeepsGBCCorrectionInReducedProfiles() {
        let enabled = GamePlayViewModel.shouldEnablePostProcessing(
            for: .fair,
            displayPlatform: .GBC
        )

        XCTAssertTrue(enabled)
    }

    func testShouldEnablePostProcessingRespectsProfileForNonGBCSystems() {
        let enabled = GamePlayViewModel.shouldEnablePostProcessing(
            for: .fair,
            displayPlatform: .GBA
        )

        XCTAssertFalse(enabled)
    }

    func testInitialAudioEngineRateKeepsBalancedNDSAtNativeHint() {
        let rate = GamePlayViewModel.initialAudioEngineRate(
            requestedPlatform: .NDS,
            isNDSCore: true,
            audioQuality: 1,
            nativeRateHint: 32_768
        )

        XCTAssertEqual(rate, 32_768)
    }

    func testInitialAudioEngineRateKeepsFrameFirstNDSAtNativeHint() {
        let rate = GamePlayViewModel.initialAudioEngineRate(
            requestedPlatform: .NDS,
            isNDSCore: true,
            audioQuality: 2,
            nativeRateHint: 32_768
        )

        XCTAssertEqual(rate, 32_768)
    }

    func testInitialAudioEngineRateUses48kForSoundFirstNDS() {
        let rate = GamePlayViewModel.initialAudioEngineRate(
            requestedPlatform: .NDS,
            isNDSCore: true,
            audioQuality: 0,
            nativeRateHint: 32_768
        )

        XCTAssertEqual(rate, 48_000)
    }

    func testResolvedAudioSampleRatePreservesNativeMelonDSNDSRate() {
        let rate = GamePlayViewModel.resolvedAudioSampleRate(32_728, platform: .NDS)

        XCTAssertEqual(rate, 32_728)
    }

    func testResolvedAudioSampleRateLeavesNonNDSRatesUntouched() {
        let rate = GamePlayViewModel.resolvedAudioSampleRate(44_100, platform: .GBA)

        XCTAssertEqual(rate, 44_100)
    }

    func testAudioLatencyProfileUsesLowLatencyForGB() {
        let profile = GamePlayViewModel.audioLatencyProfile(
            requestedPlatform: .GB,
            isNDSCore: false
        )

        XCTAssertEqual(profile, .lowLatency)
    }

    func testAudioLatencyProfileUsesStreamingForNDS() {
        let profile = GamePlayViewModel.audioLatencyProfile(
            requestedPlatform: .NDS,
            isNDSCore: true
        )

        XCTAssertEqual(profile, .streaming)
    }

    func testAudioLatencyProfileUsesBalancedForGBA() {
        let profile = GamePlayViewModel.audioLatencyProfile(
            requestedPlatform: .GBA,
            isNDSCore: false
        )

        XCTAssertEqual(profile, .balanced)
    }

    func testShouldAutoResumeLaunchStateAllowsNDS() {
        XCTAssertTrue(GamePlayViewModel.shouldAutoResumeLaunchState(for: .NDS))
    }

    func testShouldAutoResumeLaunchStateAllowsOtherPlatforms() {
        XCTAssertTrue(GamePlayViewModel.shouldAutoResumeLaunchState(for: .GBA))
    }
}
