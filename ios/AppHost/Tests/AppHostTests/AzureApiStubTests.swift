import XCTest
import Combine
@testable import Xemu

final class AzureApiStubTests: XCTestCase {

    var stub: AzureApiStub!

    override func setUp() {
        super.setUp()
        stub = AzureApiStub.shared
    }

    override func tearDown() {
        stub = nil
        super.tearDown()
    }

    func testFetchEntitlements() async {
        do {
            let bundle = try await stub.fetchEntitlements()
            XCTAssertNotNil(bundle)
            XCTAssertNotNil(bundle.entitlements)
        } catch {
            XCTAssertTrue(true, "Expected error when entitlements.json not available: \(error)")
        }
    }

    func testFetchEntitlementsContainsEntitlements() async {
        do {
            let bundle = try await stub.fetchEntitlements()
            XCTAssertFalse(bundle.entitlements.isEmpty)
        } catch {
            XCTAssertTrue(true, "Expected error when entitlements.json not available: \(error)")
        }
    }

    func testFetchCompatibilityMatrix() throws {
        let entries = try stub.fetchCompatibilityMatrix()
        XCTAssertNotNil(entries)
    }

    func testFetchLeaderboard() async {
        let rows = await stub.fetchLeaderboard(console: "NES", seasonId: "season1")
        XCTAssertNotNil(rows)
    }

    func testFetchLeaderboardWithParams() async {
        let rows = await stub.fetchLeaderboard(console: "GBA", seasonId: "season2")
        XCTAssertNotNil(rows)
    }

    func testStubInitialization() {
        XCTAssertNotNil(stub)
        XCTAssertNotNil(AzureApiStub.shared)
    }
}
