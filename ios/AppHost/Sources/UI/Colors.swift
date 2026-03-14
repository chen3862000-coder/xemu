import SwiftUI

struct AppColors {
    private struct Palette {
        let primary: Color
        let secondary: Color
        let accent: Color
        let background: Color
        let surface: Color
        let surfaceLight: Color
        let textPrimary: Color
        let textSecondary: Color
        let textMuted: Color
        let label: Color
        let secondaryLabel: Color
        let destructive: Color
        let success: Color
        let warning: Color
        let error: Color
        let info: Color
    }

    private static var currentTheme: AppThemeMode {
        if let raw = UserDefaults.standard.string(forKey: "appThemeMode"),
           let mode = AppThemeMode(rawValue: raw) {
            return mode
        }
        return .light
    }

    private static var palette: Palette {
        switch currentTheme {
        case .light:
            return Palette(
                primary: Color(hex: "8B3DFF"),
                secondary: Color(hex: "EDE1FF"),
                accent: Color(hex: "7B2FEA"),
                background: Color(hex: "F5F2FA"),
                surface: Color(hex: "FFFFFF"),
                surfaceLight: Color(hex: "F1ECF8"),
                textPrimary: Color(hex: "23232B"),
                textSecondary: Color(hex: "6A6A75"),
                textMuted: Color(hex: "9A9AA6"),
                label: Color(hex: "23232B"),
                secondaryLabel: Color(hex: "6A6A75"),
                destructive: Color(hex: "DC2626"),
                success: Color(hex: "22C55E"),
                warning: Color(hex: "F59E0B"),
                error: Color(hex: "DC2626"),
                info: Color(hex: "3B82F6")
            )
        case .dark:
            return Palette(
                primary: Color(hex: "9B6BFF"),
                secondary: Color(hex: "201D2B"),
                accent: Color(hex: "9B6BFF"),
                background: Color(hex: "0B0B12"),
                surface: Color(hex: "14141D"),
                surfaceLight: Color(hex: "202031"),
                textPrimary: Color(hex: "F3F2F7"),
                textSecondary: Color(hex: "B2B0C0"),
                textMuted: Color(hex: "7F7B92"),
                label: Color(hex: "FAFAFA"),
                secondaryLabel: Color(hex: "B2B0C0"),
                destructive: Color(hex: "C75B72"),
                success: Color(hex: "6BB98E"),
                warning: Color(hex: "C8A45A"),
                error: Color(hex: "C75B72"),
                info: Color(hex: "6C9CFF")
            )
        }
    }

    static var isDarkMode: Bool { currentTheme == .dark }

    enum Background {
        static var appPrimary: Color { AppColors.isDarkMode ? Color(hex: "0B0B12") : AppColors.background }
        static var appSecondary: Color { AppColors.isDarkMode ? Color(hex: "11111A") : Color(hex: "EEE8F6") }
        static var appTertiary: Color { AppColors.isDarkMode ? Color(hex: "181824") : Color(hex: "E5DEEF") }
    }

    enum Surface {
        static var cardPrimary: Color { AppColors.isDarkMode ? Color(hex: "14141D") : AppColors.surface }
        static var cardSecondary: Color { AppColors.isDarkMode ? Color(hex: "1A1A25") : Color(hex: "F8F5FC") }
        static var cardElevated: Color { AppColors.isDarkMode ? Color(hex: "202031") : Color(hex: "F1ECF8") }
        static var cardOverlay: Color { AppColors.isDarkMode ? Color.black.opacity(0.58) : Color.black.opacity(0.36) }
        static var accentTint: Color { AppColors.primary.opacity(AppColors.isDarkMode ? 0.14 : 0.10) }
        static var accentTintStrong: Color { AppColors.primary.opacity(AppColors.isDarkMode ? 0.20 : 0.16) }
    }

    enum Text {
        static var primary: Color { AppColors.textPrimary }
        static var secondary: Color { AppColors.textSecondary }
        static var tertiary: Color { AppColors.textMuted }
        static var accent: Color { AppColors.primary }
    }

    enum Border {
        static var subtle: Color {
            AppColors.isDarkMode ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
        }

        static var active: Color {
            AppColors.isDarkMode ? AppColors.primary.opacity(0.24) : AppColors.primary.opacity(0.18)
        }

        static var softDivider: Color {
            AppColors.isDarkMode ? Color.white.opacity(0.08) : Color.black.opacity(0.06)
        }
    }

    enum Shadow {
        static var card: Color {
            AppColors.isDarkMode ? Color.black.opacity(0.26) : Color.black.opacity(0.10)
        }

        static var ambientGlow: Color {
            AppColors.primary.opacity(AppColors.isDarkMode ? 0.18 : 0.10)
        }
    }

    static var primary: Color { palette.primary }
    static var secondary: Color { palette.secondary }
    static var accent: Color { palette.accent }
    static var background: Color { palette.background }
    static var surface: Color { palette.surface }
    static var surfaceLight: Color { palette.surfaceLight }
    static var textPrimary: Color { palette.textPrimary }
    static var textSecondary: Color { palette.textSecondary }
    static var textMuted: Color { palette.textMuted }
    static var label: Color { palette.label }
    static var secondaryLabel: Color { palette.secondaryLabel }
    static var destructive: Color { palette.destructive }
    static var success: Color { palette.success }
    static var warning: Color { palette.warning }
    static var error: Color { palette.error }
    static var info: Color { palette.info }
    static let clear = Color.clear

    static var gradients: [String: LinearGradient] {
        [
            "nes": LinearGradient(colors: [Color(hex: "EF4444"), Color(hex: "F97316")], startPoint: .topLeading, endPoint: .bottomTrailing),
            "gb": LinearGradient(colors: [Color(hex: "22C55E"), Color(hex: "16A34A")], startPoint: .topLeading, endPoint: .bottomTrailing),
            "gbc": LinearGradient(colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")], startPoint: .topLeading, endPoint: .bottomTrailing),
            "gba": LinearGradient(colors: [Color(hex: "8B5CF6"), Color(hex: "7C3AED")], startPoint: .topLeading, endPoint: .bottomTrailing),
            "nds": LinearGradient(colors: [Color(hex: "EC4899"), Color(hex: "DB2777")], startPoint: .topLeading, endPoint: .bottomTrailing),
            "ps1": LinearGradient(colors: [Color(hex: "6366F1"), Color(hex: "4F46E5")], startPoint: .topLeading, endPoint: .bottomTrailing),
            "3ds": LinearGradient(colors: [Color(hex: "06B6D4"), Color(hex: "0891B2")], startPoint: .topLeading, endPoint: .bottomTrailing),
            "psp": LinearGradient(colors: [Color(hex: "F59E0B"), Color(hex: "D97706")], startPoint: .topLeading, endPoint: .bottomTrailing),
            "genesis": LinearGradient(colors: [Color(hex: "3B82F6"), Color(hex: "2563EB")], startPoint: .topLeading, endPoint: .bottomTrailing),
        ]
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
