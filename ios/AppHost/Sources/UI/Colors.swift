import SwiftUI

struct AppColors {
    static let primary = Color(hex: "6366F1")
    static let secondary = Color(hex: "8B5CF6")
    static let accent = Color(hex: "EC4899")
    static let background = Color(hex: "09090B")
    static let surface = Color(hex: "18181B")
    static let surfaceLight = Color(hex: "27272A")
    static let textPrimary = Color(hex: "FAFAFA")
    static let textSecondary = Color(hex: "A1A1AA")
    static let textMuted = Color(hex: "71717A")
    static let label = Color(hex: "FAFAFA")
    static let secondaryLabel = Color(hex: "A1A1AA")
    static let destructive = Color(hex: "EF4444")
    static let success = Color(hex: "22C55E")
    static let warning = Color(hex: "F59E0B")
    static let error = Color(hex: "EF4444")
    static let info = Color(hex: "3B82F6")
    static let clear = Color.clear
    
    static let gradients: [String: LinearGradient] = [
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
