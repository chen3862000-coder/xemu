import Foundation
import CoreGraphics

enum GameplayProfileKind: Sendable {
    case marioPlatformer
    case metroidFusion
}

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
    let liveMemory: MarioLiveMemoryMap?

    func matches(title: String, platform: Platform, romHash: String) -> Bool {
        matchScore(title: title, platform: platform, romHash: romHash) != nil
    }

    func matchScore(title: String, platform: Platform, romHash: String) -> Int? {
        guard profilePlatform == platform else { return nil }
        let normalizedTitle = title.normalizedMarioProfileKey
        let normalizedHash = romHash.normalizedMarioProfileKey
        let scores = titleMatchers.compactMap { matcher -> Int? in
            let candidate = matcher.normalizedMarioProfileKey
            guard normalizedTitle.contains(candidate) || (!normalizedHash.isEmpty && normalizedHash.contains(candidate)) else {
                return nil
            }
            return candidate.count
        }
        return scores.max()
    }

    static func activeProfile(
        title: String,
        platform: Platform,
        romHash: String
    ) -> MarioGameProfile? {
        allProfiles
            .compactMap { profile in
                profile.matchScore(title: title, platform: platform, romHash: romHash).map { (profile, $0) }
            }
            .max { lhs, rhs in lhs.1 < rhs.1 }?
            .0
    }

    static let superMarioLand = MarioGameProfile(
        id: "sml_gb",
        displayName: "Super Mario Land",
        titleMatchers: [
            "super mario land",
            "sml"
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
        poweredUpHeightRange: 20...32,
        liveMemory: nil
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
        poweredUpHeightRange: 20...32,
        liveMemory: nil
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
            "smb",                  // Match "smb" variations
            "f84f26f22751b58ed57bd332274e18131660729a",
            "07295cd60ae44183ebecb013930727e0404169d5",
            "254f2254e9d54e2501e3e4ebe09491e03573a6a4"
        ],
        nativeResolution: CGSize(width: 160, height: 144),
        gameplayRegion: CGRect(x: 0.0, y: 0.12, width: 1.0, height: 0.76),
        initialSearchRegion: CGRect(x: 0.08, y: 0.22, width: 0.84, height: 0.58),
        minSampleInterval: 0.16,
        damageCooldown: 2.2,
        deathCooldown: 2.8,
        fadeConfirmationThreshold: 0.36,
        blackoutThreshold: 0.085,
        smallHeightRange: 8...15,
        superHeightRange: 16...24,
        poweredUpHeightRange: 22...36,
        liveMemory: MarioLiveMemoryMap(
            kind: .marioPlatformer,
            livesAddress: 0xC17F,
            powerUpAddress: 0xC1C5,
            gameplayStateAddress: 0xC1C1,
            invulnerabilityTimerAddress: 0xC1D5,
            deathStateValues: [0x03],
            invulnerabilityStateValues: [0x06],
            smallPowerUpValues: [0],
            superPowerUpValues: [1],
            poweredUpValues: [2, 3],
            healthAddress16: nil,
            maxHealthAddress16: nil,
            gameModeAddress: nil
        )
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
        poweredUpHeightRange: 24...38,
        liveMemory: nil
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
        poweredUpHeightRange: 26...40,
        liveMemory: MarioLiveMemoryMap(
            kind: .marioPlatformer,
            livesAddress: 0x030042BC,
            powerUpAddress: 0x03004300,
            gameplayStateAddress: 0x03003FA0,
            invulnerabilityTimerAddress: 0x0300402D,
            deathStateValues: [0x09],
            invulnerabilityStateValues: [0x01, 0x0E],
            smallPowerUpValues: [0],
            superPowerUpValues: [1],
            poweredUpValues: [2, 3],
            healthAddress16: nil,
            maxHealthAddress16: nil,
            gameModeAddress: nil
        )
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
        poweredUpHeightRange: 28...42,
        liveMemory: nil
    )

    static let sma4SuperMarioBros3 = MarioGameProfile(
        id: "sma4_smb3_gba",
        displayName: "Super Mario Advance 4: Super Mario Bros. 3",
        titleMatchers: [
            "super mario advance 4",
            "sma4",
            "super mario bros 3",
            "smb3",
            "super mariod",
            "69e81f41394f02d64cad206adb26b3cd43690770",
            "532f3307021637474b6dd37da059ca360f612337",
            "b7f3d6dc014e2f0ddc996137bdefbb8167a77e66",
            "2e5ce11a893464dc0cce0a6b451580ba35a7e5de"
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
        poweredUpHeightRange: 25...38,
        liveMemory: MarioLiveMemoryMap(
            kind: .marioPlatformer,
            livesAddress: 0x03002A6A,
            powerUpAddress: 0x03003F5B,
            gameplayStateAddress: 0x03003F65,
            invulnerabilityTimerAddress: 0x03003F60,
            deathStateValues: [],
            invulnerabilityStateValues: [],
            smallPowerUpValues: [0],
            superPowerUpValues: [1],
            poweredUpValues: [2, 3, 4, 5, 6, 7, 8],
            healthAddress16: nil,
            maxHealthAddress16: nil,
            gameModeAddress: nil
        )
    )

    static let metroidFusion = MarioGameProfile(
        id: "metroid_fusion_gba",
        displayName: "Metroid Fusion",
        titleMatchers: [
            "metroid fusion",
            "metroid4",
            "metroid 4",
            "metroid4usa",
            "metroid4eur",
            "metroid4jpn",
            "metfusionchn"
        ],
        nativeResolution: CGSize(width: 240, height: 160),
        gameplayRegion: CGRect(x: 0.0, y: 0.10, width: 1.0, height: 0.80),
        initialSearchRegion: CGRect(x: 0.08, y: 0.18, width: 0.84, height: 0.64),
        minSampleInterval: 0.14,
        damageCooldown: 0.9,
        deathCooldown: 2.0,
        fadeConfirmationThreshold: 0.38,
        blackoutThreshold: 0.09,
        smallHeightRange: 10...20,
        superHeightRange: 21...32,
        poweredUpHeightRange: 21...32,
        liveMemory: MarioLiveMemoryMap(
            kind: .metroidFusion,
            livesAddress: 0x03001310,
            powerUpAddress: 0x0300131C,
            gameplayStateAddress: 0x03001245,
            invulnerabilityTimerAddress: 0x03001249,
            deathStateValues: [0x3E, 0x3F],
            invulnerabilityStateValues: [0x11, 0x12, 0x13, 0x14],
            smallPowerUpValues: [],
            superPowerUpValues: [0],
            poweredUpValues: Set(1...UInt8.max),
            healthAddress16: 0x03001310,
            maxHealthAddress16: 0x03001312,
            gameModeAddress: 0x03000BDE
        )
    )

    static let allProfiles: [MarioGameProfile] = [
        superMarioLand,
        superMarioLand2,
        superMarioBrosDeluxe,
        superMarioAdvance,
        sma2SuperMarioWorld,
        sma3YoshisIsland,
        sma4SuperMarioBros3,
        metroidFusion
    ]

    private var profilePlatform: Platform {
        if id.hasSuffix("_gbc") {
            return .GBC
        }
        if id.hasSuffix("_gb") {
            return .GB
        }
        return .GBA
    }
}

struct MarioLiveMemoryMap: Sendable {
    let kind: GameplayProfileKind
    let livesAddress: UInt32
    let powerUpAddress: UInt32
    let gameplayStateAddress: UInt32
    let invulnerabilityTimerAddress: UInt32
    let deathStateValues: Set<UInt8>
    let invulnerabilityStateValues: Set<UInt8>
    let smallPowerUpValues: Set<UInt8>
    let superPowerUpValues: Set<UInt8>
    let poweredUpValues: Set<UInt8>
    let healthAddress16: UInt32?
    let maxHealthAddress16: UInt32?
    let gameModeAddress: UInt32?
}

private extension String {
    var normalizedMarioProfileKey: String {
        lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "", options: .regularExpression)
    }
}
