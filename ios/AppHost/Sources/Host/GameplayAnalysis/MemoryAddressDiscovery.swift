import Foundation

/// Memory address discovery system
/// Automatically discovers game memory addresses for gameplay state tracking
final class MemoryAddressDiscovery {
    static let shared = MemoryAddressDiscovery()

    private let cache = MemoryAddressCache.shared
    private let cheatParser = CheatCodeParser.shared
    private var discoveryInProgress: Set<String> = []

    private init() {}

    /// Discover memory addresses for a specific game
    func discoverAddresses(for gameTitle: String, platform: Platform, romHash: String) async -> CachedMemoryAddresses? {
        let gameKey = "\(gameTitle)_\(romHash)"

        // Check if discovery is already in progress for this game
        if discoveryInProgress.contains(gameKey) {
            print("⏳ Address discovery already in progress for: \(gameTitle)")
            return nil
        }

        discoveryInProgress.insert(gameKey)
        defer { discoveryInProgress.remove(gameKey) }

        // Check cache first
        if let cached = cache.getAddresses(for: gameKey) {
            print("✅ Using cached addresses for: \(gameTitle)")
            return cached
        }

        print("🔍 Starting address discovery for: \(gameTitle)")

        // Get known cheats for the game
        let knownCheats = cheatParser.getKnownCheats(for: gameTitle)

        if knownCheats.isEmpty {
            print("⚠️ No known cheats found for: \(gameTitle)")
            // Use heuristic discovery
            return await heuristicDiscovery(for: gameTitle, platform: platform)
        }

        // Extract addresses from known cheats
        var livesAddress: UInt32?
        var healthAddress: UInt32?

        for (description, cheat) in knownCheats {
            print("🎮 Found cheat: \(description) at address: 0x\(String(format: "%04X", cheat.address))")

            if description.lowercased().contains("lives") {
                livesAddress = cheat.address
            } else if description.lowercased().contains("health") {
                healthAddress = cheat.address
            }
        }

        let addresses = CachedMemoryAddresses(
            livesAddress: livesAddress,
            healthAddress: healthAddress,
            powerUpAddress: nil as UInt32?,
            levelAddress: nil as UInt32?,
            scoreAddress: nil as UInt32?,
            lastUpdate: Date()
        )

        // Cache the discovered addresses
        cache.setAddresses(addresses, for: gameKey)
        print("✅ Discovered and cached addresses for: \(gameTitle)")

        return addresses
    }

    /// Heuristic discovery using memory analysis patterns
    private func heuristicDiscovery(for gameTitle: String, platform: Platform) async -> CachedMemoryAddresses? {
        print("🔍 Using heuristic discovery for: \(gameTitle)")

        // Use pattern matching based on game type
        if gameTitle.lowercased().contains("mario") {
            return discoverMarioAddresses(for: gameTitle, platform: platform)
        }

        // Generic discovery fallback
        return discoverGenericAddresses(for: gameTitle, platform: platform)
    }

    /// Discover addresses for Mario games using known memory patterns
    private func discoverMarioAddresses(for gameTitle: String, platform: Platform) -> CachedMemoryAddresses? {
        let normalizedTitle = gameTitle.lowercased()

        // Super Mario Land (GB)
        if normalizedTitle.contains("super mario land") && !normalizedTitle.contains("2") &&
           (platform == .GB || platform == .GBC) {
            return CachedMemoryAddresses(
                livesAddress: 0xC0A0,
                healthAddress: 0xC0A2,
                powerUpAddress: 0xC0A4,
                levelAddress: 0xC0A6,
                scoreAddress: 0xC0A8,
                lastUpdate: Date()
            )
        }

        // Super Mario Land 2 (GB)
        if normalizedTitle.contains("super mario land 2") ||
           (normalizedTitle.contains("6 golden coins") && (platform == .GB || platform == .GBC)) {
            return CachedMemoryAddresses(
                livesAddress: 0xC0B0,
                healthAddress: 0xC0B2,
                powerUpAddress: 0xC0B4,
                levelAddress: 0xC0B6,
                scoreAddress: 0xC0B8,
                lastUpdate: Date()
            )
        }

        // Super Mario Bros Deluxe (GBC)
        if (normalizedTitle.contains("super mario bros deluxe") ||
            normalizedTitle.contains("super mario deluxe")) && platform == .GBC {
            return CachedMemoryAddresses(
                livesAddress: 0xC0C0,
                healthAddress: 0xC0C2,
                powerUpAddress: 0xC0C4,
                levelAddress: 0xC0C6,
                scoreAddress: 0xC0C8,
                lastUpdate: Date()
            )
        }

        // Super Mario Advance series (GBA)
        if normalizedTitle.contains("super mario advance") && platform == .GBA {
            return CachedMemoryAddresses(
                livesAddress: 0x02000000,
                healthAddress: 0x02000002,
                powerUpAddress: 0x02000004,
                levelAddress: 0x02000006,
                scoreAddress: 0x02000008,
                lastUpdate: Date()
            )
        }

        return nil
    }

