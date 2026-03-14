import Foundation

enum LocalizationDiagnostics {
    static func reportMissingKey(_ key: String, table: String, locale: Locale) {
#if DEBUG
        print("⚠️ Missing localization key '\(key)' in table '\(table)' for locale '\(locale.identifier)'")
#endif
    }

    static func reportFallbackHit(_ key: String, requestedLocale: Locale, resolvedLocale: Locale) {
#if DEBUG
        guard requestedLocale.identifier != resolvedLocale.identifier else { return }
        print(
            "ℹ️ Localization fallback for key '\(key)': requested '\(requestedLocale.identifier)', resolved '\(resolvedLocale.identifier)'"
        )
#endif
    }
}
