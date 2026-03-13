import SwiftUI

enum ShellConsoleKind: String, Codable, CaseIterable {
    case gb
    case gbc
    case gba
    case nds

    init?(platform: Platform?) {
        switch platform {
        case .GB: self = .gb
        case .GBC: self = .gbc
        case .GBA: self = .gba
        case .NDS: self = .nds
        default: return nil
        }
    }
}

enum ShellMaterialType: String, Codable {
    case solid
    case glass
    case neon
}

enum ShellLandscapeBehavior: String, Codable {
    case adaptive
    case centeredScreen
    case hardwareLocked
}

enum ShellHapticProfile: String, Codable {
    case off
    case subtle
    case gamepad
}

struct ShellColorToken: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double
    var a: Double = 1.0

    var color: Color { Color(red: r, green: g, blue: b).opacity(a) }

    static let clear = ShellColorToken(r: 0, g: 0, b: 0, a: 0)
    static let white = ShellColorToken(r: 1, g: 1, b: 1, a: 1)
    static let black = ShellColorToken(r: 0, g: 0, b: 0, a: 1)
}

struct ShellGradientStopToken: Codable, Hashable {
    var color: ShellColorToken
    var location: Double
}

struct ShellLinearGradientToken: Codable, Hashable {
    var colors: [ShellColorToken]

    func gradient(startPoint: UnitPoint = .topLeading, endPoint: UnitPoint = .bottomTrailing) -> LinearGradient {
        LinearGradient(colors: colors.map(\.color), startPoint: startPoint, endPoint: endPoint)
    }
}

struct ShellColorPalette: Codable, Hashable {
    var shellBaseTop: ShellColorToken
    var shellBaseBottom: ShellColorToken
    var shellAccent: ShellColorToken
    var shellAccentSecondary: ShellColorToken
    var shellStroke: ShellColorToken
    var shellHighlight: ShellColorToken
    var shellShadow: ShellColorToken

    var screenFrameTop: ShellColorToken
    var screenFrameBottom: ShellColorToken
    var screenStroke: ShellColorToken
    var screenInnerStroke: ShellColorToken

    var controlSurfaceTop: ShellColorToken
    var controlSurfaceBottom: ShellColorToken
    var controlStroke: ShellColorToken
    var controlIcon: ShellColorToken

    var faceButtonAStart: ShellColorToken
    var faceButtonAEnd: ShellColorToken
    var faceButtonBStart: ShellColorToken
    var faceButtonBEnd: ShellColorToken
    var faceButtonText: ShellColorToken
    var faceButtonGlow: ShellColorToken

    var utilityFillStart: ShellColorToken
    var utilityFillEnd: ShellColorToken
    var utilityStroke: ShellColorToken
    var utilityIcon: ShellColorToken
    var utilityGlow: ShellColorToken

    var systemButtonFill: ShellColorToken
    var systemButtonStroke: ShellColorToken
    var systemButtonText: ShellColorToken
    var systemButtonKnobFill: ShellColorToken
    var systemButtonKnobStroke: ShellColorToken
    var systemButtonGlowStart: ShellColorToken
    var systemButtonGlowEnd: ShellColorToken

    var ndsTouchHighlight: ShellColorToken
    var ndsTouchGlow: ShellColorToken
    var ndsRailFillTop: ShellColorToken
    var ndsRailFillBottom: ShellColorToken
    var ndsRailStroke: ShellColorToken
}

struct ShellScreenStyle: Codable, Hashable {
    var cornerRadius: Double
    var bezelCornerRadius: Double
    var bezelThickness: Double
    var shadowRadius: Double
    var shadowYOffset: Double
    var borderOpacity: Double
    var floatingDisplay: Bool
}

struct ShellControlStyle: Codable, Hashable {
    var materialType: ShellMaterialType
    var glowEnabled: Bool
    var idleOpacity: Double
    var pressScale: Double
    var dpadBasePlateOpacity: Double
    var shoulderRecessOpacity: Double
    var utilityButtonSize: Double
    var systemButtonHeight: Double
    var badgeOpacity: Double
}

struct ShellLayoutStyle: Codable, Hashable {
    var controlSpacing: Double
    var screenSpacing: Double
    var immersiveEnabled: Bool
    var landscapeBehavior: ShellLandscapeBehavior
    var portraitControlYOffset: Double
    var portraitSystemRowYOffset: Double
    var ndsPortraitControlGapReduction: Double
    var ndsLandscapeSideColumnScale: Double
}

struct ShellAnimationStyle: Codable, Hashable {
    var tapDuration: Double
    var useSpring: Bool
    var glowPulseEnabled: Bool
    var hapticProfile: ShellHapticProfile
}