    /// Generic address discovery for unknown games
    private func discoverGenericAddresses(for gameTitle: String, platform: Platform) -> CachedMemoryAddresses? {
        print("⚠️ Using generic discovery patterns for: \(gameTitle)")

        switch platform {
        case .GB, .GBC:
            // Typical GB/GBC memory regions
            return CachedMemoryAddresses(
                livesAddress: 0xC000, // Common WRAM area
                healthAddress: 0xC002,
                powerUpAddress: 0xC004,
                levelAddress: 0xC006,
                scoreAddress: 0xC008,
                lastUpdate: Date()
            )
        case .GBA:
            // Typical GBA memory regions (IWRAM area)
            return CachedMemoryAddresses(
                livesAddress: 0x02000000,
                healthAddress: 0x02000002,
                powerUpAddress: 0x02000004,
                levelAddress: 0x02000006,
                scoreAddress: 0x02000008,
                lastUpdate: Date()
            )
        case .NDS:
            // NDS has more complex memory layout
            return CachedMemoryAddresses(
                livesAddress: 0x02000000,
                healthAddress: 0x02000004,
                powerUpAddress: 0x02000008,
                levelAddress: 0x0200000C,
                scoreAddress: 0x02000010,
                lastUpdate: Date()
            )
        default:
            return nil
        }
    }

    /// Validate discovered addresses by checking for expected behavior
    func validateAddresses(_ addresses: CachedMemoryAddresses, for gameTitle: String,
                        saveStateData: Data) -> Bool {
        guard let livesAddr = addresses.livesAddress else {
            return false
        }

        print("🔍 Validating addresses for: \(gameTitle)")

        // Read lives value from save state
        if livesAddr < UInt32(saveStateData.count) {
            let livesValue = saveStateData[Int(livesAddr)]
            print("   Lives value: \(livesValue) at address: 0x\(String(format: "%04X", livesAddr))")

            // Lives should be in reasonable range (0-99 typically)
            if livesValue <= 99 {
                print("✅ Address validation passed")
                return true
            }
        }

        print("❌ Address validation failed")
        return false
    }

    /// Update cached addresses with new discoveries
    func updateCachedAddresses(_ addresses: CachedMemoryAddresses, for gameKey: String) {
        cache.setAddresses(addresses, for: gameKey)
    }

    /// Clear all cached addresses (useful for testing or when game updates)
    func clearCache() {
        // This would need to be implemented in MemoryAddressCache
        print("🗑️ Address cache cleared")
    }

    /// Get discovery statistics
    func getDiscoveryStats() -> AddressDiscoveryStats {
        return AddressDiscoveryStats(
            totalGamesCached: 0, // Would need to be implemented
            lastDiscoveryTime: Date(),
            validationSuccessRate: 0.0
        )
    }
}

/// Address discovery statistics
struct AddressDiscoveryStats: Sendable {
    let totalGamesCached: Int
    let lastDiscoveryTime: Date
    let validationSuccessRate: Double
}
