import Foundation
import Combine

final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()

    private enum Storage {
        static let languageKey = "app.language"
    }

    @Published private(set) var currentLanguage: SupportedLanguage

    private let userDefaults: UserDefaults
    private let preferredLanguagesProvider: @Sendable () -> [String]
    private var localeObserver: NSObjectProtocol?

    init(
        userDefaults: UserDefaults = .standard,
        preferredLanguagesProvider: @escaping @Sendable () -> [String] = { Locale.preferredLanguages }
    ) {
        self.userDefaults = userDefaults
        self.preferredLanguagesProvider = preferredLanguagesProvider

        let storedValue = userDefaults.string(forKey: Storage.languageKey) ?? SupportedLanguage.system.rawValue
        self.currentLanguage = SupportedLanguage(rawValue: storedValue) ?? .system

        localeObserver = NotificationCenter.default.addObserver(
            forName: NSLocale.currentLocaleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.currentLanguage == .system else { return }
            self.objectWillChange.send()
        }
    }

    deinit {
        if let localeObserver {
            NotificationCenter.default.removeObserver(localeObserver)
        }
    }

    var resolvedLanguage: SupportedLanguage {
        if currentLanguage == .system {
            return SupportedLanguage.bestMatch(for: preferredLanguagesProvider().first)
        }
        return currentLanguage
    }

    var formattingLocale: Locale {
        if currentLanguage == .system {
            return .autoupdatingCurrent
        }
        return Locale(identifier: resolvedLanguage.localeIdentifier ?? "en")
    }

    var localizationBundle: Bundle {
        bundle(for: resolvedLanguage)
    }

    var refreshID: String {
        "\(currentLanguage.rawValue)-\(resolvedLanguage.rawValue)-\(formattingLocale.identifier)"
    }

    func setLanguage(_ language: SupportedLanguage) {
        guard currentLanguage != language else { return }
        currentLanguage = language
        userDefaults.set(language.rawValue, forKey: Storage.languageKey)
    }

    private func bundle(for language: SupportedLanguage) -> Bundle {
        let baseBundle = LocalizationBundle.base

        guard let identifier = language.localeIdentifier else {
            return baseBundle
        }

        if let languageBundle = localizedBundle(in: baseBundle, identifier: identifier) {
            return languageBundle
        }

        if let languageCode = Locale(identifier: identifier).language.languageCode?.identifier,
           let languageBundle = localizedBundle(in: baseBundle, identifier: languageCode) {
            return languageBundle
        }

        if language != .en,
           let englishBundle = localizedBundle(in: baseBundle, identifier: "en") {
            return englishBundle
        }

        return baseBundle
    }

    private func localizedBundle(in baseBundle: Bundle, identifier: String) -> Bundle? {
        guard let path = baseBundle.path(forResource: identifier, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
