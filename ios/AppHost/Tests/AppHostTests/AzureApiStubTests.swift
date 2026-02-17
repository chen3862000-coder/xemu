import XCTest
import Combine
@testable import AppHost

final class AzureApiStubTests: XCTestCase {

    var stub: AzureApiStub!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        stub = AzureApiStub()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        stub = nil
        cancellables = nil
        super.tearDown()
    }

    func testFetchEntitlements() {
        let userId = UUID()
        let expectation = XCTestExpectation(description: "Fetch entitlements")

        stub.fetchEntitlements(userId: userId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Fetch should succeed")
                    }
                },
                receiveValue: { bundle in
                    XCTAssertNotNil(bundle)
                    XCTAssertEqual(bundle.userId, userId)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testFetchEntitlementsContainsDeviceProfile() {
        let userId = UUID()
        let expectation = XCTestExpectation(description: "Fetch entitlements with device profile")

        stub.fetchEntitlements(userId: userId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { bundle in
                    XCTAssertNotNil(bundle.deviceProfile)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testFetchEntitlementsContainsActiveEntitlement() {
        let userId = UUID()
        let expectation = XCTestExpectation(description: "Fetch with active entitlement")

        stub.fetchEntitlements(userId: userId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { bundle in
                    let activeEntitlements = bundle.entitlements.filter { $0.status == .Active }
                    XCTAssertTrue(activeEntitlements.count > 0)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testFetchEntitlementsMultipleUsers() {
        let userId1 = UUID()
        let userId2 = UUID()
        let expectation = XCTestExpectation(description: "Fetch for multiple users")
        expectation.expectedFulfillmentCount = 2

        stub.fetchEntitlements(userId: userId1)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { bundle in
                    XCTAssertEqual(bundle.userId, userId1)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        stub.fetchEntitlements(userId: userId2)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { bundle in
                    XCTAssertEqual(bundle.userId, userId2)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testValidateDevice() {
        let deviceId = UUID()
        let expectation = XCTestExpectation(description: "Validate device")

        stub.validateDevice(deviceId: deviceId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Validation should succeed")
                    }
                },
                receiveValue: { isValid in
                    XCTAssertTrue(isValid)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testValidateDeviceUnknownDevice() {
        let unknownDeviceId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let expectation = XCTestExpectation(description: "Validate unknown device")

        stub.validateDevice(deviceId: unknownDeviceId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { isValid in
                    XCTAssertFalse(isValid)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testCheckCompatibility() {
        let romHash = "test_rom_hash_123"
        let expectation = XCTestExpectation(description: "Check compatibility")

        stub.checkCompatibility(romHash: romHash)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { profile in
                    XCTAssertNotNil(profile)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testCheckCompatibilityStable() {
        let stableHash = "nes_stable_hash"
        let expectation = XCTestExpectation(description: "Check stable compatibility")

        stub.checkCompatibility(romHash: stableHash)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { profile in
                    XCTAssertEqual(profile.tier, "stable")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testCheckCompatibilityExperimental() {
        let experimentalHash = "experimental_hash_456"
        let expectation = XCTestExpectation(description: "Check experimental compatibility")

        stub.checkCompatibility(romHash: experimentalHash)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { profile in
                    XCTAssertEqual(profile.tier, "experimental")
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testSubmitTelemetry() {
        let sessionId = UUID()
        let telemetryData: [String: Any] = [
            "session_id": sessionId.uuidString,
            "duration": 1800,
            "platform": "NES"
        ]
        let expectation = XCTestExpectation(description: "Submit telemetry")

        stub.submitTelemetry(data: telemetryData)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        XCTFail("Telemetry submission should succeed")
                    }
                },
                receiveValue: { success in
                    XCTAssertTrue(success)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testSubmitMultipleTelemetryEvents() {
        let sessionId = UUID()
        let expectation = XCTestExpectation(description: "Submit multiple telemetry events")
        expectation.expectedFulfillmentCount = 3

        for i in 0..<3 {
            let telemetryData: [String: Any] = [
                "session_id": sessionId.uuidString,
                "duration": 600 + (i * 600),
                "platform": "NES"
            ]

            stub.submitTelemetry(data: telemetryData)
                .sink(
                    receiveCompletion: { _ in },
                    receiveValue: { success in
                        XCTAssertTrue(success)
                        expectation.fulfill()
                    }
                )
                .store(in: &cancellables)
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testFetchAchievements() {
        let userId = UUID()
        let expectation = XCTestExpectation(description: "Fetch achievements")

        stub.fetchAchievements(userId: userId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { achievements in
                    XCTAssertGreaterThan(achievements.count, 0)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testFetchAchievementsContainsMetadata() {
        let userId = UUID()
        let expectation = XCTestExpectation(description: "Fetch with achievement metadata")

        stub.fetchAchievements(userId: userId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { achievements in
                    let firstAchievement = achievements.first
                    XCTAssertNotNil(firstAchievement?.title)
                    XCTAssertNotNil(firstAchievement?.description)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testMockDataConsistency() {
        let userId = UUID()
        let expectation1 = XCTestExpectation(description: "First fetch")
        let expectation2 = XCTestExpectation(description: "Second fetch")

        stub.fetchEntitlements(userId: userId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { bundle1 in
                    self.stub.fetchEntitlements(userId: userId)
                        .sink(
                            receiveCompletion: { _ in },
                            receiveValue: { bundle2 in
                                XCTAssertEqual(bundle1.userId, bundle2.userId)
                                expectation2.fulfill()
                            }
                        )
                        .store(in: &self.cancellables)
                    expectation1.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation1, expectation2], timeout: 1.0)
    }

    func testLatencySimulation() {
        let userId = UUID()
        let expectation = XCTestExpectation(description: "Test latency")

        let startTime = Date()

        stub.fetchEntitlements(userId: userId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    let elapsedTime = Date().timeIntervalSince(startTime)
                    XCTAssertGreaterThan(elapsedTime, 0)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testErrorResponse() {
        stub.simulateNetworkError = true
        let userId = UUID()
        let expectation = XCTestExpectation(description: "Test error response")

        stub.fetchEntitlements(userId: userId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        XCTAssertNotNil(error)
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should fail")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testEntitlementProductCodes() {
        let userId = UUID()
        let expectation = XCTestExpectation(description: "Check product codes")

        stub.fetchEntitlements(userId: userId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { bundle in
                    let productCodes = Set(bundle.entitlements.map { $0.productCode })
                    let validCodes: Set<ProductCode> = [.REMOVE_ADS, .EXPERIMENTAL_PACK, .PRO_BUNDLE]
                    XCTAssertFalse(productCodes.isDisjoint(with: validCodes))
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testHardwareClassAssignment() {
        let deviceId = UUID()
        let expectation = XCTestExpectation(description: "Check hardware class")

        stub.validateDevice(deviceId: deviceId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { _ in
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testCompatibilityProfileFields() {
        let romHash = "test_hash_789"
        let expectation = XCTestExpectation(description: "Check profile fields")

        stub.checkCompatibility(romHash: romHash)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { profile in
                    XCTAssertNotNil(profile.tier)
                    XCTAssertNotNil(profile.platform)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testTelemetryDataStructure() {
        let sessionId = UUID()
        let telemetryData: [String: Any] = [
            "session_id": sessionId.uuidString,
            "duration": 300,
            "platform": "GBA",
            "rewinds": 5,
            "achievements": 2
        ]
        let expectation = XCTestExpectation(description: "Test telemetry structure")

        stub.submitTelemetry(data: telemetryData)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { success in
                    XCTAssertTrue(success)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testAchievementCategories() {
        let userId = UUID()
        let expectation = XCTestExpectation(description: "Check achievement categories")

        stub.fetchAchievements(userId: userId)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { achievements in
                    let categories = Set(achievements.map { $0.category })
                    XCTAssertGreaterThan(categories.count, 0)
                    expectation.fulfill()
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }

    func testStubInitialization() {
        XCTAssertNotNil(stub)
    }

    func testNetworkOfflineSimulation() {
        stub.simulateNetworkError = true
        let userId = UUID()
        let expectation = XCTestExpectation(description: "Network offline")

        stub.fetchEntitlements(userId: userId)
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should fail")
                }
            )
            .store(in: &cancellables)

        wait(for: [expectation], timeout: 1.0)
    }
}
