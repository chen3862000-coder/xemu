import Foundation

enum LocalizationDiagnostics {
    static func reportMissingKey(_ key: String, table: String, locale: Locale) {
        _ = key
        _ = table
        _ = locale
    }

    static func reportFallbackHit(_ key: String, requestedLocale: Locale, resolvedLocale: Locale) {
        _ = key
        _ = requestedLocale
        _ = resolvedLocale
    }
}
