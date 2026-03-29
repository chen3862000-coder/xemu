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

    func testTargetFrameTimeUsesNormalSpeedByDefault() {
        XCTAssertEqual(GamePlayViewModel.targetFrameTime(forSpeed: 1), 1.0 / 60.0, accuracy: 0.000_001)
    }

    func testTargetFrameTimeAcceleratesWhenFastForwardIsEnabled() {
        XCTAssertEqual(GamePlayViewModel.targetFrameTime(forSpeed: 3), 1.0 / 180.0, accuracy: 0.000_001)
    }

    func testTargetFrameTimeClampsInvalidFastForwardValues() {
        XCTAssertEqual(GamePlayViewModel.targetFrameTime(forSpeed: 0), 1.0 / 60.0, accuracy: 0.000_001)
    }

    func testPlayInsightsPayloadNormalizesSMALivesForDisplay() {
        let sample = MarioLiveMemorySample(
            lives: 4,
            powerUpState: 0,
            gameplayState: 0,
            invulnerabilityTimer: 0,
            health: nil,
            maxHealth: nil,
            gameMode: nil,
            contextValues: [
                "map": 0x01,
                "level": 0x15
            ]
        )

        let payload = GamePlayViewModel.playInsightsPayload(for: .superMarioAdvance2, liveSample: sample)

        XCTAssertEqual(payload["lives"], 5)
        XCTAssertEqual(payload["map"], 0x01)
        XCTAssertEqual(payload["level"], 0x15)
    }

    func testPlayInsightsPayloadNormalizesMetroidEnergyOffsetForDisplay() {
        let sample = MarioLiveMemorySample(
            lives: nil,
            powerUpState: 0,
            gameplayState: 0,
            invulnerabilityTimer: 0,
            health: 134,
            maxHealth: 199,
            gameMode: 0x01,
            contextValues: [
                "area": 0x02,
                "room": 0x0F
            ]
        )

        let payload = GamePlayViewModel.playInsightsPayload(for: .metroidFusion, liveSample: sample)

        XCTAssertEqual(payload["health"], 34)
        XCTAssertEqual(payload["maxHealth"], 99)
        XCTAssertEqual(payload["area"], 0x02)
        XCTAssertEqual(payload["room"], 0x0F)
    }

    func testPlayInsightsPayloadIncludesDragonBallVitalsAndState() {
        let sample = MarioLiveMemorySample(
            lives: 3,
            powerUpState: 0,
            gameplayState: 0x02,
            invulnerabilityTimer: 0,
            health: 164,
            maxHealth: 255,
            gameMode: nil,
            contextValues: ["stage": 0x4F2C]
        )

        let payload = GamePlayViewModel.playInsightsPayload(for: .dragonBallAdvancedAdventure, liveSample: sample)

        XCTAssertEqual(payload["lives"], 3)
        XCTAssertEqual(payload["health"], 164)
        XCTAssertEqual(payload["maxHealth"], 255)
        XCTAssertEqual(payload["state"], 0x02)
        XCTAssertEqual(payload["stage"], 0x4F2C)
    }

    func testPlayInsightsPayloadIncludesMetroidZeroMissionVitalsAndLocation() {
        let sample = MarioLiveMemorySample(
            lives: nil,
            powerUpState: 0x02,
            gameplayState: 0x10,
            invulnerabilityTimer: 0,
            health: 34,
            maxHealth: 99,
            gameMode: nil,
            contextValues: [
                "area": 0x06,
                "room": 0x1C,
                "mapX": 18,
                "mapY": 7
            ]
        )

        let payload = GamePlayViewModel.playInsightsPayload(for: .metroidZeroMission, liveSample: sample)

        XCTAssertEqual(payload["health"], 34)
        XCTAssertEqual(payload["maxHealth"], 99)
        XCTAssertEqual(payload["area"], 0x06)
        XCTAssertEqual(payload["room"], 0x1C)
        XCTAssertEqual(payload["mapX"], 18)
        XCTAssertEqual(payload["mapY"], 7)
    }
}
