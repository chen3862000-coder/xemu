import Foundation

struct HelpSupportCatalog: Codable, Hashable {
    let ui: HelpSupportUIStrings
    let categories: [HelpSupportCategory]
    let supportActions: [HelpSupportAction]

    func category(id: String) -> HelpSupportCategory? {
        categories.first { $0.id == id }
    }

    func article(id: String) -> (category: HelpSupportCategory, item: HelpSupportItem)? {
        for category in categories {
            if let item = category.items.first(where: { $0.id == id }) {
                return (category, item)
            }
        }
        return nil
    }

    func action(id: String) -> HelpSupportAction? {
        supportActions.first { $0.id == id }
    }

    func searchResults(matching query: String, locale: Locale) -> [HelpSupportSearchResult] {
        let normalizedQuery = HelpSupportLocalization.normalize(query)
        guard !normalizedQuery.isEmpty else { return [] }

        return categories
            .flatMap { category in
                category.items.compactMap { item -> HelpSupportSearchResult? in
                    let title = HelpSupportLocalization.normalize(item.title(for: locale))
                    let summary = HelpSupportLocalization.normalize(item.summary(for: locale) ?? "")
                    let steps = HelpSupportLocalization.normalize(item.steps(for: locale).joined(separator: " "))
                    let keywords = HelpSupportLocalization.normalize(item.keywords(for: locale).joined(separator: " "))

                    var score = 0
                    if title == normalizedQuery { score += 400 }
                    if title.hasPrefix(normalizedQuery) { score += 250 }
                    if title.contains(normalizedQuery) { score += 200 }
                    if keywords.contains(normalizedQuery) { score += 300 }
                    if summary.contains(normalizedQuery) { score += 60 }
                    if steps.contains(normalizedQuery) { score += 40 }
                    if item.isFeatured { score += 75 }

                    guard score > 0 else { return nil }
                    return HelpSupportSearchResult(category: category, item: item, score: score)
                }
            }
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                return $0.item.title(for: locale).localizedCaseInsensitiveCompare($1.item.title(for: locale)) == .orderedAscending
            }
    }
}

struct HelpSupportUIStrings: Codable, Hashable {
    let screenTitle: [String: String]
    let searchPlaceholder: [String: String]
    let popularHelpTitle: [String: String]
    let browseByTopicTitle: [String: String]
    let getInTouchTitle: [String: String]
    let legalTitle: [String: String]
    let noResultsTitle: [String: String]
    let noResultsBody: [String: String]
    let moreHelpComingTitle: [String: String]
    let moreHelpComingBody: [String: String]
    let expandedState: [String: String]
    let collapsedState: [String: String]
    let replayGuideTitle: [String: String]
    let replayGuideMessage: [String: String]

    func text(_ values: KeyPath<HelpSupportUIStrings, [String: String]>, locale: Locale) -> String {
        HelpSupportLocalization.text(self[keyPath: values], locale: locale)
    }
}

struct HelpSupportCategory: Codable, Identifiable, Hashable {
    let id: String
    let icon: String
    let title: [String: String]
    let items: [HelpSupportItem]

    func title(for locale: Locale) -> String {
        HelpSupportLocalization.text(title, locale: locale)
    }
}

struct HelpSupportItem: Codable, Identifiable, Hashable {
    let id: String
    let icon: String?
    let title: [String: String]
    let keywords: [String: [String]]
    let summary: [String: String]?
    let steps: [String: [String]]
    let tip: [String: String]?
    let isFeatured: Bool

    func title(for locale: Locale) -> String {
        HelpSupportLocalization.text(title, locale: locale)
    }

    func summary(for locale: Locale) -> String? {
        guard let summary else { return nil }
        return HelpSupportLocalization.text(summary, locale: locale)
    }

    func steps(for locale: Locale) -> [String] {
        HelpSupportLocalization.list(steps, locale: locale)
    }

    func tip(for locale: Locale) -> String? {
        guard let tip else { return nil }
        return HelpSupportLocalization.text(tip, locale: locale)
    }

