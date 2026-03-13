import XCTest
@testable import Xemu

final class GBCoreAudioTests: XCTestCase {
    func testDefaultAudioSampleRateMatchesBridgeContract() {
        let core = GBCore()

        XCTAssertEqual(core.getAudioSampleRate(), 44_100)
        XCTAssertEqual(GBCore.nativeAudioSampleRate, 44_100)
    }
}
