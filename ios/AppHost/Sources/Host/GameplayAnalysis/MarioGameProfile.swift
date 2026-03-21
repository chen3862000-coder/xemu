import Foundation
import CoreGraphics

struct MarioGameProfile: Sendable {
    let id: String
    let displayName: String
    let titleMatchers: [String]
    let nativeResolution: CGSize
    let gameplayRegion: CGRect
    let initialSearchRegion: CGRect
    let minSampleInterval: TimeInterval
    let damageCooldown: TimeInterval
    let deathCooldown: TimeInterval
    let fadeConfirmationThreshold: Double
    let blackoutThreshold: Double
    let smallHeightRange: ClosedRange<CGFloat>
    let superHeightRange: ClosedRange<CGFloat>
    let poweredUpHeightRange: ClosedRange<CGFloat>

    func matches(title: String, platform: Platform, romHash: String) -> Bool {
        let normalizedTitle = title.normalizedMarioProfileKey
        let normalizedHash = romHash.normalizedMarioProfileKey
        print("🔍 Profile matching - title: '\(title)' -> normalized: '\(normalizedTitle)', hash: '\(romHash)' -> normalized: '\(normalizedHash)'")
        for matcher in titleMatchers {
            let candidate = matcher.normalizedMarioProfileKey
            let titleMatch = normalizedTitle.contains(candidate)
            let hashMatch = !normalizedHash.isEmpty && normalizedHash.contains(candidate)
            print("🔍   matcher: '\(matcher)' -> '\(candidate)', titleMatch: \(titleMatch), hashMatch: \(hashMatch)")
            if titleMatch || hashMatch {
                return true
            }
        }
        return false
    }

    static func activeProfile(
        title: String,
        platform: Platform,
        romHash: String
    ) -> MarioGameProfile? {
        allProfiles.first { $0.matches(title: title, platform: platform, romHash: romHash) }
    }

    static let superMarioLand = MarioGameProfile(
        id: "sml_gb",
        displayName: "Super Mario Land",
        titleMatchers: [
            "super mario land",
            "sml",
            "super mario"
        ],
        nativeResolution: CGSize(width: 160, height: 144),
        gameplayRegion: CGRect(x: 0.0, y: 0.15, width: 1.0, height: 0.70),
        initialSearchRegion: CGRect(x: 0.1, y: 0.25, width: 0.8, height: 0.55),
        minSampleInterval: 10.0,  // Effectively disable analysis for GBC to restore performance
        damageCooldown: 2.0,
        deathCooldown: 2.5,
        fadeConfirmationThreshold: 0.35,
        blackoutThreshold: 0.08,
        smallHeightRange: 8...14,
        superHeightRange: 15...22,
        poweredUpHeightRange: 20...32
    )

    static let superMarioLand2 = MarioGameProfile(
        id: "sml2_gb",
        displayName: "Super Mario Land 2: 6 Golden Coins",
        titleMatchers: [
            "super mario land 2",
            "sml2",
            "6 golden coins",
            "wario"
        ],
        nativeResolution: CGSize(width: 160, height: 144),
        gameplayRegion: CGRect(x: 0.0, y: 0.15, width: 1.0, height: 0.70),
        initialSearchRegion: CGRect(x: 0.1, y: 0.25, width: 0.8, height: 0.55),
        minSampleInterval: 10.0,  // Effectively disable analysis for GBC to restore performance
        damageCooldown: 2.0,
        deathCooldown: 2.5,
        fadeConfirmationThreshold: 0.35,
        blackoutThreshold: 0.08,
        smallHeightRange: 8...14,
        superHeightRange: 15...22,
        poweredUpHeightRange: 20...32
    )

    static let superMarioBrosDeluxe = MarioGameProfile(
        id: "smbd_gbc",
        displayName: "Super Mario Bros. Deluxe",
        titleMatchers: [
            "super mario bros deluxe",
            "super mario deluxe",
            "smbd",
            "sm deluxe",
            "mario deluxe",           // Catch "MARIO DELUXAHYE"
            "smb deluxe",            // Super Mario Bros Deluxe shortened
            "smd",                   // Super Mario Deluxe abbreviation
            "deluxe",                // Match "deluxe" variations
            "deluxahye",              // Match "deluxahye" variations
            "mario deluxahye",          // Match "mario deluxahye" variations
            "mario deluxa",              // Match "mario deluxa" variations
            "mario deluxa hye",           // Match "mario deluxa hye" variations
            "mario deluxahy e",          // Match "mario deluxahy e" variations
            "mariodeluxe",              // Match "mariodeluxe" variations
            "mariodeluxahye",          // Match "mariodeluxahye" variations
            "smb"                   // Match "smb" variations
        ],
        nativeResolution: CGSize(width: 160, height: 144),
        gameplayRegion: CGRect(x: 0.0, y: 0.12, width: 1.0, height: 0.76),
        initialSearchRegion: CGRect(x: 0.08, y: 0.22, width: 0.84, height: 0.58),
        minSampleInterval: 0.8,  // Increased from 0.15 to reduce CPU load
        damageCooldown: 2.2,
        deathCooldown: 2.8,
        fadeConfirmationThreshold: 0.36,
        blackoutThreshold: 0.085,
        smallHeightRange: 8...15,
        superHeightRange: 16...24,
        poweredUpHeightRange: 22...36
    )

