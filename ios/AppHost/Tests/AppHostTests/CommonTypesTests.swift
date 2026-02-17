import XCTest
@testable import AppHost

final class CommonTypesTests: XCTestCase {

    func testPlatformEnumCases() {
        XCTAssertEqual(Platform.NES.rawValue, "nes")
        XCTAssertEqual(Platform.GB.rawValue, "gb")
        XCTAssertEqual(Platform.GBA.rawValue, "gba")
        XCTAssertEqual(Platform.GENESIS.rawValue, "genesis")
        XCTAssertEqual(Platform.NDS.rawValue, "nds")
        XCTAssertEqual(Platform.PS1.rawValue, "ps1")
        XCTAssertEqual(Platform.PS2.rawValue, "ps2")
        XCTAssertEqual(Platform._3DS.rawValue, "3ds")
    }

    func testPlatformEnumDecoding() {
        XCTAssertEqual(Platform(rawValue: "nes"), .NES)
        XCTAssertEqual(Platform(rawValue: "gb"), .GB)
        XCTAssertEqual(Platform(rawValue: "gba"), .GBA)
        XCTAssertEqual(Platform(rawValue: "genesis"), .GENESIS)
        XCTAssertEqual(Platform(rawValue: "nds"), .NDS)
        XCTAssertEqual(Platform(rawValue: "ps1"), .PS1)
        XCTAssertEqual(Platform(rawValue: "ps2"), .PS2)
        XCTAssertEqual(Platform(rawValue: "3ds"), ._3DS)
        XCTAssertNil(Platform(rawValue: "UNKNOWN"))
    }

    func testTierEnumCases() {
        XCTAssertEqual(Tier.stable.rawValue, "stable")
        XCTAssertEqual(Tier.experimental.rawValue, "experimental")
        XCTAssertEqual(Tier.unknown.rawValue, "unknown")
    }

    func testCompletionStateEnumCases() {
        XCTAssertEqual(CompletionState.NotStarted.rawValue, "NotStarted")
        XCTAssertEqual(CompletionState.InProgress.rawValue, "InProgress")
        XCTAssertEqual(CompletionState.Completed.rawValue, "Completed")
        XCTAssertEqual(CompletionState.Mastered.rawValue, "Mastered")
    }

    func testSessionModeEnumCases() {
        XCTAssertEqual(SessionMode.SinglePlayer.rawValue, "SinglePlayer")
        XCTAssertEqual(SessionMode.Legit.rawValue, "Legit")
        XCTAssertEqual(SessionMode.MultiplayerHost.rawValue, "MultiplayerHost")
        XCTAssertEqual(SessionMode.MultiplayerGuest.rawValue, "MultiplayerGuest")
    }

    func testSessionVerdictEnumCases() {
        XCTAssertEqual(SessionVerdict.Pending.rawValue, "Pending")
        XCTAssertEqual(SessionVerdict.Valid.rawValue, "Valid")
        XCTAssertEqual(SessionVerdict.Invalid.rawValue, "Invalid")
        XCTAssertEqual(SessionVerdict.Flagged.rawValue, "Flagged")
    }

    func testEntitlementStatusEnumCases() {
        XCTAssertEqual(EntitlementStatus.Active.rawValue, "Active")
        XCTAssertEqual(EntitlementStatus.Revoked.rawValue, "Revoked")
        XCTAssertEqual(EntitlementStatus.Refunded.rawValue, "Refunded")
        XCTAssertEqual(EntitlementStatus.Expired.rawValue, "Expired")
    }

    func testProductCodeEnumCases() {
        XCTAssertEqual(ProductCode.REMOVE_ADS.rawValue, "REMOVE_ADS")
        XCTAssertEqual(ProductCode.EXPERIMENTAL_PACK.rawValue, "EXPERIMENTAL_PACK")
        XCTAssertEqual(ProductCode.PRO_BUNDLE.rawValue, "PRO_BUNDLE")
    }

    func testHardwareClassEnumCases() {
        XCTAssertEqual(HardwareClass.Tier1.rawValue, "Tier1")
        XCTAssertEqual(HardwareClass.Tier2.rawValue, "Tier2")
        XCTAssertEqual(HardwareClass.Tier3.rawValue, "Tier3")
        XCTAssertEqual(HardwareClass.Unsupported.rawValue, "Unsupported")
    }

    func testAchievementTriggerInitialization() {
        let trigger = AchievementTrigger(
            achievementId: UUID(),
            triggeredAt: Date(),
            metadata: ["key": "value"]
        )

        XCTAssertNotNil(trigger.achievementId)
        XCTAssertNotNil(trigger.triggeredAt)
        XCTAssertEqual(trigger.metadata["key"] as? String, "value")
    }

    func testAchievementTriggerCodable() {
        let originalTrigger = AchievementTrigger(
            achievementId: UUID(),
            triggeredAt: Date(),
            metadata: ["score": 100, "level": 5]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        guard let data = try? encoder.encode(originalTrigger),
              let decodedTrigger = try? JSONDecoder().decode(AchievementTrigger.self, from: data) else {
            XCTFail("Encoding/decoding failed")
            return
        }

        XCTAssertEqual(originalTrigger.achievementId, decodedTrigger.achievementId)
        XCTAssertEqual(originalTrigger.metadata["score"] as? Int, decodedTrigger.metadata["score"] as? Int)
    }

    func testDeviceBindingInitialization() {
        let binding = DeviceBinding(
            deviceName: "iPhone 15",
            deviceId: UUID(),
            boundAt: Date()
        )

        XCTAssertEqual(binding.deviceName, "iPhone 15")
        XCTAssertNotNil(binding.deviceId)
        XCTAssertNotNil(binding.boundAt)
    }

    func testDeviceBindingCodable() {
        let originalBinding = DeviceBinding(
            deviceName: "iPad Pro",
            deviceId: UUID(),
            boundAt: Date()
        )

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(originalBinding),
              let decodedBinding = try? JSONDecoder().decode(DeviceBinding.self, from: data) else {
            XCTFail("Encoding/decoding failed")
            return
        }

        XCTAssertEqual(originalBinding.deviceName, decodedBinding.deviceName)
        XCTAssertEqual(originalBinding.deviceId, decodedBinding.deviceId)
    }

    func testPlatformEquatable() {
        XCTAssertNotEqual(Platform.NES, Platform.GBA)
        XCTAssertEqual(Platform.NES, Platform.NES)
    }

    func testTierHashable() {
        let set: Set<Tier> = [.stable, .experimental, .unknown]
        XCTAssertEqual(set.count, 3)
    }

    func testCompletionStateRawValueRoundtrip() {
        for state in [CompletionState.NotStarted, .InProgress, .Completed, .Mastered] {
            XCTAssertEqual(CompletionState(rawValue: state.rawValue), state)
        }
    }

    func testSessionModeRawValueRoundtrip() {
        for mode in [SessionMode.SinglePlayer, .Legit, .MultiplayerHost, .MultiplayerGuest] {
            XCTAssertEqual(SessionMode(rawValue: mode.rawValue), mode)
        }
    }
}
