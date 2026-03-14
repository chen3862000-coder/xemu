import XCTest
@testable import Xemu

final class CoverFeatureFlagsTests: XCTestCase {
    func testCustomCoverSyncIsDisabledByDefault() {
        XCTAssertFalse(CoverFeatureFlags.customCoverSyncEnabled)
    }
}
