import XCTest
@testable import Xemu

final class MemoryGameAnalyzerTests: XCTestCase {
    func testSMA2PowerDownEmitsDamageFromLiveMemory() {
        let analyzer = MemoryGameAnalyzer()

        let baseline = MarioLiveMemorySample(lives: 5, powerUpState: 3, gameplayState: 0, invulnerabilityTimer: 0)
        let damaged = MarioLiveMemorySample(lives: 5, powerUpState: 1, gameplayState: 1, invulnerabilityTimer: 44)

        let first = analyzer.analyzeLiveMemory(baseline, profile: .sma2SuperMarioWorld)
        let second = analyzer.analyzeLiveMemory(damaged, profile: .sma2SuperMarioWorld)

        XCTAssertTrue(first?.events.isEmpty ?? false)
        XCTAssertEqual(second?.events, [.damageLight])
        XCTAssertEqual(second?.playerState, .superState)
        XCTAssertEqual(second?.gameplayPhase, .gameplayActive)
    }

    func testSMA2DeathStateEmitsDeathFromLiveMemory() {
        let analyzer = MemoryGameAnalyzer()

        let baseline = MarioLiveMemorySample(lives: 4, powerUpState: 0, gameplayState: 0, invulnerabilityTimer: 0)
        let dead = MarioLiveMemorySample(lives: 4, powerUpState: 0, gameplayState: 0x09, invulnerabilityTimer: 0)

        _ = analyzer.analyzeLiveMemory(baseline, profile: .sma2SuperMarioWorld)
        let result = analyzer.analyzeLiveMemory(dead, profile: .sma2SuperMarioWorld)

        XCTAssertEqual(result?.events, [.deathDetected])
        XCTAssertEqual(result?.playerState, .dead)
        XCTAssertEqual(result?.gameplayPhase, .deathSequence)
    }

    func testSMBDPowerDownEmitsDamageFromLiveMemory() {
        let analyzer = MemoryGameAnalyzer()

        let baseline = MarioLiveMemorySample(lives: 5, powerUpState: 1, gameplayState: 0, invulnerabilityTimer: 0)
        let damaged = MarioLiveMemorySample(lives: 5, powerUpState: 0, gameplayState: 0x06, invulnerabilityTimer: 32)

        _ = analyzer.analyzeLiveMemory(baseline, profile: .superMarioBrosDeluxe)
        let result = analyzer.analyzeLiveMemory(damaged, profile: .superMarioBrosDeluxe)

        XCTAssertEqual(result?.events, [.damageLight])
        XCTAssertEqual(result?.playerState, .invulnerableBlink)
        XCTAssertEqual(result?.gameplayPhase, .gameplayActive)
    }

    func testSMBDDeathStateEmitsDeathFromLiveMemory() {
        let analyzer = MemoryGameAnalyzer()

        let baseline = MarioLiveMemorySample(lives: 3, powerUpState: 0, gameplayState: 0, invulnerabilityTimer: 0)
        let dead = MarioLiveMemorySample(lives: 3, powerUpState: 0, gameplayState: 0x03, invulnerabilityTimer: 0)

        _ = analyzer.analyzeLiveMemory(baseline, profile: .superMarioBrosDeluxe)
        let result = analyzer.analyzeLiveMemory(dead, profile: .superMarioBrosDeluxe)

        XCTAssertEqual(result?.events, [.deathDetected])
        XCTAssertEqual(result?.playerState, .dead)
        XCTAssertEqual(result?.gameplayPhase, .deathSequence)
    }

    func testSMA4PowerDownEmitsDamageFromLiveMemory() {
        let analyzer = MemoryGameAnalyzer()

        let baseline = MarioLiveMemorySample(lives: 5, powerUpState: 5, gameplayState: 0, invulnerabilityTimer: 0)
        let damaged = MarioLiveMemorySample(lives: 5, powerUpState: 1, gameplayState: 3, invulnerabilityTimer: 18)

        _ = analyzer.analyzeLiveMemory(baseline, profile: .sma4SuperMarioBros3)
        let result = analyzer.analyzeLiveMemory(damaged, profile: .sma4SuperMarioBros3)

        XCTAssertEqual(result?.events, [.damageLight])
        XCTAssertEqual(result?.playerState, .superState)
        XCTAssertEqual(result?.gameplayPhase, .gameplayActive)
    }

    func testSMA4LivesDecreaseEmitsDeathFromLiveMemory() {
        let analyzer = MemoryGameAnalyzer()

        let baseline = MarioLiveMemorySample(lives: 5, powerUpState: 0, gameplayState: 0, invulnerabilityTimer: 0)
        let dead = MarioLiveMemorySample(lives: 4, powerUpState: 0, gameplayState: 0, invulnerabilityTimer: 0)

        _ = analyzer.analyzeLiveMemory(baseline, profile: .sma4SuperMarioBros3)
        let result = analyzer.analyzeLiveMemory(dead, profile: .sma4SuperMarioBros3)

        XCTAssertEqual(result?.events, [.deathDetected])
        XCTAssertEqual(result?.playerState, .dead)
        XCTAssertEqual(result?.gameplayPhase, .deathSequence)
    }

