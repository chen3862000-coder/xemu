import Foundation

public struct CompatibilityInfo: Codable, Identifiable {
    public let id: UUID
    public let romHash: String
    public let minDeviceTier: HardwareClass
    public let tier: Tier
    public let notes: String

    public init(id: UUID, romHash: String, minDeviceTier: HardwareClass, tier: Tier, notes: String) {
        self.id = id
        self.romHash = romHash
        self.minDeviceTier = minDeviceTier
        self.tier = tier
        self.notes = notes
    }
}

public final class CompatibilityDataStore: @unchecked Sendable {
    public static let shared = CompatibilityDataStore()

    private var compatibilityMap: [String: CompatibilityInfo] = [:]
    private let decoder = JSONDecoder()

    private init() {
        loadCompatibilityData()
    }

    private func loadCompatibilityData() {
        if let url = resourceBundle.url(forResource: "compatibility", withExtension: "json", subdirectory: "MockData"),
           let data = try? Data(contentsOf: url) {
            decodeCompatibilityData(data)
            return
        }

        let fallbackEntries = (try? AzureApiStub.shared.fetchCompatibilityMatrix()) ?? []
        compatibilityMap = Dictionary(
            uniqueKeysWithValues: fallbackEntries.map {
                (
                    $0.romHash,
                    CompatibilityInfo(
                        id: $0.id,
                        romHash: $0.romHash,
                        minDeviceTier: HardwareClass(rawValue: $0.minDeviceTier) ?? .unsupported,
                        tier: Tier(rawValue: $0.tier.lowercased()) ?? .unknown,
                        notes: $0.notes
                    )
                )
            }
        )
    }

    private func decodeCompatibilityData(_ data: Data) {
        do {
            let entries = try decoder.decode([CompatibilityEntry].self, from: data)
            for entry in entries {
                let info = CompatibilityInfo(
                    id: entry.id,
                    romHash: entry.romHash,
                    minDeviceTier: HardwareClass(rawValue: entry.minDeviceTier) ?? .unsupported,
                    tier: Tier(rawValue: entry.tier.lowercased()) ?? .unknown,
                    notes: entry.notes
                )
                compatibilityMap[info.romHash] = info
            }
        } catch {
        }
    }

    public func getCompatibilityInfo(for romHash: String) -> CompatibilityInfo? {
        return compatibilityMap[romHash]
    }

    public func getTier(for romHash: String) -> Tier {
        return compatibilityMap[romHash]?.tier ?? .unknown
    }

    public func getMinDeviceTier(for romHash: String) -> HardwareClass {
        return compatibilityMap[romHash]?.minDeviceTier ?? .unsupported
    }

    public func isExperimental(for romHash: String) -> Bool {
        return getTier(for: romHash) == .experimental
    }

    public func isCompatible(romHash: String, deviceHardwareClass: HardwareClass) -> Bool {
        guard let info = compatibilityMap[romHash] else { return false }

        let deviceRank = deviceHardwareClass.rank
        let requiredRank = info.minDeviceTier.rank

        return deviceRank >= requiredRank
    }

    public func getAllExperimentalROMs() -> [CompatibilityInfo] {
        return compatibilityMap.values.filter { $0.tier == .experimental }
    }

    public func getAllROMs() -> [CompatibilityInfo] {
        return Array(compatibilityMap.values)
    }

    public func reload() {
        compatibilityMap.removeAll()
        loadCompatibilityData()
    }

    private var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}

private struct CompatibilityEntry: Codable {
    let id: UUID
    let romHash: String
    let minDeviceTier: String
    let tier: String
    let notes: String
}

private extension HardwareClass {
    var rank: Int {
        switch self {
        case .tier1: return 1
        case .tier2: return 2
        case .tier3: return 3
        case .unsupported: return 0
        }
    }
}
