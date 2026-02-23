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
                primary: Color(hex: "9333EA"),
                secondary: Color(hex: "F3E8FF"),
                accent: Color(hex: "7C3AED"),
                background: Color(hex: "FAF8FC"),
                surface: Color(hex: "FFFFFF"),
                surfaceLight: Color(hex: "F3E8FF"),
                textPrimary: Color(hex: "1A0B2E"),
                textSecondary: Color(hex: "6B21A8"),
                textMuted: Color(hex: "8B5FBF"),
                label: Color(hex: "1A0B2E"),
                secondaryLabel: Color(hex: "6B21A8"),
                destructive: Color(hex: "DC2626"),
                success: Color(hex: "22C55E"),
                warning: Color(hex: "F59E0B"),
                error: Color(hex: "DC2626"),
                info: Color(hex: "3B82F6")
            )
        case .dark:
            return Palette(
                primary: Color(hex: "9333EA"),
                secondary: Color(hex: "1E0A35"),
                accent: Color(hex: "7C3AED"),
                background: Color(hex: "0A0118"),
                surface: Color(hex: "160428"),
                surfaceLight: Color(hex: "1E0A35"),
                textPrimary: Color(hex: "FAFAFA"),
                textSecondary: Color(hex: "C4B5FD"),
                textMuted: Color(hex: "A78BCA"),
                label: Color(hex: "FAFAFA"),
                secondaryLabel: Color(hex: "C4B5FD"),
                destructive: Color(hex: "D4183D"),
                success: Color(hex: "22C55E"),
                warning: Color(hex: "F59E0B"),
                error: Color(hex: "D4183D"),
                info: Color(hex: "3B82F6")
            )
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
