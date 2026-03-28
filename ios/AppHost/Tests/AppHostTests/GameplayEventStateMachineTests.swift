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

    func testMemoryBackedDeathSequenceTriggersDeath() {
        let machine = GameplayEventStateMachine(profile: .sma2SuperMarioWorld)
        let result = machine.consume(
            makeObservation(
                state: .dead,
                confidence: 0.98,
                deathConfidence: 1.0,
                fadeConfidence: 1.0,
                lifeLossConfidence: 1.0,
                phase: .deathSequence,
                timestamp: Date(timeIntervalSinceReferenceDate: 250)
            )
        )

        XCTAssertEqual(result.events, [.deathDetected])
    }

    func testHurtAndBlinkComboEmitsLightDamage() {
        let machine = GameplayEventStateMachine(profile: .sma2SuperMarioWorld)
        let result = machine.consume(
            makeObservation(
                state: .hurt,
                confidence: 0.9,
                blinkConfidence: 0.9,
                hurtConfidence: 0.95,
                timestamp: Date(timeIntervalSinceReferenceDate: 300)
            )
        )

        XCTAssertEqual(result.events, [.damageLight])
    }

    func testMemoryBackedDamageWithoutFormDowngradeStillEmitsLightDamage() {
        let machine = GameplayEventStateMachine(profile: .dragonBallAdvancedAdventure)
        let result = machine.consume(
            makeObservation(
                state: .superState,
                confidence: 0.98,
                blinkConfidence: 0.9,
                hurtConfidence: 1.0,
                phase: .gameplayActive,
                timestamp: Date(timeIntervalSinceReferenceDate: 325)
            )
        )

        XCTAssertEqual(result.events, [.damageLight])
    }

    func testGameplayResumesAfterDeathSequenceAndAllowsBlinkDamage() {
        let machine = GameplayEventStateMachine(profile: .sma4SuperMarioBros3)
        let t0 = Date(timeIntervalSinceReferenceDate: 400)

        _ = machine.consume(
            makeObservation(
                state: .dead,
                confidence: 1.0,
                deathConfidence: 1.0,
                fadeConfidence: 1.0,
                lifeLossConfidence: 1.0,
                phase: .deathSequence,
                timestamp: t0
            )
        )

        _ = machine.consume(
            makeObservation(
                state: .poweredUp,
                confidence: 0.95,
                phase: .gameplayActive,
                timestamp: t0.addingTimeInterval(2.0)
            )
        )

        let damage = machine.consume(
            makeObservation(
                state: .invulnerableBlink,
                confidence: 0.98,
                blinkConfidence: 0.95,
                hurtConfidence: 1.0,
                phase: .gameplayActive,
                timestamp: t0.addingTimeInterval(2.2)
            )
        )

        XCTAssertEqual(damage.events, [.damageLight])
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
            memoryDebugSummary: nil,
            locationDebugSummary: nil,
            timestamp: timestamp
        )
    }
}