struct ShellThemeConsoleOverrides: Codable, Hashable {
    var utilityButtonSize: Double?
    var dpadScaleMultiplier: Double?
    var faceButtonScaleMultiplier: Double?
    var touchScreenHighlightOpacity: Double?
}

struct EmulatorShellTheme: Codable, Hashable, Identifiable {
    var id: String
    var displayName: String
    var supportedConsoles: [ShellConsoleKind]

    var colorPalette: ShellColorPalette
    var screenStyle: ShellScreenStyle
    var controlStyle: ShellControlStyle
    var layoutStyle: ShellLayoutStyle
    var animationStyle: ShellAnimationStyle
    var consoleOverrides: [ShellConsoleKind: ShellThemeConsoleOverrides]

    func override(for console: ShellConsoleKind?) -> ShellThemeConsoleOverrides {
        guard let console else { return ShellThemeConsoleOverrides() }
        return consoleOverrides[console] ?? ShellThemeConsoleOverrides()
    }
}

struct EmulatorThemePackageManifest: Codable, Hashable {
    var version: Int
    var theme: EmulatorShellTheme
    var assetDirectory: String?
}

@MainActor
final class ShellThemeManager: ObservableObject {
    static let shared = ShellThemeManager()

    private static let selectedThemeKey = "shellTheme.selectedThemeID"
    private static let perConsoleSelectedThemeKey = "shellTheme.perConsoleSelectedThemeIDs"

    @Published private(set) var builtInThemes: [EmulatorShellTheme]
    @Published private(set) var downloadableThemes: [EmulatorShellTheme] = []
    @Published var perConsoleSelectedThemeIDs: [ShellConsoleKind: String] {
        didSet { persistPerConsoleSelections() }
    }
    @Published var selectedThemeID: String {
        didSet {
            UserDefaults.standard.set(selectedThemeID, forKey: Self.selectedThemeKey)
        }
    }

    private init() {
        self.builtInThemes = Self.defaultThemes()
        if let data = UserDefaults.standard.data(forKey: Self.perConsoleSelectedThemeKey),
           let decoded = try? JSONDecoder().decode([ShellConsoleKind: String].self, from: data) {
            self.perConsoleSelectedThemeIDs = decoded
        } else {
            self.perConsoleSelectedThemeIDs = [.gb: "gb-classic-dmg", .gbc: "gbc-modern-minimal"]
        }
        let stored = UserDefaults.standard.string(forKey: Self.selectedThemeKey)
        self.selectedThemeID = stored ?? Self.defaultThemes().first?.id ?? "classic-neon"
    }

    var availableThemes: [EmulatorShellTheme] {
        builtInThemes + downloadableThemes
    }

    var activeTheme: EmulatorShellTheme {
        availableThemes.first(where: { $0.id == selectedThemeID }) ?? builtInThemes[0]
    }

    func theme(for platform: Platform?) -> EmulatorShellTheme {
        guard let console = ShellConsoleKind(platform: platform) else { return activeTheme }
        if let selectedID = perConsoleSelectedThemeIDs[console],
           let match = availableThemes.first(where: { $0.id == selectedID && $0.supportedConsoles.contains(console) }) {
            return match
        }
        if activeTheme.supportedConsoles.contains(console) {
            return activeTheme
        }
        return builtInThemes.first(where: { $0.supportedConsoles.contains(console) }) ?? activeTheme
    }

    func setTheme(id: String) {
        guard availableThemes.contains(where: { $0.id == id }) else { return }
        selectedThemeID = id
    }

    func setTheme(id: String, for console: ShellConsoleKind?) {
        guard let console else {
            setTheme(id: id)
            return
        }
        guard availableThemes.contains(where: { $0.id == id && $0.supportedConsoles.contains(console) }) else { return }
        perConsoleSelectedThemeIDs[console] = id
    }

    func clearConsoleThemeOverride(_ console: ShellConsoleKind) {
        perConsoleSelectedThemeIDs.removeValue(forKey: console)
    }

    func resetBuiltInTheme() {
        selectedThemeID = builtInThemes[0].id
    }

    func loadThemePackage(from url: URL) throws {
        let data = try Data(contentsOf: url)
        let package = try JSONDecoder().decode(EmulatorThemePackageManifest.self, from: data)
        guard package.version == 1 else { return }
        if let index = downloadableThemes.firstIndex(where: { $0.id == package.theme.id }) {
            downloadableThemes[index] = package.theme
        } else {
            downloadableThemes.append(package.theme)
        }
    }

