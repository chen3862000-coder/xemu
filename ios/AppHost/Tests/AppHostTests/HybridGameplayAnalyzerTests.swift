import XCTest
@testable import Xemu

final class HybridGameplayAnalyzerTests: XCTestCase {
    func testWithoutMemoryEventsReturnsUnknownAndNoGameplayEvents() {
        let analyzer = HybridGameplayAnalyzer()
        let result = analyzer.analyze(
            frameBufferInfo: makeFrame(width: 240, height: 160),
            liveMemorySample: nil,
            profile: .sma2SuperMarioWorld,
            saveStateData: nil,
            platform: .GBA,
            gameTitle: "Super Mario Advance 2: Super Mario World",
            romHash: "super_mario_advance_2"
        )

        XCTAssertEqual(result.detectionMethod, .unknown)
        XCTAssertTrue(result.events.isEmpty)
    }

    private func makeFrame(width: Int, height: Int) -> FrameBufferInfo {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for index in stride(from: 0, to: bytes.count, by: 4) {
            bytes[index] = 0x20
            bytes[index + 1] = 0xC0
            bytes[index + 2] = 0xE0
            bytes[index + 3] = 0xFF
        }

        return FrameBufferInfo(
            data: Data(bytes),
            width: width,
            height: height,
            pitch: width * 4
        )
    }
}