    static let superMarioAdvance = MarioGameProfile(
        id: "sma_gba",
        displayName: "Super Mario Advance",
        titleMatchers: [
            "super mario advance",
            "sma",
            "super mario bros 2"
        ],
        nativeResolution: CGSize(width: 240, height: 160),
        gameplayRegion: CGRect(x: 0.0, y: 0.14, width: 1.0, height: 0.72),
        initialSearchRegion: CGRect(x: 0.08, y: 0.24, width: 0.84, height: 0.56),
        minSampleInterval: 0.14,
        damageCooldown: 2.2,
        deathCooldown: 2.8,
        fadeConfirmationThreshold: 0.37,
        blackoutThreshold: 0.085,
        smallHeightRange: 9...16,
        superHeightRange: 17...26,
        poweredUpHeightRange: 24...38
    )

    static let sma2SuperMarioWorld = MarioGameProfile(
        id: "sma2_smw_gba",
        displayName: "Super Mario Advance 2: Super Mario World",
        titleMatchers: [
            "super mario advance 2",
            "super mario world",
            "sma2",
            "smw",
            "super mario b",
            "supermariob"
        ],
        nativeResolution: CGSize(width: 240, height: 160),
        gameplayRegion: CGRect(x: 0.0, y: 0.14, width: 1.0, height: 0.76),
        initialSearchRegion: CGRect(x: 0.08, y: 0.24, width: 0.84, height: 0.58),
        minSampleInterval: 0.14,
        damageCooldown: 2.3,
        deathCooldown: 3.0,
        fadeConfirmationThreshold: 0.38,
        blackoutThreshold: 0.09,
        smallHeightRange: 10...18,
        superHeightRange: 19...28,
        poweredUpHeightRange: 26...40
    )

    static let sma3YoshisIsland = MarioGameProfile(
        id: "sma3_yi_gba",
        displayName: "Super Mario Advance 3: Yoshi's Island",
        titleMatchers: [
            "super mario advance 3",
            "sma3",
            "yoshi's island",
            "yoshi island"
        ],
        nativeResolution: CGSize(width: 240, height: 160),
        gameplayRegion: CGRect(x: 0.0, y: 0.12, width: 1.0, height: 0.78),
        initialSearchRegion: CGRect(x: 0.06, y: 0.20, width: 0.88, height: 0.62),
        minSampleInterval: 0.14,
        damageCooldown: 2.4,
        deathCooldown: 3.2,
        fadeConfirmationThreshold: 0.40,
        blackoutThreshold: 0.10,
        smallHeightRange: 10...18,
        superHeightRange: 19...28,
        poweredUpHeightRange: 28...42
    )

    static let sma4SuperMarioBros3 = MarioGameProfile(
        id: "sma4_smb3_gba",
        displayName: "Super Mario Advance 4: Super Mario Bros. 3",
        titleMatchers: [
            "super mario advance 4",
            "sma4",
            "super mario bros 3",
            "smb3"
        ],
        nativeResolution: CGSize(width: 240, height: 160),
        gameplayRegion: CGRect(x: 0.0, y: 0.13, width: 1.0, height: 0.74),
        initialSearchRegion: CGRect(x: 0.08, y: 0.22, width: 0.84, height: 0.58),
        minSampleInterval: 0.14,
        damageCooldown: 2.3,
        deathCooldown: 3.0,
        fadeConfirmationThreshold: 0.38,
        blackoutThreshold: 0.09,
        smallHeightRange: 10...17,
        superHeightRange: 18...27,
        poweredUpHeightRange: 25...38
    )

    static let allProfiles: [MarioGameProfile] = [
        superMarioLand,
        superMarioLand2,
        superMarioBrosDeluxe,
        superMarioAdvance,
        sma2SuperMarioWorld,
        sma3YoshisIsland,
        sma4SuperMarioBros3
    ]
}

private extension String {
    var normalizedMarioProfileKey: String {
        lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }
}