    private static func defaultThemes() -> [EmulatorShellTheme] {
        [classicNeonTheme, gbClassicDMGTheme, gbcModernMinimalTheme, gbaModernMinimalTheme, ndsModernMinimalTheme, minimalGlassTheme, retroMonoTheme]
    }

    private func persistPerConsoleSelections() {
        if let data = try? JSONEncoder().encode(perConsoleSelectedThemeIDs) {
            UserDefaults.standard.set(data, forKey: Self.perConsoleSelectedThemeKey)
        }
    }
}

private extension ShellThemeManager {
    nonisolated static var classicNeonTheme: EmulatorShellTheme {
        EmulatorShellTheme(
            id: "classic-neon",
            displayName: "Classic Neon",
            supportedConsoles: ShellConsoleKind.allCases,
            colorPalette: .init(
                shellBaseTop: .init(r: 0.31, g: 0.20, b: 0.42, a: 0.85),
                shellBaseBottom: .init(r: 0.17, g: 0.17, b: 0.27, a: 0.92),
                shellAccent: .init(r: 0.66, g: 0.33, b: 0.97, a: 1),
                shellAccentSecondary: .init(r: 1.00, g: 0.31, b: 0.85, a: 1),
                shellStroke: .init(r: 1, g: 1, b: 1, a: 0.14),
                shellHighlight: .init(r: 1, g: 1, b: 1, a: 0.06),
                shellShadow: .init(r: 0.38, g: 0.20, b: 0.70, a: 0.24),
                screenFrameTop: .init(r: 0.07, g: 0.09, b: 0.14, a: 1),
                screenFrameBottom: .init(r: 0.05, g: 0.08, b: 0.18, a: 1),
                screenStroke: .init(r: 1, g: 1, b: 1, a: 0.08),
                screenInnerStroke: .init(r: 0.66, g: 0.33, b: 0.97, a: 0.15),
                controlSurfaceTop: .init(r: 1, g: 1, b: 1, a: 0.86),
                controlSurfaceBottom: .init(r: 0.77, g: 0.75, b: 0.87, a: 0.94),
                controlStroke: .init(r: 0, g: 0, b: 0, a: 0.42),
                controlIcon: .init(r: 0, g: 0, b: 0, a: 0.24),
                faceButtonAStart: .init(r: 1.00, g: 0.31, b: 0.85, a: 0.92),
                faceButtonAEnd: .init(r: 0.66, g: 0.33, b: 0.97, a: 0.95),
                faceButtonBStart: .init(r: 0.92, g: 0.34, b: 0.90, a: 0.90),
                faceButtonBEnd: .init(r: 0.60, g: 0.32, b: 0.95, a: 0.95),
                faceButtonText: .init(r: 1, g: 1, b: 1, a: 0.92),
                faceButtonGlow: .init(r: 0.78, g: 0.24, b: 0.95, a: 0.28),
                utilityFillStart: .init(r: 0.92, g: 0.31, b: 0.86, a: 0.86),
                utilityFillEnd: .init(r: 0.54, g: 0.24, b: 0.94, a: 0.92),
                utilityStroke: .init(r: 1, g: 1, b: 1, a: 0.22),
                utilityIcon: .init(r: 1, g: 1, b: 1, a: 0.92),
                utilityGlow: .init(r: 0.56, g: 0.26, b: 0.98, a: 0.30),
                systemButtonFill: .init(r: 1, g: 1, b: 1, a: 0.10),
                systemButtonStroke: .init(r: 1, g: 1, b: 1, a: 0.20),
                systemButtonText: .init(r: 1, g: 1, b: 1, a: 0.72),
                systemButtonKnobFill: .init(r: 1, g: 1, b: 1, a: 0.95),
                systemButtonKnobStroke: .init(r: 0, g: 0, b: 0, a: 0.35),
                systemButtonGlowStart: .init(r: 1.00, g: 0.31, b: 0.85, a: 0.55),
                systemButtonGlowEnd: .init(r: 0.66, g: 0.33, b: 0.97, a: 0.50),
                ndsTouchHighlight: .init(r: 0.66, g: 0.33, b: 0.97, a: 0.32),
                ndsTouchGlow: .init(r: 0.66, g: 0.33, b: 0.97, a: 0.18),
                ndsRailFillTop: .init(r: 1, g: 1, b: 1, a: 0.95),
                ndsRailFillBottom: .init(r: 0.88, g: 0.88, b: 0.88, a: 0.96),
                ndsRailStroke: .init(r: 0, g: 0, b: 0, a: 0.35)
            ),
            screenStyle: .init(cornerRadius: 22, bezelCornerRadius: 12, bezelThickness: 3, shadowRadius: 20, shadowYOffset: 10, borderOpacity: 0.10, floatingDisplay: false),
            controlStyle: .init(materialType: .neon, glowEnabled: true, idleOpacity: 1.0, pressScale: 0.97, dpadBasePlateOpacity: 0.14, shoulderRecessOpacity: 0.14, utilityButtonSize: 32, systemButtonHeight: 30, badgeOpacity: 1.0),
            layoutStyle: .init(controlSpacing: 10, screenSpacing: 10, immersiveEnabled: false, landscapeBehavior: .centeredScreen, portraitControlYOffset: -28, portraitSystemRowYOffset: -22, ndsPortraitControlGapReduction: 16, ndsLandscapeSideColumnScale: 1.0),
            animationStyle: .init(tapDuration: 0.14, useSpring: false, glowPulseEnabled: false, hapticProfile: .subtle),
            consoleOverrides: [
                .gbc: .init(dpadScaleMultiplier: 0.95, faceButtonScaleMultiplier: 0.95),
                .nds: .init(touchScreenHighlightOpacity: 0.42)
            ]
        )
    }