    func keywords(for locale: Locale) -> [String] {
        HelpSupportLocalization.list(keywords, locale: locale)
    }
}

struct HelpSupportAction: Codable, Identifiable, Hashable {
    let id: String
    let destination: HelpSupportActionDestination
    let icon: String
    let title: [String: String]
    let subtitle: [String: String]
    let emailSubject: [String: String]?
    let emailBody: [String: String]?

    func title(for locale: Locale) -> String {
        HelpSupportLocalization.text(title, locale: locale)
    }

    func subtitle(for locale: Locale) -> String {
        HelpSupportLocalization.text(subtitle, locale: locale)
    }

    func emailSubject(for locale: Locale) -> String? {
        guard let emailSubject else { return nil }
        return HelpSupportLocalization.text(emailSubject, locale: locale)
    }

    func emailBody(for locale: Locale) -> String? {
        guard let emailBody else { return nil }
        return HelpSupportLocalization.text(emailBody, locale: locale)
    }
}

enum HelpSupportActionDestination: String, Codable, Hashable {
    case contactSupport
    case sendFeedback
    case replayGuide
}

struct HelpSupportSearchResult: Identifiable, Hashable {
    let category: HelpSupportCategory
    let item: HelpSupportItem
    let score: Int

    var id: String { item.id }
}

enum HelpSupportLocalization {
    static func text(_ values: [String: String], locale: Locale) -> String {
        LocalizedContentResolver.resolve(values: values, locale: locale) ?? values["en"] ?? ""
    }

    static func list(_ values: [String: [String]], locale: Locale) -> [String] {
        let identifier = locale.identifier
        let normalizedIdentifier = identifier.replacingOccurrences(of: "_", with: "-")

        if let exact = values[identifier] {
            return exact
        }

        if let normalizedExact = values[normalizedIdentifier] {
            return normalizedExact
        }

        if normalizedIdentifier.hasPrefix("zh-Hant"), let hant = values["zh-Hant"] {
            return hant
        }

        if normalizedIdentifier.hasPrefix("zh-Hans"), let hans = values["zh-Hans"] {
            return hans
        }

        if let matchedLanguageKey = SupportedLanguage.bestMatch(for: normalizedIdentifier).localeIdentifier,
           let matchedLanguageValue = values[matchedLanguageKey] {
            return matchedLanguageValue
        }

        if let languageCode = locale.language.languageCode?.identifier,
           let base = values[languageCode] {
            return base
        }

        if let fallback = values["en"] {
            return fallback
        }

        return values.keys.sorted().compactMap { values[$0] }.first ?? []
    }

    static func normalize(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }
}

extension LocalizedContentStore {
    static func loadHelpSupportCatalog(bundle: Bundle = LocalizationBundle.base) -> HelpSupportCatalog {
        guard let url = resourceURL(named: "help_support", bundle: bundle) else {
            return HelpSupportCatalog(ui: .empty, categories: [], supportActions: [])
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(HelpSupportCatalog.self, from: data)
        } catch {
            return HelpSupportCatalog(ui: .empty, categories: [], supportActions: [])
        }
    }
}

private extension HelpSupportUIStrings {
    static let empty = HelpSupportUIStrings(
        screenTitle: ["en": "Help & Support"],
        searchPlaceholder: ["en": "Search help"],
        popularHelpTitle: ["en": "Popular Help"],
        browseByTopicTitle: ["en": "Browse by Topic"],
        getInTouchTitle: ["en": "Get in Touch"],
        legalTitle: ["en": "Legal"],
        noResultsTitle: ["en": "No Results"],
        noResultsBody: ["en": "Try different keywords like save, controller, or audio."],
        moreHelpComingTitle: ["en": "More help is coming"],
        moreHelpComingBody: ["en": "This section will expand in future updates."],
        expandedState: ["en": "Expanded"],
        collapsedState: ["en": "Collapsed"],
        replayGuideTitle: ["en": "Guide Ready"],
        replayGuideMessage: ["en": "The launch guide will appear the next time you start a game."]
    )
}
