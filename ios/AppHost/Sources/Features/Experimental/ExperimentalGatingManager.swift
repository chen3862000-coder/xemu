import Foundation

public enum ExperimentalGatingError: Error, LocalizedError {
    case deviceNotSupported
    case entitlementRequired(ProductCode)
    case romNotInDatabase

    public var errorDescription: String? {
        switch self {
        case .deviceNotSupported:
            return "This device is not supported for experimental emulation."
        case .entitlementRequired(let productCode):
            return "Experimental emulation requires the \(productCode.rawValue) entitlement."
        case .romNotInDatabase:
            return "This ROM is not in the compatibility database."
        }
    }
}

public struct ExperimentalGatingResult {
    public let isAllowed: Bool
    public let reason: String?
    public let requiredEntitlement: ProductCode?

    public init(isAllowed: Bool, reason: String? = nil, requiredEntitlement: ProductCode? = nil) {
        self.isAllowed = isAllowed
        self.reason = reason
        self.requiredEntitlement = requiredEntitlement
    }
}

@MainActor
public final class ExperimentalGatingManager {
    public static let shared = ExperimentalGatingManager()

    private let compatibilityStore = CompatibilityDataStore.shared
    private let entitlementCache = EntitlementCache()

    private init() {}

    public func checkDeviceSupport() -> HardwareClass {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        let model = String(cString: machine)

        return classifyHardwareModel(model)
    }

    private func classifyHardwareModel(_ model: String) -> HardwareClass {
        let tier1Models = [
            "iPhone14,2", "iPhone14,3", "iPhone14,7", "iPhone14,8",
            "iPhone15,2", "iPhone15,3", "iPhone15,4", "iPhone15,5",
            "iPad13,16", "iPad13,17", "iPad13,18", "iPad13,19",
            "iPad14,1", "iPad14,2", "iPad14,3", "iPad14,4",
            "iPad14,5", "iPad14,6", "iPad14,8", "iPad14,9",
            "iPad14,10", "iPad14,11", "iPad15,1", "iPad15,2",
            "iPad15,3", "iPad15,4", "iPad15,5", "iPad15,6",
            "iPad15,7", "iPad15,8", "iPad16,1", "iPad16,2",
            "iPad16,3", "iPad16,4", "iPad16,5", "iPad16,6",
            "AppleTV14,1"
        ]

        let tier2Models = [
            "iPhone11,2", "iPhone11,4", "iPhone11,6", "iPhone11,8",
            "iPhone12,1", "iPhone12,3", "iPhone12,5", "iPhone12,8",
            "iPhone13,1", "iPhone13,2", "iPhone13,3", "iPhone13,4",
            "iPhone13,20", "iPhone13,21", "iPhone13,22", "iPhone13,23",
            "iPad11,1", "iPad11,2", "iPad11,3", "iPad11,4",
            "iPad11,6", "iPad11,7", "iPad12,1", "iPad12,2",
            "iPad13,1", "iPad13,2", "iPad13,4", "iPad13,5",
            "iPad13,6", "iPad13,7", "iPad13,8", "iPad13,9",
            "iPad13,10", "iPad13,11", "iPad13,14", "iPad13,15",
            "iPad13,16", "iPad13,17", "iPad13,18", "iPad13,19",
            "AppleTV13,4"
        ]

        let tier3Models = [
            "iPhone10,3", "iPhone10,6", "iPhone11,2", "iPhone11,4",
            "iPhone11,6", "iPhone11,8", "iPad8,1", "iPad8,2",
            "iPad8,3", "iPad8,4", "iPad8,5", "iPad8,6",
            "iPad8,7", "iPad8,8", "iPad8,9", "iPad8,10",
            "iPad8,11", "iPad8,12", "iPad11,1", "iPad11,2",
            "iPad11,3", "iPad11,4", "iPad11,6", "iPad11,7",
            "iPad12,1", "iPad12,2", "iPad12,9", "iPad12,10",
            "iPad12,11", "iPad12,12", "iPad12,13", "iPad12,14",
            "iPad12,15", "iPad12,16", "iPad12,17", "iPad12,18",
            "iPad12,19", "iPad12,20", "iPad12,21", "iPad12,22",
            "iPad12,23", "iPad12,24", "iPad12,25", "iPad12,26",
            "iPad13,1", "iPad13,2", "iPad13,4", "iPad13,5",
            "iPad13,6", "iPad13,7", "iPad13,8", "iPad13,9",
            "iPad13,10", "iPad13,11", "iPad13,14", "iPad13,15",
            "iPad13,16", "iPad13,17", "iPad13,18", "iPad13,19",
            "iPad14,1", "iPad14,2", "iPad14,3", "iPad14,4",
            "iPad14,5", "iPad14,6", "iPad14,8", "iPad14,9",
            "iPad14,10", "iPad14,11", "iPad15,1", "iPad15,2",
            "iPad15,3", "iPad15,4", "iPad15,5", "iPad15,6",
            "iPad15,7", "iPad15,8", "iPad16,1", "iPad16,2",
            "iPad16,3", "iPad16,4", "iPad16,5", "iPad16,6",
            "AppleTV14,1"
        ]

        if tier1Models.contains(model) {
            return .tier1
        } else if tier2Models.contains(model) {
            return .tier2
        } else if tier3Models.contains(model) {
            return .tier3
        } else {
            return .unsupported
        }
    }