    nonisolated static var minimalGlassTheme: EmulatorShellTheme {
        var theme = classicNeonTheme
        theme.id = "minimal-glass"
        theme.displayName = "Minimal Glass"
        theme.colorPalette.shellBaseTop = .init(r: 1, g: 1, b: 1, a: 0.10)
        theme.colorPalette.shellBaseBottom = .init(r: 1, g: 1, b: 1, a: 0.05)
        theme.colorPalette.shellStroke = .init(r: 1, g: 1, b: 1, a: 0.22)
        theme.colorPalette.faceButtonGlow = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.12)
        theme.colorPalette.utilityGlow = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.14)
        theme.controlStyle.materialType = .glass
        theme.controlStyle.glowEnabled = false
        theme.controlStyle.dpadBasePlateOpacity = 0.08
        theme.animationStyle.tapDuration = 0.10
        return theme
    }

    nonisolated static var gbcModernMinimalTheme: EmulatorShellTheme {
        var theme = classicNeonTheme
        theme.id = "gbc-modern-minimal"
        theme.displayName = "GBC Modern Minimal"
        theme.supportedConsoles = [.gbc]
        theme.colorPalette.shellBaseTop = .init(r: 0.95, g: 0.96, b: 0.98, a: 0.10)
        theme.colorPalette.shellBaseBottom = .init(r: 0.92, g: 0.93, b: 0.97, a: 0.06)
        theme.colorPalette.shellAccent = .init(r: 0.66, g: 0.33, b: 0.97, a: 1)
        theme.colorPalette.shellAccentSecondary = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.85)
        theme.colorPalette.shellStroke = .init(r: 1, g: 1, b: 1, a: 0.16)
        theme.colorPalette.shellHighlight = .init(r: 1, g: 1, b: 1, a: 0.12)
        theme.colorPalette.shellShadow = .init(r: 0.03, g: 0.05, b: 0.09, a: 0.20)

        theme.colorPalette.screenFrameTop = .init(r: 0.02, g: 0.03, b: 0.05, a: 0.98)
        theme.colorPalette.screenFrameBottom = .init(r: 0.01, g: 0.02, b: 0.04, a: 0.98)
        theme.colorPalette.screenStroke = .init(r: 1, g: 1, b: 1, a: 0.06)
        theme.colorPalette.screenInnerStroke = .init(r: 1, g: 1, b: 1, a: 0.05)

        theme.colorPalette.controlSurfaceTop = .init(r: 1, g: 1, b: 1, a: 0.24)
        theme.colorPalette.controlSurfaceBottom = .init(r: 1, g: 1, b: 1, a: 0.14)
        theme.colorPalette.controlStroke = .init(r: 1, g: 1, b: 1, a: 0.18)
        theme.colorPalette.controlIcon = .init(r: 0.12, g: 0.13, b: 0.18, a: 0.55)

        theme.colorPalette.faceButtonAStart = .init(r: 1, g: 1, b: 1, a: 0.22)
        theme.colorPalette.faceButtonAEnd = .init(r: 1, g: 1, b: 1, a: 0.14)
        theme.colorPalette.faceButtonBStart = .init(r: 1, g: 1, b: 1, a: 0.22)
        theme.colorPalette.faceButtonBEnd = .init(r: 1, g: 1, b: 1, a: 0.14)
        theme.colorPalette.faceButtonText = .init(r: 1, g: 1, b: 1, a: 0.92)
        theme.colorPalette.faceButtonGlow = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.12)

        theme.colorPalette.utilityFillStart = .init(r: 1, g: 1, b: 1, a: 0.15)
        theme.colorPalette.utilityFillEnd = .init(r: 1, g: 1, b: 1, a: 0.08)
        theme.colorPalette.utilityStroke = .init(r: 1, g: 1, b: 1, a: 0.20)
        theme.colorPalette.utilityIcon = .init(r: 1, g: 1, b: 1, a: 0.86)
        theme.colorPalette.utilityGlow = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.10)

        theme.colorPalette.systemButtonFill = .init(r: 1, g: 1, b: 1, a: 0.12)
        theme.colorPalette.systemButtonStroke = .init(r: 1, g: 1, b: 1, a: 0.20)
        theme.colorPalette.systemButtonText = .init(r: 1, g: 1, b: 1, a: 0.72)
        theme.colorPalette.systemButtonKnobFill = .init(r: 1, g: 1, b: 1, a: 0.88)
        theme.colorPalette.systemButtonKnobStroke = .init(r: 1, g: 1, b: 1, a: 0.18)
        theme.colorPalette.systemButtonGlowStart = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.18)
        theme.colorPalette.systemButtonGlowEnd = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.10)

        theme.controlStyle.materialType = .glass
        theme.controlStyle.glowEnabled = false
        theme.controlStyle.idleOpacity = 0.65
        theme.controlStyle.pressScale = 0.92
        theme.controlStyle.dpadBasePlateOpacity = 0.08
        theme.controlStyle.shoulderRecessOpacity = 0.06
        theme.controlStyle.utilityButtonSize = 34
        theme.controlStyle.systemButtonHeight = 34

        theme.screenStyle.cornerRadius = 24
        theme.screenStyle.bezelCornerRadius = 24
        theme.screenStyle.bezelThickness = 1
        theme.screenStyle.shadowRadius = 20
        theme.screenStyle.shadowYOffset = 10
        theme.screenStyle.floatingDisplay = true

        theme.layoutStyle.portraitControlYOffset = -14
        theme.layoutStyle.portraitSystemRowYOffset = -10
        theme.animationStyle.tapDuration = 0.12
        theme.animationStyle.hapticProfile = .subtle

        theme.consoleOverrides[.gbc] = .init(utilityButtonSize: 34, dpadScaleMultiplier: 0.90, faceButtonScaleMultiplier: 0.90)
        return theme
    }

    nonisolated static var gbClassicDMGTheme: EmulatorShellTheme {
        var theme = classicNeonTheme
        theme.id = "gb-classic-dmg"
        theme.displayName = "GB Classic DMG"
        theme.supportedConsoles = [.gb]
        theme.colorPalette.shellBaseTop = .init(r: 0.79, g: 0.81, b: 0.77, a: 0.98)
        theme.colorPalette.shellBaseBottom = .init(r: 0.67, g: 0.70, b: 0.64, a: 0.98)
        theme.colorPalette.shellAccent = .init(r: 0.49, g: 0.61, b: 0.32, a: 1)
        theme.colorPalette.shellAccentSecondary = .init(r: 0.71, g: 0.84, b: 0.54, a: 1)
        theme.colorPalette.shellStroke = .init(r: 0.25, g: 0.29, b: 0.24, a: 0.28)
        theme.colorPalette.shellHighlight = .init(r: 1, g: 1, b: 1, a: 0.16)
        theme.colorPalette.shellShadow = .init(r: 0.08, g: 0.11, b: 0.07, a: 0.16)

        theme.colorPalette.screenFrameTop = .init(r: 0.29, g: 0.33, b: 0.26, a: 1)
        theme.colorPalette.screenFrameBottom = .init(r: 0.17, g: 0.20, b: 0.15, a: 1)
        theme.colorPalette.screenStroke = .init(r: 0.73, g: 0.84, b: 0.57, a: 0.20)
        theme.colorPalette.screenInnerStroke = .init(r: 0.63, g: 0.74, b: 0.48, a: 0.18)

        theme.colorPalette.controlSurfaceTop = .init(r: 0.44, g: 0.46, b: 0.42, a: 0.98)
        theme.colorPalette.controlSurfaceBottom = .init(r: 0.30, g: 0.31, b: 0.29, a: 0.98)
        theme.colorPalette.controlStroke = .init(r: 0.08, g: 0.08, b: 0.08, a: 0.68)
        theme.colorPalette.controlIcon = .init(r: 0.95, g: 0.97, b: 0.90, a: 0.94)

        theme.colorPalette.faceButtonAStart = .init(r: 0.43, g: 0.43, b: 0.48, a: 0.98)
        theme.colorPalette.faceButtonAEnd = .init(r: 0.25, g: 0.25, b: 0.29, a: 0.98)
        theme.colorPalette.faceButtonBStart = .init(r: 0.43, g: 0.43, b: 0.48, a: 0.98)
        theme.colorPalette.faceButtonBEnd = .init(r: 0.25, g: 0.25, b: 0.29, a: 0.98)
        theme.colorPalette.faceButtonGlow = .init(r: 0.51, g: 0.66, b: 0.33, a: 0.14)

        theme.colorPalette.utilityFillStart = .init(r: 0.59, g: 0.61, b: 0.58, a: 0.94)
        theme.colorPalette.utilityFillEnd = .init(r: 0.42, g: 0.44, b: 0.40, a: 0.98)
        theme.colorPalette.utilityStroke = .init(r: 0.14, g: 0.15, b: 0.12, a: 0.58)
        theme.colorPalette.utilityIcon = .init(r: 0.93, g: 0.95, b: 0.88, a: 0.92)
        theme.colorPalette.utilityGlow = .init(r: 0.51, g: 0.66, b: 0.33, a: 0.10)

        theme.controlStyle.materialType = .solid
        theme.controlStyle.glowEnabled = false
        theme.controlStyle.idleOpacity = 0.95
        theme.controlStyle.pressScale = 0.95
        theme.layoutStyle.landscapeBehavior = .hardwareLocked
        theme.consoleOverrides[.gb] = .init(dpadScaleMultiplier: 0.96, faceButtonScaleMultiplier: 0.92)
        return theme
    }

    nonisolated static var gbaModernMinimalTheme: EmulatorShellTheme {
        var theme = classicNeonTheme
        theme.id = "gba-modern-minimal"
        theme.displayName = "GBA Modern Minimal"
        theme.supportedConsoles = [.gba]

        theme.colorPalette.shellBaseTop = .init(r: 0.96, g: 0.97, b: 0.99, a: 0.06)
        theme.colorPalette.shellBaseBottom = .init(r: 0.92, g: 0.94, b: 0.98, a: 0.04)
        theme.colorPalette.shellStroke = .init(r: 1, g: 1, b: 1, a: 0.12)
        theme.colorPalette.shellHighlight = .init(r: 1, g: 1, b: 1, a: 0.08)
        theme.colorPalette.shellShadow = .init(r: 0.02, g: 0.03, b: 0.06, a: 0.18)

        theme.colorPalette.screenFrameTop = .init(r: 0.02, g: 0.03, b: 0.05, a: 0.98)
        theme.colorPalette.screenFrameBottom = .init(r: 0.01, g: 0.02, b: 0.04, a: 0.98)
        theme.colorPalette.screenStroke = .init(r: 1, g: 1, b: 1, a: 0.05)
        theme.colorPalette.screenInnerStroke = .init(r: 1, g: 1, b: 1, a: 0.04)

        theme.colorPalette.controlSurfaceTop = .init(r: 1, g: 1, b: 1, a: 0.24)
        theme.colorPalette.controlSurfaceBottom = .init(r: 1, g: 1, b: 1, a: 0.14)
        theme.colorPalette.controlStroke = .init(r: 1, g: 1, b: 1, a: 0.18)
        theme.colorPalette.controlIcon = .init(r: 0.10, g: 0.12, b: 0.18, a: 0.56)

        theme.colorPalette.faceButtonAStart = .init(r: 1, g: 1, b: 1, a: 0.22)
        theme.colorPalette.faceButtonAEnd = .init(r: 1, g: 1, b: 1, a: 0.13)
        theme.colorPalette.faceButtonBStart = theme.colorPalette.faceButtonAStart
        theme.colorPalette.faceButtonBEnd = theme.colorPalette.faceButtonAEnd
        theme.colorPalette.faceButtonText = .init(r: 1, g: 1, b: 1, a: 0.90)
        theme.colorPalette.faceButtonGlow = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.08)

        theme.colorPalette.utilityFillStart = .init(r: 1, g: 1, b: 1, a: 0.14)
        theme.colorPalette.utilityFillEnd = .init(r: 1, g: 1, b: 1, a: 0.08)
        theme.colorPalette.utilityStroke = .init(r: 1, g: 1, b: 1, a: 0.16)
        theme.colorPalette.utilityIcon = .init(r: 1, g: 1, b: 1, a: 0.88)
        theme.colorPalette.utilityGlow = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.08)

        theme.colorPalette.systemButtonFill = .init(r: 1, g: 1, b: 1, a: 0.10)
        theme.colorPalette.systemButtonStroke = .init(r: 1, g: 1, b: 1, a: 0.16)
        theme.colorPalette.systemButtonText = .init(r: 1, g: 1, b: 1, a: 0.74)
        theme.colorPalette.systemButtonKnobFill = .init(r: 1, g: 1, b: 1, a: 0.88)
        theme.colorPalette.systemButtonKnobStroke = .init(r: 1, g: 1, b: 1, a: 0.14)
        theme.colorPalette.systemButtonGlowStart = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.14)
        theme.colorPalette.systemButtonGlowEnd = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.08)

        theme.screenStyle.cornerRadius = 22
        theme.screenStyle.bezelCornerRadius = 22
        theme.screenStyle.bezelThickness = 1
        theme.screenStyle.shadowRadius = 20
        theme.screenStyle.shadowYOffset = 10
        theme.screenStyle.borderOpacity = 0.06
        theme.screenStyle.floatingDisplay = true

        theme.controlStyle.materialType = .glass
        theme.controlStyle.glowEnabled = false
        theme.controlStyle.idleOpacity = 0.48
        theme.controlStyle.pressScale = 0.92
        theme.controlStyle.dpadBasePlateOpacity = 0.08
        theme.controlStyle.shoulderRecessOpacity = 0.06
        theme.controlStyle.utilityButtonSize = 32
        theme.controlStyle.systemButtonHeight = 30

        theme.layoutStyle.screenSpacing = 16
        theme.layoutStyle.portraitControlYOffset = -10
        theme.layoutStyle.portraitSystemRowYOffset = -10
        theme.layoutStyle.landscapeBehavior = .centeredScreen

        theme.animationStyle.tapDuration = 0.12
        theme.animationStyle.useSpring = true
        theme.animationStyle.hapticProfile = .subtle

        theme.consoleOverrides[.gba] = .init(utilityButtonSize: 32, dpadScaleMultiplier: 0.82, faceButtonScaleMultiplier: 0.82)
        return theme
    }

    nonisolated static var ndsModernMinimalTheme: EmulatorShellTheme {
        var theme = classicNeonTheme
        theme.id = "nds-modern-minimal"
        theme.displayName = "NDS Modern Minimal"
        theme.supportedConsoles = [.nds]

        theme.colorPalette.shellBaseTop = .init(r: 0.96, g: 0.97, b: 0.99, a: 0.08)
        theme.colorPalette.shellBaseBottom = .init(r: 0.93, g: 0.94, b: 0.98, a: 0.05)
        theme.colorPalette.shellStroke = .init(r: 1, g: 1, b: 1, a: 0.12)
        theme.colorPalette.shellHighlight = .init(r: 1, g: 1, b: 1, a: 0.10)
        theme.colorPalette.shellShadow = .init(r: 0.02, g: 0.03, b: 0.06, a: 0.22)

        theme.colorPalette.screenFrameTop = .init(r: 0.01, g: 0.02, b: 0.04, a: 0.98)
        theme.colorPalette.screenFrameBottom = .init(r: 0.01, g: 0.02, b: 0.04, a: 0.98)
        theme.colorPalette.screenStroke = .init(r: 1, g: 1, b: 1, a: 0.06)
        theme.colorPalette.screenInnerStroke = .init(r: 1, g: 1, b: 1, a: 0.04)

        theme.colorPalette.controlSurfaceTop = .init(r: 1, g: 1, b: 1, a: 0.23)
        theme.colorPalette.controlSurfaceBottom = .init(r: 1, g: 1, b: 1, a: 0.13)
        theme.colorPalette.controlStroke = .init(r: 1, g: 1, b: 1, a: 0.18)
        theme.colorPalette.controlIcon = .init(r: 0.10, g: 0.12, b: 0.18, a: 0.58)

        theme.colorPalette.faceButtonAStart = .init(r: 1, g: 1, b: 1, a: 0.22)
        theme.colorPalette.faceButtonAEnd = .init(r: 1, g: 1, b: 1, a: 0.13)
        theme.colorPalette.faceButtonBStart = theme.colorPalette.faceButtonAStart
        theme.colorPalette.faceButtonBEnd = theme.colorPalette.faceButtonAEnd
        theme.colorPalette.faceButtonText = .init(r: 1, g: 1, b: 1, a: 0.90)
        theme.colorPalette.faceButtonGlow = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.08)

        theme.colorPalette.utilityFillStart = .init(r: 1, g: 1, b: 1, a: 0.14)
        theme.colorPalette.utilityFillEnd = .init(r: 1, g: 1, b: 1, a: 0.08)
        theme.colorPalette.utilityStroke = .init(r: 1, g: 1, b: 1, a: 0.18)
        theme.colorPalette.utilityIcon = .init(r: 1, g: 1, b: 1, a: 0.88)
        theme.colorPalette.utilityGlow = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.10)

        theme.colorPalette.systemButtonFill = .init(r: 1, g: 1, b: 1, a: 0.12)
        theme.colorPalette.systemButtonStroke = .init(r: 1, g: 1, b: 1, a: 0.18)
        theme.colorPalette.systemButtonText = .init(r: 1, g: 1, b: 1, a: 0.76)
        theme.colorPalette.systemButtonKnobFill = .init(r: 1, g: 1, b: 1, a: 0.90)
        theme.colorPalette.systemButtonKnobStroke = .init(r: 1, g: 1, b: 1, a: 0.15)
        theme.colorPalette.systemButtonGlowStart = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.16)
        theme.colorPalette.systemButtonGlowEnd = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.08)

        theme.colorPalette.ndsTouchHighlight = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.18)
        theme.colorPalette.ndsTouchGlow = .init(r: 0.66, g: 0.33, b: 0.97, a: 0.08)
        theme.colorPalette.ndsRailFillTop = .init(r: 1, g: 1, b: 1, a: 0.16)
        theme.colorPalette.ndsRailFillBottom = .init(r: 1, g: 1, b: 1, a: 0.10)
        theme.colorPalette.ndsRailStroke = .init(r: 1, g: 1, b: 1, a: 0.16)

        theme.screenStyle.cornerRadius = 22
        theme.screenStyle.bezelCornerRadius = 20
        theme.screenStyle.bezelThickness = 1
        theme.screenStyle.shadowRadius = 18
        theme.screenStyle.shadowYOffset = 8
        theme.screenStyle.borderOpacity = 0.06
        theme.screenStyle.floatingDisplay = true

        theme.controlStyle.materialType = .glass
        theme.controlStyle.glowEnabled = false
        theme.controlStyle.idleOpacity = 0.55
        theme.controlStyle.pressScale = 0.90
        theme.controlStyle.dpadBasePlateOpacity = 0.06
        theme.controlStyle.shoulderRecessOpacity = 0.05
        theme.controlStyle.utilityButtonSize = 32
        theme.controlStyle.systemButtonHeight = 32

        theme.layoutStyle.screenSpacing = 20
        theme.layoutStyle.portraitControlYOffset = -8
        theme.layoutStyle.portraitSystemRowYOffset = -8
        theme.layoutStyle.ndsPortraitControlGapReduction = 8
        theme.layoutStyle.ndsLandscapeSideColumnScale = 0.82

        theme.animationStyle.tapDuration = 0.12
        theme.animationStyle.useSpring = true
        theme.animationStyle.hapticProfile = .subtle

        theme.consoleOverrides[.nds] = .init(
            utilityButtonSize: 32,
            dpadScaleMultiplier: 0.78,
            faceButtonScaleMultiplier: 0.78,
            touchScreenHighlightOpacity: 0.24
        )
        return theme
    }

    nonisolated static var retroMonoTheme: EmulatorShellTheme {
        var theme = classicNeonTheme
        theme.id = "retro-classic"
        theme.displayName = "Retro Classic"
        theme.colorPalette.shellAccent = .init(r: 0.80, g: 0.76, b: 0.66, a: 1)
        theme.colorPalette.shellAccentSecondary = .init(r: 0.65, g: 0.60, b: 0.52, a: 1)
        theme.colorPalette.faceButtonAStart = .init(r: 0.90, g: 0.90, b: 0.90, a: 0.95)
        theme.colorPalette.faceButtonAEnd = .init(r: 0.78, g: 0.78, b: 0.78, a: 0.95)
        theme.colorPalette.faceButtonBStart = theme.colorPalette.faceButtonAStart
        theme.colorPalette.faceButtonBEnd = theme.colorPalette.faceButtonAEnd
        theme.colorPalette.faceButtonText = .init(r: 0.1, g: 0.1, b: 0.1, a: 0.75)
        theme.colorPalette.faceButtonGlow = .init(r: 0, g: 0, b: 0, a: 0.10)
        theme.colorPalette.utilityFillStart = .init(r: 0.25, g: 0.25, b: 0.25, a: 0.90)
        theme.colorPalette.utilityFillEnd = .init(r: 0.15, g: 0.15, b: 0.15, a: 0.92)
        theme.colorPalette.utilityGlow = .init(r: 0, g: 0, b: 0, a: 0.10)
        theme.controlStyle.glowEnabled = false
        theme.controlStyle.materialType = .solid
        theme.animationStyle.hapticProfile = .off
        return theme
    }
}

private struct EmulatorShellThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: EmulatorShellTheme = ShellThemeManager.classicNeonTheme
}

extension EnvironmentValues {
    var emulatorShellTheme: EmulatorShellTheme {
        get { self[EmulatorShellThemeEnvironmentKey.self] }
        set { self[EmulatorShellThemeEnvironmentKey.self] = newValue }
    }
}