    func testSMA4HighPowerValueClassifiesAsPoweredUp() {
        let analyzer = MemoryGameAnalyzer()

        let sample = MarioLiveMemorySample(lives: 3, powerUpState: 8, gameplayState: 0, invulnerabilityTimer: 62)
        let result = analyzer.analyzeLiveMemory(sample, profile: .sma4SuperMarioBros3)

        XCTAssertEqual(result?.playerState, .poweredUp)
        XCTAssertEqual(result?.gameplayPhase, .gameplayActive)
    }

    func testSMA4DelayedInvulnerabilityWindowStillEmitsDamage() {
        let analyzer = MemoryGameAnalyzer()

        let stable = MarioLiveMemorySample(lives: 2, powerUpState: 0, gameplayState: 0, invulnerabilityTimer: 0)
        let firstBlink = MarioLiveMemorySample(lives: 2, powerUpState: 0, gameplayState: 0, invulnerabilityTimer: 62)
        let secondBlink = MarioLiveMemorySample(lives: 2, powerUpState: 0, gameplayState: 0, invulnerabilityTimer: 61)

        _ = analyzer.analyzeLiveMemory(stable, profile: .sma4SuperMarioBros3)
        let firstResult = analyzer.analyzeLiveMemory(firstBlink, profile: .sma4SuperMarioBros3)
        let secondResult = analyzer.analyzeLiveMemory(secondBlink, profile: .sma4SuperMarioBros3)

        XCTAssertEqual(firstResult?.events, [.damageLight])
        XCTAssertTrue(secondResult?.events.isEmpty ?? false)
        XCTAssertEqual(firstResult?.playerState, .invulnerableBlink)
    }

    func testSMA4PoweredUpInvulnerabilityWindowStillEmitsDamage() {
        let analyzer = MemoryGameAnalyzer()

        let stable = MarioLiveMemorySample(lives: 2, powerUpState: 8, gameplayState: 0, invulnerabilityTimer: 0)
        let firstBlink = MarioLiveMemorySample(lives: 2, powerUpState: 8, gameplayState: 0, invulnerabilityTimer: 62)
        let secondBlink = MarioLiveMemorySample(lives: 2, powerUpState: 8, gameplayState: 0, invulnerabilityTimer: 61)

        _ = analyzer.analyzeLiveMemory(stable, profile: .sma4SuperMarioBros3)
        let firstResult = analyzer.analyzeLiveMemory(firstBlink, profile: .sma4SuperMarioBros3)
        let secondResult = analyzer.analyzeLiveMemory(secondBlink, profile: .sma4SuperMarioBros3)

        XCTAssertEqual(firstResult?.events, [.damageLight])
        XCTAssertTrue(secondResult?.events.isEmpty ?? false)
        XCTAssertEqual(firstResult?.playerState, .poweredUp)
    }

    func testSMA4RespawnInvulnerabilityDoesNotEmitFalseDamageOrPowerUpUntilRearmed() {
        let analyzer = MemoryGameAnalyzer()

        let dead = MarioLiveMemorySample(lives: 1, powerUpState: 0, gameplayState: 0, invulnerabilityTimer: 0)
        let death = MarioLiveMemorySample(lives: 0, powerUpState: 0, gameplayState: 0, invulnerabilityTimer: 0)
        let respawnBlink = MarioLiveMemorySample(lives: 0, powerUpState: 0, gameplayState: 0, invulnerabilityTimer: 62)
        let respawnPower = MarioLiveMemorySample(lives: 0, powerUpState: 8, gameplayState: 0, invulnerabilityTimer: 62)
        let calmGameplay = MarioLiveMemorySample(lives: 1, powerUpState: 0, gameplayState: 0, invulnerabilityTimer: 0)
        let laterPowerUp = MarioLiveMemorySample(lives: 1, powerUpState: 8, gameplayState: 0, invulnerabilityTimer: 0)

        _ = analyzer.analyzeLiveMemory(dead, profile: .sma4SuperMarioBros3)
        let deathResult = analyzer.analyzeLiveMemory(death, profile: .sma4SuperMarioBros3)
        let respawnBlinkResult = analyzer.analyzeLiveMemory(respawnBlink, profile: .sma4SuperMarioBros3)
        let respawnPowerResult = analyzer.analyzeLiveMemory(respawnPower, profile: .sma4SuperMarioBros3)
        _ = analyzer.analyzeLiveMemory(calmGameplay, profile: .sma4SuperMarioBros3)
        let laterPowerResult = analyzer.analyzeLiveMemory(laterPowerUp, profile: .sma4SuperMarioBros3)

        XCTAssertEqual(deathResult?.events, [.deathDetected])
        XCTAssertTrue(respawnBlinkResult?.events.isEmpty ?? false)
        XCTAssertTrue(respawnPowerResult?.events.isEmpty ?? false)
        XCTAssertEqual(laterPowerResult?.events, [.powerUpCollected])
    }
}
