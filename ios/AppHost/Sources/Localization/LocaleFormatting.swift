import Foundation

enum LocaleFormatting {
    static func shortDuration(
        seconds: Int,
        minimumMinutes: Int = 0,
        languageManager: LanguageManager = .shared
    ) -> String {
        let totalSeconds = max(0, seconds)
        let hours = totalSeconds / 3600
        let minutes = max(minimumMinutes, (totalSeconds % 3600) / 60)

        if hours > 0, minutes > 0 {
            return L10n.format(
                "common.duration_hours_minutes",
                Int64(hours),
                Int64(minutes),
                table: "Screens",
                languageManager: languageManager
            )
        }

        if hours > 0 {
            return L10n.format(
                "common.duration_hours_only",
                Int64(hours),
                table: "Screens",
                languageManager: languageManager
            )
        }

        return L10n.format(
            "common.duration_minutes_only",
            Int64(max(minimumMinutes, totalSeconds / 60)),
            table: "Screens",
            languageManager: languageManager
        )
    }

    static func decimalHours(
        seconds: Int,
        languageManager: LanguageManager = .shared
    ) -> String {
        let hours = Double(max(0, seconds)) / 3600.0
        if hours >= 1 {
            return L10n.format(
                "common.duration_decimal_hours",
                hours,
                table: "Screens",
                languageManager: languageManager
            )
        }

        return shortDuration(seconds: seconds, minimumMinutes: 1, languageManager: languageManager)
    }
}
