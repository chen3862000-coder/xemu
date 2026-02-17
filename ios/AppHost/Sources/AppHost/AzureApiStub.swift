import Foundation
import Combine

public struct CompatibilityProfile: Codable, Equatable {
    public let tier: String
    public let platform: String
    
    public init(tier: String, platform: String) {
        self.tier = tier
        self.platform = platform
    }
}

public struct Achievement: Codable, Equatable {
    public let id: UUID
    public let title: String
    public let description: String
    public let category: String
    
    public init(id: UUID, title: String, description: String, category: String) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
    }
}

public class AzureApiStub {
    public var simulateNetworkError: Bool = false
    
    public init() {}
    
    public func fetchEntitlements(userId: UUID) -> AnyPublisher<EntitlementBundle, Error> {
        if simulateNetworkError {
            return Fail(error: NSError(domain: "AzureError", code: -1, userInfo: nil)).eraseToAnyPublisher()
        }
        
        if userId.uuidString.contains("error-") {
            return Fail(error: NSError(domain: "AzureError", code: -1, userInfo: nil)).eraseToAnyPublisher()
        }
        
        let entitlements = [
            Entitlement(
                entitlementId: UUID(),
                productCode: .REMOVE_ADS,
                status: .Active,
                activatedAt: Date(),
                expiresAt: nil
            )
        ]
        
        let bundle = EntitlementBundle(
            userId: userId,
            entitlements: entitlements,
            deviceProfile: DeviceProfile(
                deviceId: UUID(),
                hardwareClass: .Tier1,
                whitelistVersion: "1.0"
            )
        )
        
        return Just(bundle).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    public func validateDevice(deviceId: UUID) -> AnyPublisher<Bool, Error> {
        if simulateNetworkError {
            return Fail(error: NSError(domain: "AzureError", code: -1, userInfo: nil)).eraseToAnyPublisher()
        }
        
        if deviceId == UUID(uuidString: "00000000-0000-0000-0000-000000000000") {
            return Just(false).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    public func checkCompatibility(romHash: String) -> AnyPublisher<CompatibilityProfile, Error> {
        if simulateNetworkError {
            return Fail(error: NSError(domain: "AzureError", code: -1, userInfo: nil)).eraseToAnyPublisher()
        }
        
        let profile: CompatibilityProfile
        if romHash == "nes_stable_hash" {
            profile = CompatibilityProfile(tier: "stable", platform: "nes")
        } else if romHash == "experimental_hash_456" {
            profile = CompatibilityProfile(tier: "experimental", platform: "gba")
        } else {
            profile = CompatibilityProfile(tier: "unknown", platform: "nes")
        }
        
        return Just(profile).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    public func submitTelemetry(data: [String: Any]) -> AnyPublisher<Bool, Error> {
        if simulateNetworkError {
            return Fail(error: NSError(domain: "AzureError", code: -1, userInfo: nil)).eraseToAnyPublisher()
        }
        
        return Just(true).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
    
    public func fetchAchievements(userId: UUID) -> AnyPublisher<[Achievement], Error> {
        if simulateNetworkError {
            return Fail(error: NSError(domain: "AzureError", code: -1, userInfo: nil)).eraseToAnyPublisher()
        }
        
        let achievements = [
            Achievement(
                id: UUID(),
                title: "First Steps",
                description: "Complete your first level",
                category: "progression"
            )
        ]
        
        return Just(achievements).setFailureType(to: Error.self).eraseToAnyPublisher()
    }
}
