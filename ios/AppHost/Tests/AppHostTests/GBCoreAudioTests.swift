import XCTest
@testable import Xemu

final class GBCoreAudioTests: XCTestCase {
    func testDefaultAudioSampleRateMatchesBridgeContract() {
        let core = GBCore()

        XCTAssertEqual(core.getAudioSampleRate(), 65_536)
        XCTAssertEqual(GBCore.nativeAudioSampleRate, 65_536)
    }
}
