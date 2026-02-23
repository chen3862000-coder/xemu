import SwiftUI

enum AppThemeMode: String, CaseIterable {
    case light
    case dark
}

@MainActor
final class ThemeController: ObservableObject {
    static let shared = ThemeController()

    private static let storageKey = "appThemeMode"

    @Published private(set) var mode: AppThemeMode

    private init() {
        if let stored = UserDefaults.standard.string(forKey: Self.storageKey),
           let parsed = AppThemeMode(rawValue: stored) {
            mode = parsed
        } else {
            mode = .light
            UserDefaults.standard.set(AppThemeMode.light.rawValue, forKey: Self.storageKey)
        }
    }

    var colorScheme: ColorScheme {
        mode == .light ? .light : .dark
    }

    var isLightMode: Bool {
        mode == .light
    }

    func setMode(_ newMode: AppThemeMode) {
        guard mode != newMode else { return }
        mode = newMode
        UserDefaults.standard.set(newMode.rawValue, forKey: Self.storageKey)
    }

    func toggleMode() {
        setMode(mode == .light ? .dark : .light)
    }
}