    public func canRunExperimentalROM(romHash: String) async -> ExperimentalGatingResult {
        let deviceClass = checkDeviceSupport()

        guard let compatInfo = compatibilityStore.getCompatibilityInfo(for: romHash) else {
            return ExperimentalGatingResult(
                isAllowed: false,
                reason: "ROM not found in compatibility database",
                requiredEntitlement: nil
            )
        }

        guard compatInfo.tier == .experimental else {
            return ExperimentalGatingResult(
                isAllowed: true,
                reason: nil,
                requiredEntitlement: nil
            )
        }

        guard deviceClass != .unsupported else {
            return ExperimentalGatingResult(
                isAllowed: false,
                reason: "This device is not supported for experimental emulation",
                requiredEntitlement: nil
            )
        }

        let isCompatible = compatibilityStore.isCompatible(romHash: romHash, deviceHardwareClass: deviceClass)

        guard isCompatible else {
            return ExperimentalGatingResult(
                isAllowed: false,
                reason: "This ROM requires a device with \(compatInfo.minDeviceTier.rawValue) or better. Your device is \(deviceClass.rawValue).",
                requiredEntitlement: nil
            )
        }

        let hasExperimentalEntitlement = entitlementCache.hasActiveEntitlement(.experimentalPack)
        let hasProEntitlement = entitlementCache.hasActiveEntitlement(.proBundle)

        let hasEntitlement = hasExperimentalEntitlement || hasProEntitlement

        guard hasEntitlement else {
            return ExperimentalGatingResult(
                isAllowed: false,
                reason: "Experimental emulation requires the EXPERIMENTAL_PACK or PRO_BUNDLE entitlement",
                requiredEntitlement: .experimentalPack
            )
        }

        return ExperimentalGatingResult(
            isAllowed: true,
            reason: nil,
            requiredEntitlement: nil
        )
    }

    public func getDeviceHardwareClass() -> HardwareClass {
        return checkDeviceSupport()
    }

    public func requiresEntitlement(for romHash: String) -> ProductCode? {
        guard let compatInfo = compatibilityStore.getCompatibilityInfo(for: romHash) else {
            return nil
        }

        return compatInfo.tier == .experimental ? .experimentalPack : nil
    }

    public func getMinimumHardwareRequirement(for romHash: String) -> HardwareClass? {
        return compatibilityStore.getMinDeviceTier(for: romHash)
    }

    public func getCompatibilityInfo(for romHash: String) -> CompatibilityInfo? {
        return compatibilityStore.getCompatibilityInfo(for: romHash)
    }
}
