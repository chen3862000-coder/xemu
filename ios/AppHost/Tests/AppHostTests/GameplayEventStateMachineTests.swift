import XCTest
@testable import Xemu

final class GameplayEventStateMachineTests: XCTestCase {
    func testFormDowngradeEmitsDamageOnce() {
        let machine = GameplayEventStateMachine(profile: .sma2SuperMarioWorld)
        let t0 = Date(timeIntervalSinceReferenceDate: 100)
        _ = machine.consume(makeObservation(state: .superState, confidence: 0.9, timestamp: t0))

        let damage = machine.consume(
            makeObservation(state: .small, confidence: 0.9, timestamp: t0.addingTimeInterval(0.2))
        )

        XCTAssertEqual(damage.events, [.damageHeavy])

        let suppressed = machine.consume(
            makeObservation(
                state: .invulnerableBlink,
                confidence: 0.7,
                blinkConfidence: 0.9,
                hurtConfidence: 0.8,
                timestamp: t0.addingTimeInterval(0.5)
            )
        )

        XCTAssertTrue(suppressed.events.isEmpty)
        XCTAssertTrue(suppressed.snapshot.inDamageCooldown)
    }

    func testFadeAndLifeLossConfirmDeath() {
        let machine = GameplayEventStateMachine(profile: .sma2SuperMarioWorld)
        let t0 = Date(timeIntervalSinceReferenceDate: 200)
        _ = machine.consume(makeObservation(state: .small, confidence: 0.88, timestamp: t0))

        let death = machine.consume(
            makeObservation(
                state: .unknown,
                confidence: 0.2,
                deathConfidence: 0.92,
                fadeConfidence: 0.8,
                lifeLossConfidence: 0.8,
                phase: .transition,
                timestamp: t0.addingTimeInterval(0.3)
            )
        )

        XCTAssertEqual(death.events, [.deathDetected])
        XCTAssertTrue(death.snapshot.inDeathSequence)
    }

    private func makeObservation(
        state: MarioPlayerState,
        confidence: Double,
        blinkConfidence: Double = 0,
        hurtConfidence: Double = 0,
        deathConfidence: Double = 0,
        fadeConfidence: Double = 0,
        lifeLossConfidence: Double = 0,
        phase: MarioGameplayPhase = .gameplayActive,
        timestamp: Date
    ) -> MarioObservation {
        MarioObservation(
            playerState: state,
            playerStateConfidence: confidence,
            blinkConfidence: blinkConfidence,
            hurtPoseConfidence: hurtConfidence,
            deathAnimationConfidence: deathConfidence,
            transitionFadeConfidence: fadeConfidence,
            lifeLossScreenConfidence: lifeLossConfidence,
            gameplayPhase: phase,
            playerBounds: nil,
            timestamp: timestamp
        )
    }
}
