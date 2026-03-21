import Foundation
#if os(iOS)
import UIKit
#endif

final class HapticManager {
    static let shared = HapticManager()

    #if os(iOS)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    #endif

    private init() {
        #if os(iOS)
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFeedback.prepare()
        #endif
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "settings.controller.hapticFeedback") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "settings.controller.hapticFeedback") }
    }

    var gameplayHapticsEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "settings.dev.hpDeathDetection") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "settings.dev.hpDeathDetection") }
    }

    func buttonPressed() {
        #if os(iOS)
        guard isEnabled else { return }
        lightImpact.impactOccurred()
        lightImpact.prepare()
        #endif
    }

    func buttonReleased() {
        #if os(iOS)
        guard isEnabled else { return }
        lightImpact.impactOccurred(intensity: 0.5)
        #endif
    }

    func selectionChanged() {
        #if os(iOS)
        guard isEnabled else { return }
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
        #endif
    }

    func gameplayEvent(_ event: GameplayEvent) {
        #if os(iOS)
        guard isEnabled, gameplayHapticsEnabled else { return }
        GameplayAnalysisLogger.event("haptic event=\(event.rawValue)")
        
        switch event {
        case .damageLight:
            triggerDamageLight()
        case .damageHeavy:
            triggerDamageHeavy()
        case .deathDetected:
            triggerDeathSequence()
        case .powerUpCollected:
            mediumImpact.impactOccurred(intensity: 0.85)
            mediumImpact.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.heavyImpact.impactOccurred(intensity: 0.7)
                self?.heavyImpact.prepare()
            }
        case .coinCollected:
            lightImpact.impactOccurred(intensity: 0.35)
            lightImpact.prepare()
        case .levelCompleted:
            triggerVictorySequence()
        case .lifeLost:
            triggerLifeLostSequence()
        case .checkpointReached:
            mediumImpact.impactOccurred(intensity: 0.65)
            mediumImpact.prepare()
        case .enemyStomped:
            mediumImpact.impactOccurred(intensity: 0.55)
            mediumImpact.prepare()
        case .lowHealthWarning:
            lightImpact.impactOccurred(intensity: 0.4)
            lightImpact.prepare()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.lightImpact.impactOccurred(intensity: 0.4)
                self?.lightImpact.prepare()
            }
        }
        #endif
    }

    private func triggerDamageLight() {
        #if os(iOS)
        lightImpact.impactOccurred(intensity: 0.8)
        lightImpact.prepare()
        #endif
    }

    private func triggerDamageHeavy() {
        #if os(iOS)
        mediumImpact.impactOccurred(intensity: 0.95)
        mediumImpact.prepare()
        #endif
    }
    
    private func triggerDeathSequence() {
        #if os(iOS)
        heavyImpact.impactOccurred(intensity: 1.0)
        heavyImpact.prepare()

        scheduleHeavyImpact(after: 0.10, intensity: 1.0)
        scheduleHeavyImpact(after: 0.22, intensity: 0.95)
        scheduleHeavyImpact(after: 0.36, intensity: 0.9)
        scheduleMediumImpact(after: 0.52, intensity: 0.75)
        scheduleMediumImpact(after: 0.68, intensity: 0.6)
        #endif
    }
    
    private func triggerVictorySequence() {
        #if os(iOS)
        mediumImpact.impactOccurred(intensity: 0.7)
        mediumImpact.prepare()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.mediumImpact.impactOccurred(intensity: 0.8)
            self?.mediumImpact.prepare()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.heavyImpact.impactOccurred(intensity: 0.9)
            self?.heavyImpact.prepare()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.heavyImpact.impactOccurred(intensity: 1.0)
            self?.heavyImpact.prepare()
        }
        #endif
    }
    
    private func triggerLifeLostSequence() {
        #if os(iOS)
        heavyImpact.impactOccurred(intensity: 0.95)
        heavyImpact.prepare()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.heavyImpact.impactOccurred(intensity: 0.85)
            self?.heavyImpact.prepare()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.mediumImpact.impactOccurred(intensity: 0.7)
            self?.mediumImpact.prepare()
        }
        #endif
    }

    private func scheduleHeavyImpact(after delay: TimeInterval, intensity: CGFloat) {
        #if os(iOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.heavyImpact.impactOccurred(intensity: intensity)
            self?.heavyImpact.prepare()
        }
        #endif
    }

    private func scheduleMediumImpact(after delay: TimeInterval, intensity: CGFloat) {
        #if os(iOS)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.mediumImpact.impactOccurred(intensity: intensity)
            self?.mediumImpact.prepare()
        }
        #endif
    }
}
