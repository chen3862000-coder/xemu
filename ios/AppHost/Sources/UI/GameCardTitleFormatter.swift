import Foundation

enum GameCardTitleFormatter {
    static func format(_ rawTitle: String?, maxWords: Int = 7) -> String {
        let raw = (rawTitle ?? "Unknown Game").trimmingCharacters(in: .whitespacesAndNewlines)
        let withoutTags = raw.replacingOccurrences(
            of: #"\s*\([^)]*\)"#,
            with: "",
            options: .regularExpression
        )
        let normalized = withoutTags
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let words = normalized.split(separator: " ")
        guard words.count > maxWords else { return normalized.isEmpty ? "Unknown Game" : normalized }
        let prefix = words.prefix(maxWords).joined(separator: " ")
        return prefix + "…"
    }
}
