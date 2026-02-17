import XCTest
import Combine
@testable import AppHost

final class EntitlementCacheTests: XCTestCase {

    var cache: EntitlementCache!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cache = EntitlementCache()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cache = nil
        cancellables = nil
        super.tearDown()
    }

    func testEntitlementBundleCreation() {
        let bundle = EntitlementBundle(
            userId: UUID(),
            entitlements: [
                Entitlement(
                    entitlementId: UUID(),
                    productCode: .REMOVE_ADS,
                    status: .Active,
                    activatedAt: Date(),
                    expiresAt: nil
                )
            ],
            deviceProfile: DeviceProfile(
                deviceId: UUID(),
                hardwareClass: .Tier1,
                whitelistVersion: "1.0.0"
            )
        )

        XCTAssertNotNil(bundle.userId)
        XCTAssertEqual(bundle.entitlements.count, 1)
        XCTAssertNotNil(bundle.deviceProfile)
    }

    func testEntitlementCreation() {
        let entitlement = Entitlement(
            entitlementId: UUID(),
            productCode: .EXPERIMENTAL_PACK,
            status: .Active,
            activatedAt: Date(),
            expiresAt: nil
        )

        XCTAssertEqual(entitlement.productCode, .EXPERIMENTAL_PACK)
        XCTAssertEqual(entitlement.status, .Active)
        XCTAssertNil(entitlement.expiresAt)
    }

    func testEntitlementExpiring() {
        let futureDate = Date().addingTimeInterval(86400 * 30)
        let entitlement = Entitlement(
            entitlementId: UUID(),
            productCode: .PRO_BUNDLE,
            status: .Active,
            activatedAt: Date(),
            expiresAt: futureDate
        )

        XCTAssertNotNil(entitlement.expiresAt)
    }

    func testDeviceProfileCreation() {
        let profile = DeviceProfile(
            deviceId: UUID(),
            hardwareClass: .Tier2,
            whitelistVersion: "2.1.0"
        )

        XCTAssertEqual(profile.hardwareClass, .Tier2)
        XCTAssertEqual(profile.whitelistVersion, "2.1.0")
    }

    func testDeviceProfileAllHardwareClasses() {
        let tier1 = DeviceProfile(deviceId: UUID(), hardwareClass: .Tier1, whitelistVersion: "1.0")
        let tier2 = DeviceProfile(deviceId: UUID(), hardwareClass: .Tier2, whitelistVersion: "1.0")
        let tier3 = DeviceProfile(deviceId: UUID(), hardwareClass: .Tier3, whitelistVersion: "1.0")
        let unsupported = DeviceProfile(deviceId: UUID(), hardwareClass: .Unsupported, whitelistVersion: "1.0")

        XCTAssertEqual(tier1.hardwareClass, .Tier1)
        XCTAssertEqual(tier2.hardwareClass, .Tier2)
        XCTAssertEqual(tier3.hardwareClass, .Tier3)
        XCTAssertEqual(unsupported.hardwareClass, .Unsupported)
    }

    func testCacheBundle() {
        let bundle = createTestBundle()
        cache.cache(bundle)

        let cached = cache.getCachedBundle()
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.userId, bundle.userId)
    }

    func testCacheDeviceProfile() {
        let profile = DeviceProfile(
            deviceId: UUID(),
            hardwareClass: .Tier1,
            whitelistVersion: "1.5.0"
        )

        cache.cacheDeviceProfile(profile)

        let cached = cache.getCachedDeviceProfile()
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.deviceId, profile.deviceId)
    }

    @MainActor func testCacheExpiration() async throws {
        let bundle = createTestBundle()
        cache.cache(bundle)

        let immediateResult = cache.getCachedBundle()
        XCTAssertNotNil(immediateResult)

        cache.setCacheExpiry(seconds: 0)

        try await Task.sleep(nanoseconds: 150_000_000)
        let expiredResult = cache.getCachedBundle()
        XCTAssertNil(expiredResult)
    }

    func testClearCache() {
        let bundle = createTestBundle()
        cache.cache(bundle)

        cache.clearCache()

        let result = cache.getCachedBundle()
        XCTAssertNil(result)
    }

    @MainActor func testIsExpired() {
        cache.setCacheExpiry(seconds: 5)

        XCTAssertFalse(cache.isExpired())

        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            XCTAssertTrue(self.cache.isExpired())
        }
    }

    func testHasActiveEntitlement() {
        let bundle = createTestBundle()
        cache.cache(bundle)

        XCTAssertTrue(cache.hasActiveEntitlement(.REMOVE_ADS))
        XCTAssertFalse(cache.hasActiveEntitlement(.EXPERIMENTAL_PACK))
    }

    func testHasNoActiveEntitlement() {
        cache.clearCache()

        XCTAssertFalse(cache.hasActiveEntitlement(.REMOVE_ADS))
        XCTAssertFalse(cache.hasActiveEntitlement(.PRO_BUNDLE))
    }

    func testGetEntitlementById() {
        let bundle = createTestBundle()
        cache.cache(bundle)

        guard let entitlementId = bundle.entitlements.first?.entitlementId else {
            XCTFail("No entitlements")
            return
        }

        let found = cache.getEntitlement(by: entitlementId)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.entitlementId, entitlementId)
    }

    func testGetEntitlementByIdNotFound() {
        let randomId = UUID()

        let found = cache.getEntitlement(by: randomId)
        XCTAssertNil(found)
    }

    func testGetDeviceId() {
        let bundle = createTestBundle()
        cache.cache(bundle)

        guard let deviceId = bundle.deviceProfile?.deviceId else {
            XCTFail("No device ID")
            return
        }

        let cachedDeviceId = cache.getDeviceId()
        XCTAssertEqual(cachedDeviceId, deviceId)
    }

    func testGetHardwareClass() {
        let bundle = createTestBundle()
        cache.cache(bundle)

        let hardwareClass = cache.getHardwareClass()
        XCTAssertNotNil(hardwareClass)
        XCTAssertEqual(hardwareClass, .Tier1)
    }

    func testUpdateEntitlementStatus() {
        let bundle = createTestBundle()
        cache.cache(bundle)

        guard let entitlementId = bundle.entitlements.first?.entitlementId else {
            XCTFail("No entitlements")
            return
        }

        cache.updateEntitlementStatus(id: entitlementId, status: .Revoked)

        let updated = cache.getEntitlement(by: entitlementId)
        XCTAssertEqual(updated?.status, .Revoked)
    }

    func testEntitlementBundleCodable() {
        let originalBundle = createTestBundle()

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(originalBundle),
              let decodedBundle = try? JSONDecoder().decode(EntitlementBundle.self, from: data) else {
            XCTFail("Encoding/decoding failed")
            return
        }

        XCTAssertEqual(originalBundle.userId, decodedBundle.userId)
        XCTAssertEqual(originalBundle.entitlements.count, decodedBundle.entitlements.count)
    }

    func testDeviceProfileCodable() {
        let originalProfile = DeviceProfile(
            deviceId: UUID(),
            hardwareClass: .Tier2,
            whitelistVersion: "3.2.1"
        )

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(originalProfile),
              let decodedProfile = try? JSONDecoder().decode(DeviceProfile.self, from: data) else {
            XCTFail("Encoding/decoding failed")
            return
        }

        XCTAssertEqual(originalProfile.deviceId, decodedProfile.deviceId)
        XCTAssertEqual(originalProfile.hardwareClass, decodedProfile.hardwareClass)
    }

    func testMultipleEntitlements() {
        let bundle = EntitlementBundle(
            userId: UUID(),
            entitlements: [
                Entitlement(
                    entitlementId: UUID(),
                    productCode: .REMOVE_ADS,
                    status: .Active,
                    activatedAt: Date(),
                    expiresAt: nil
                ),
                Entitlement(
                    entitlementId: UUID(),
                    productCode: .EXPERIMENTAL_PACK,
                    status: .Active,
                    activatedAt: Date(),
                    expiresAt: nil
                ),
                Entitlement(
                    entitlementId: UUID(),
                    productCode: .PRO_BUNDLE,
                    status: .Active,
                    activatedAt: Date(),
                    expiresAt: nil
                )
            ],
            deviceProfile: DeviceProfile(
                deviceId: UUID(),
                hardwareClass: .Tier1,
                whitelistVersion: "1.0.0"
            )
        )

        cache.cache(bundle)

        XCTAssertTrue(cache.hasActiveEntitlement(.REMOVE_ADS))
        XCTAssertTrue(cache.hasActiveEntitlement(.EXPERIMENTAL_PACK))
        XCTAssertTrue(cache.hasActiveEntitlement(.PRO_BUNDLE))
    }

    func testCachePersistence() {
        let bundle = createTestBundle()
        cache.cache(bundle)

        let newCache = EntitlementCache()
        let persistedBundle = newCache.getCachedBundle()

        XCTAssertNotNil(persistedBundle)
        XCTAssertEqual(persistedBundle?.userId, bundle.userId)
    }

    func testAllEntitlementStatuses() {
        let statuses: [EntitlementStatus] = [.Active, .Revoked, .Refunded, .Expired]

        for status in statuses {
            XCTAssertEqual(status.rawValue, "\(status)")
        }
    }

    func testEntitlementEquality() {
        let id = UUID()
        let entitlement1 = Entitlement(
            entitlementId: id,
            productCode: .REMOVE_ADS,
            status: .Active,
            activatedAt: Date(),
            expiresAt: nil
        )

        let entitlement2 = Entitlement(
            entitlementId: id,
            productCode: .REMOVE_ADS,
            status: .Active,
            activatedAt: entitlement1.activatedAt,
            expiresAt: nil
        )

        XCTAssertEqual(entitlement1.entitlementId, entitlement2.entitlementId)
    }

    func testInvalidCacheExpiry() {
        cache.setCacheExpiry(seconds: -1)

        XCTAssertTrue(cache.isExpired())
    }

    private func createTestBundle() -> EntitlementBundle {
        return EntitlementBundle(
            userId: UUID(),
            entitlements: [
                Entitlement(
                    entitlementId: UUID(),
                    productCode: .REMOVE_ADS,
                    status: .Active,
                    activatedAt: Date(),
                    expiresAt: nil
                )
            ],
            deviceProfile: DeviceProfile(
                deviceId: UUID(),
                hardwareClass: .Tier1,
                whitelistVersion: "1.0.0"
            )
        )
    }
}
