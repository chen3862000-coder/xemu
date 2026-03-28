import Foundation

struct LocalizedConsoleDescription: Codable, Identifiable, Equatable {
    let consoleID: String
    let localizedNames: [String: String]
    let localizedDescriptions: [String: String]

    var id: String { consoleID }

    func name(for locale: Locale) -> String {
        LocalizedContentResolver.resolve(values: localizedNames, locale: locale) ?? consoleID
    }

    func description(for locale: Locale) -> String? {
        LocalizedContentResolver.resolve(values: localizedDescriptions, locale: locale)
    }
}

struct GlossaryEntry: Codable, Identifiable, Equatable {
    let termKey: String
    let source: String
    let description: String
    let translations: [String: String]

    var id: String { termKey }

    func translation(for locale: Locale) -> String? {
        LocalizedContentResolver.resolve(values: translations, locale: locale)
    }
}

enum LocalizedContentResolver {
    static func resolve(
        values: [String: String],
        locale: Locale,
        fallbackLanguage: String = "en"
    ) -> String? {
        let identifier = locale.identifier

        if let exact = values[identifier] {
            return exact
        }

        if identifier.hasPrefix("zh-Hant"), let hant = values["zh-Hant"] {
            return hant
        }

        if identifier.hasPrefix("zh-Hans"), let hans = values["zh-Hans"] {
            return hans
        }

        if let languageCode = locale.language.languageCode?.identifier,
           let base = values[languageCode] {
            return base
        }

        if let fallback = values[fallbackLanguage] {
            return fallback
        }

        return values.values.sorted().first
    }
}

enum LocalizedContentStore {
    static func loadConsoles(bundle: Bundle = LocalizationBundle.base) -> [LocalizedConsoleDescription] {
        loadResource(named: "consoles", bundle: bundle)
    }

    static func loadGlossary(bundle: Bundle = LocalizationBundle.base) -> [GlossaryEntry] {
        loadResource(named: "glossary", bundle: bundle)
    }

    private static func loadResource<T: Decodable>(named name: String, bundle: Bundle) -> [T] {
        guard let url = bundle.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "LocalizedContent"
        ) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([T].self, from: data)
        } catch {
            return []
        }
    }
}
