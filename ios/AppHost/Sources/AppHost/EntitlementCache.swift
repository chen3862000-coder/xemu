import Foundation

public struct Entitlement: Codable, Equatable {
    public let entitlementId: UUID
    public let productCode: ProductCode
    public var status: EntitlementStatus
    public let activatedAt: Date
    public let expiresAt: Date?
    
    public init(entitlementId: UUID, productCode: ProductCode, status: EntitlementStatus, activatedAt: Date, expiresAt: Date?) {
        self.entitlementId = entitlementId
        self.productCode = productCode
        self.status = status
        self.activatedAt = activatedAt
        self.expiresAt = expiresAt
    }
}

public struct DeviceProfile: Codable, Equatable {
    public let deviceId: UUID
    public let hardwareClass: HardwareClass
    public let whitelistVersion: String
    
    public init(deviceId: UUID, hardwareClass: HardwareClass, whitelistVersion: String) {
        self.deviceId = deviceId
        self.hardwareClass = hardwareClass
        self.whitelistVersion = whitelistVersion
    }
}

public struct EntitlementBundle: Codable, Equatable {
    public let userId: UUID
    public var entitlements: [Entitlement]
    public var deviceProfile: DeviceProfile?
    
    public init(userId: UUID, entitlements: [Entitlement], deviceProfile: DeviceProfile?) {
        self.userId = userId
        self.entitlements = entitlements
        self.deviceProfile = deviceProfile
    }
}

public final class EntitlementCache: @unchecked Sendable {
    private var bundle: EntitlementBundle?
    private var deviceProfile: DeviceProfile?
    private var cacheExpiry: Date?
    private let defaults = UserDefaults.standard
    
    public init() {}
    
    public func cache(_ bundle: EntitlementBundle) {
        self.bundle = bundle
        cacheExpiry = Date().addingTimeInterval(24 * 60 * 60)
        persist()
    }
    
    public func getCachedBundle() -> EntitlementBundle? {
        if let expiry = cacheExpiry, Date() > expiry {
            return nil
        }
        return bundle ?? loadBundle()
    }
    
    public func cacheDeviceProfile(_ profile: DeviceProfile) {
        self.deviceProfile = profile
        persist()
    }
    
    public func getCachedDeviceProfile() -> DeviceProfile? {
        return deviceProfile ?? loadDeviceProfile()
    }
    
    public func setCacheExpiry(seconds: Int) {
        cacheExpiry = Date().addingTimeInterval(Double(seconds))
    }
    
    public func isExpired() -> Bool {
        guard let expiry = cacheExpiry else { return false }
        return Date() > expiry
    }
    
    public func clearCache() {
        bundle = nil
        deviceProfile = nil
        cacheExpiry = nil
        persist()
        defaults.removeObject(forKey: "cachedBundle")
        defaults.removeObject(forKey: "cachedDeviceProfile")
    }
    
    public func hasActiveEntitlement(_ productCode: ProductCode) -> Bool {
        guard let bundle = getCachedBundle() else { return false }
        return bundle.entitlements.contains { $0.productCode == productCode && $0.status == .Active }
    }
    
    public func getEntitlement(by id: UUID) -> Entitlement? {
        guard let bundle = getCachedBundle() else { return nil }
        return bundle.entitlements.first { $0.entitlementId == id }
    }
    
    public func getDeviceId() -> UUID? {
        return getCachedDeviceProfile()?.deviceId ?? getCachedBundle()?.deviceProfile?.deviceId
    }
    
    public func getHardwareClass() -> HardwareClass? {
        return getCachedDeviceProfile()?.hardwareClass ?? getCachedBundle()?.deviceProfile?.hardwareClass
    }
    
    public func updateEntitlementStatus(id: UUID, status: EntitlementStatus) {
        if let index = bundle?.entitlements.firstIndex(where: { $0.entitlementId == id }) {
            bundle?.entitlements[index].status = status
            persist()
        }
    }
    
    private func persist() {
        if let bundle = bundle {
            if let data = try? JSONEncoder().encode(bundle) {
                defaults.set(data, forKey: "cachedBundle")
            }
        }
        if let profile = deviceProfile {
            if let data = try? JSONEncoder().encode(profile) {
                defaults.set(data, forKey: "cachedDeviceProfile")
            }
        }
    }
    
    private func loadBundle() -> EntitlementBundle? {
        guard let data = defaults.data(forKey: "cachedBundle"),
              let bundle = try? JSONDecoder().decode(EntitlementBundle.self, from: data) else {
            return nil
        }
        self.bundle = bundle
        return bundle
    }
    
    private func loadDeviceProfile() -> DeviceProfile? {
        guard let data = defaults.data(forKey: "cachedDeviceProfile"),
              let profile = try? JSONDecoder().decode(DeviceProfile.self, from: data) else {
            return nil
        }
        self.deviceProfile = profile
        return profile
    }
}
