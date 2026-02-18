import Foundation

public final class DeviceProfileCache: @unchecked Sendable {
    public static let shared = DeviceProfileCache()
    
    public var cache: [UUID: DeviceProfile] = [:]
    private let queue = DispatchQueue(label: "com.xemu.deviceprofilecache", qos: .userInitiated)
    
    private init() {}
    
    public func getCachedProfile() -> DeviceProfile? {
        return queue.sync { cache.values.first }
    }
    
    public func loadProfile(for deviceId: String) -> DeviceProfile? {
        if let uuid = UUID(uuidString: deviceId) {
            return queue.sync { cache[uuid] }
        }
        return nil
    }
    
    public func loadProfile() -> DeviceProfile? {
        return queue.sync { cache.values.first }
    }
    
    public func cache(_ profile: DeviceProfile) {
        queue.async { [weak self] in
            self?.cache[profile.deviceId] = profile
        }
    }
    
    public func saveProfile(_ profile: DeviceProfile) {
        queue.async { [weak self] in
            self?.cache[profile.deviceId] = profile
        }
    }

    func saveProfile(from cached: CachedDeviceProfile) {
        guard let hwClass = HardwareClass(rawValue: cached.hardwareClass) else { return }
        let profile = DeviceProfile(
            deviceId: cached.deviceId,
            hardwareClass: hwClass,
            whitelistVersion: "1.0"
        )
        queue.async { [weak self] in
            self?.cache[profile.deviceId] = profile
        }
    }
    
    public func clearCache() {
        queue.async { [weak self] in
            self?.cache.removeAll()
        }
    }
}
