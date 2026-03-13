import SwiftUI

enum ConsoleIdentity: String, CaseIterable, Identifiable {
    case gb
    case gbc
    case gba
    case nds

    var id: String { rawValue }

    var systemCode: String { rawValue.uppercased() }

    var displayName: String {
        switch self {
        case .gb: return "Game Boy"
        case .gbc: return "Game Boy Color"
        case .gba: return "Game Boy Advance"
        case .nds: return "Nintendo DS"
        }
    }

    var shortName: String { systemCode }

    var assetName: String {
        switch self {
        case .gb: return "ConsoleGB"
        case .gbc: return "ConsoleGBC"
        case .gba: return "ConsoleGBA"
        case .nds: return "ConsoleNDS"
        }
    }

    var accentColor: Color {
        switch self {
        case .gb: return Color(hex: "7D9A52")
        case .gbc: return Color(hex: "7A4BC2")
        case .gba: return Color(hex: "6C5CE7")
        case .nds: return Color(hex: "1F2A44")
        }
    }

    var secondaryAccentColor: Color {
        switch self {
        case .gb: return Color(hex: "B7D6A4")
        case .gbc: return Color(hex: "B597F5")
        case .gba: return Color(hex: "A29BFE")
        case .nds: return Color(hex: "4A6FA5")
        }
    }

    var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [secondaryAccentColor.opacity(0.88), accentColor.opacity(0.78)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var shellThemeID: String? {
        switch self {
        case .gb: return "gb-classic-dmg"
        case .gbc: return "gbc-modern-minimal"
        case .gba: return "gba-modern-minimal"
        case .nds: return "nds-modern-minimal"
        }
    }

    static func resolve(systemRaw: String?, fileName: String? = nil, romPath: String? = nil) -> ConsoleIdentity? {
        let normalized = (systemRaw ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "gb", "gameboy", "game boy", "dmg":
            return .gb
        case "gbc", "cgb", "gameboycolor", "game boy color":
            return .gbc
        case "gba", "gameboyadvance", "game boy advance":
            return .gba
        case "nds", "ds", "nintendo ds":
            return .nds
        case "gb/gbc", "game boy + color", "game boy color + game boy", "gameboy+color":
            return inferHandheldIdentity(fileName: fileName, romPath: romPath) ?? .gb
        default:
            return inferHandheldIdentity(fileName: fileName, romPath: romPath)
        }
    }

    static func resolve(platform: EmulatorPlatform) -> ConsoleIdentity? {
        switch platform {
        case .gameBoy: return .gb
        case .gameBoyColor: return .gbc
        case .gameBoyAdvance: return .gba
        case .nintendoDS: return .nds
        default: return nil
        }
    }

    static func resolve(platform: Platform?) -> ConsoleIdentity? {
        switch platform {
        case .GB: return .gb
        case .GBC: return .gbc
        case .GBA: return .gba
        case .NDS: return .nds
        default: return nil
        }
    }

    private static func inferHandheldIdentity(fileName: String?, romPath: String?) -> ConsoleIdentity? {
        let candidates = [fileName, romPath]
        for candidate in candidates {
            guard let candidate else { continue }
            let ext = (candidate as NSString).pathExtension.lowercased()
            switch ext {
            case "gb": return .gb
            case "gbc", "cgb": return .gbc
            case "gba": return .gba
            case "nds": return .nds
            default: continue
            }
        }
        return nil
    }
}

extension ROMLibraryEntry {
    var consoleIdentity: ConsoleIdentity? {
        ConsoleIdentity.resolve(systemRaw: system, fileName: fileName)
    }

    var resolvedSystemCode: String {
        consoleIdentity?.rawValue ?? (system ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

extension Game {
    var consoleIdentity: ConsoleIdentity? {
        ConsoleIdentity.resolve(platform: emulatorPlatform)
            ?? ConsoleIdentity.resolve(systemRaw: platform, fileName: romPath, romPath: romPath)
    }
}
