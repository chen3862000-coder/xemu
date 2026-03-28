import Foundation

enum SupportedLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case en
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case ja
    case es

    var id: String { rawValue }

    var localeIdentifier: String? {
        switch self {
        case .system:
            nil
        case .en:
            "en"
        case .zhHans:
            "zh-Hans"
        case .zhHant:
            "zh-Hant"
        case .ja:
            "ja"
        case .es:
            "es"
        }
    }

    var nativeDisplayName: String {
        switch self {
        case .system:
            "Follow System"
        case .en:
            "English"
        case .zhHans:
            "简体中文"
        case .zhHant:
            "繁體中文"
        case .ja:
            "日本語"
        case .es:
            "Español"
        }
    }

    static let launchLanguages: [SupportedLanguage] = [.en, .zhHans, .zhHant, .ja, .es]

    static func bestMatch(for identifier: String?) -> SupportedLanguage {
        let normalized = (identifier ?? "")
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()

        guard !normalized.isEmpty else { return .en }

        if normalized.hasPrefix("zh") {
            if normalized.contains("hant")
                || normalized.hasSuffix("-tw")
                || normalized.hasSuffix("-hk")
                || normalized.hasSuffix("-mo") {
                return .zhHant
            }
            return .zhHans
        }

        if normalized.hasPrefix("ja") {
            return .ja
        }

        if normalized.hasPrefix("es") {
            return .es
        }

        return .en
    }
}
