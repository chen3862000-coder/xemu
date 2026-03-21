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
}
