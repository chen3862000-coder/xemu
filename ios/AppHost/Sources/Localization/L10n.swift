import Foundation

enum L10n {
    static func string(
        _ key: String,
        table: String = "AppUI",
        fallback: String? = nil,
        languageManager: LanguageManager = .shared
    ) -> String {
        string(
            key,
            table: table,
            bundle: languageManager.localizationBundle,
            locale: languageManager.formattingLocale,
            fallback: fallback
        )
    }

    static func format(
        _ key: String,
        _ arguments: CVarArg...,
        table: String = "AppUI",
        fallback: String? = nil,
        languageManager: LanguageManager = .shared
    ) -> String {
        let format = string(key, table: table, fallback: fallback, languageManager: languageManager)
        return String(format: format, locale: languageManager.formattingLocale, arguments: arguments)
    }

    static func string(
        _ key: String,
        table: String,
        bundle: Bundle,
        locale: Locale,
        fallback: String? = nil
    ) -> String {
        let value = NSLocalizedString(key, tableName: table, bundle: bundle, value: fallback ?? key, comment: "")
        if value == key {
            if let fallbackValue = StringCatalogFallback.localizedValue(for: key, table: table, bundle: bundle, locale: locale) {
                return fallbackValue
            }

            LocalizationDiagnostics.reportMissingKey(key, table: table, locale: locale)
            return fallback ?? key
        }

        let bundleLocale = bundle.preferredLocalizations.first.map(Locale.init(identifier:)) ?? locale
        LocalizationDiagnostics.reportFallbackHit(key, requestedLocale: locale, resolvedLocale: bundleLocale)
        return value
    }
}
