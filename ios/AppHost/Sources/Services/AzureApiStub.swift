import Foundation

struct AzureApiStub {
    static let shared = AzureApiStub()

    private let decoder = JSONDecoder()

    private init() {}

    // MARK: - Entitlements

    func fetchEntitlements() async throws -> EntitlementBundle {
        try await Task.sleep(nanoseconds: 150_000_000) // simulate latency
        guard let data = Self.stubData(named: "entitlements") else {
            throw StubError.missingResource("entitlements")
        }

        return try decoder.decode(EntitlementBundle.self, from: data)
    }

    // MARK: - Compatibility

    func fetchCompatibilityMatrix() throws -> [CompatibilityEntry] {
        guard let data = Self.stubData(named: "compatibility") else { return [] }
        return (try? decoder.decode([CompatibilityEntry].self, from: data)) ?? []
    }

    // MARK: - Leaderboards

    func fetchLeaderboard(console: String, seasonId: String) async -> [LeaderboardRow] {
        guard let data = Self.stubData(named: "leaderboard") else { return [] }
        return (try? decoder.decode([LeaderboardRow].self, from: data)) ?? []
    }

    // MARK: - Helpers

    private static func stubData(named name: String) -> Data? {
        guard let url = resourceBundle.url(forResource: name, withExtension: "json", subdirectory: "MockData") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }
}

extension AzureApiStub {
    struct EntitlementBundle: Codable {
        struct Entitlement: Codable {
            let productCode: String
            let status: String
            let features: [String: Bool]
            let offlineGraceEnd: Date
        }

        let entitlements: [Entitlement]
    }

    struct CompatibilityEntry: Codable, Identifiable {
        let id: UUID
        let romHash: String
        let minDeviceTier: String
        let tier: String
        let notes: String
    }

    struct LeaderboardRow: Codable, Identifiable {
        let id: UUID
        let username: String
        let rank: Int
        let score: Double
        let region: String
    }

    enum StubError: Error {
        case missingResource(String)
    }
}
