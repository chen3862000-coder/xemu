import Foundation

/// Memory address cache for storing discovered game memory addresses
final class MemoryAddressCache {

    static let shared = MemoryAddressCache()

    private let cache = NSCache<NSString, CachedMemoryAddressesWrapper>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL

    private init() {
        // Set up cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDirectory.appendingPathComponent("MemoryAddresses", isDirectory: true)

        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: cacheDirectory.path) {
            try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }

        // Configure memory cache
        cache.countLimit = 100 // Maximum number of cached games
        cache.totalCostLimit = 10 * 1024 * 1024 // 10MB limit

        // Load cached addresses from disk
        loadCacheFromDisk()
    }

    /// Get cached addresses for a specific game
    func getAddresses(for gameKey: String) -> CachedMemoryAddresses? {
        if let wrapper = cache.object(forKey: gameKey as NSString) {
            return wrapper.addresses
        }

        // Try to load from disk
        return loadFromDisk(gameKey: gameKey)
    }

    /// Set cached addresses for a specific game
    func setAddresses(_ addresses: CachedMemoryAddresses, for gameKey: String) {
        let wrapper = CachedMemoryAddressesWrapper(addresses: addresses)
        cache.setObject(wrapper, forKey: gameKey as NSString)

        // Also save to disk
        saveToDisk(addresses: addresses, gameKey: gameKey)
    }

    /// Clear all cached addresses
    func clearAll() {
        cache.removeAllObjects()

        // Clear disk cache
        if let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                try? fileManager.removeItem(at: fileURL)
            }
        }

        print("🗑️ Memory address cache cleared")
    }

    // MARK: - Private Methods

    private func loadCacheFromDisk() {
        guard let enumerator = fileManager.enumerator(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        var loadedCount = 0
        for case let fileURL as URL in enumerator {
            if let addresses = loadFromDisk(gameKey: fileURL.deletingPathExtension().lastPathComponent) {
                let wrapper = CachedMemoryAddressesWrapper(addresses: addresses)
                cache.setObject(wrapper, forKey: fileURL.deletingPathExtension().lastPathComponent as NSString)
                loadedCount += 1
            }
        }

        if loadedCount > 0 {
            print("📂 Loaded \(loadedCount) cached address sets from disk")
        }
    }

    private func loadFromDisk(gameKey: String) -> CachedMemoryAddresses? {
        let fileURL = cacheDirectory.appendingPathComponent("\(gameKey).json")

        guard let data = try? Data(contentsOf: fileURL) else {
            return nil
        }

        return try? JSONDecoder().decode(CachedMemoryAddresses.self, from: data)
    }

    private func saveToDisk(addresses: CachedMemoryAddresses, gameKey: String) {
        let fileURL = cacheDirectory.appendingPathComponent("\(gameKey).json")

        guard let data = try? JSONEncoder().encode(addresses) else {
            return
        }

        try? data.write(to: fileURL)
    }
}

/// Wrapper for NSCache
private class CachedMemoryAddressesWrapper {
    let addresses: CachedMemoryAddresses

    init(addresses: CachedMemoryAddresses) {
        self.addresses = addresses
    }
}

/// Cached memory addresses for a game
struct CachedMemoryAddresses: Codable, Sendable {
    let livesAddress: UInt32?
    let healthAddress: UInt32?
    let powerUpAddress: UInt32?
    let levelAddress: UInt32?
    let scoreAddress: UInt32?
    let lastUpdate: Date
}