import Foundation
#if os(iOS)
import UIKit
#endif

final class HapticManager {
    static let shared = HapticManager()

    #if os(iOS)
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    #endif

    private init() {
        #if os(iOS)
        lightImpact.prepare()
        mediumImpact.prepare()
        selectionFeedback.prepare()
        #endif
    }

    var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "settings.controller.hapticFeedback") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "settings.controller.hapticFeedback") }
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
}
