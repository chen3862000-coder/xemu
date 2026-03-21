import XCTest
@testable import Xemu

@MainActor
final class EmulatorSessionCoreTests: XCTestCase {
    func testFrameSkipEmitsEveryNthFrameWhileAudioStillStreams() {
        let session = EmulatorSession()
        let core = MockEmulatorCore()
        let delegate = MockRenderDelegate()

        session.loadCore(core)
        session.renderDelegate = delegate
        session.setRenderFrameSkip(1)
        session.start()

        for _ in 0..<5 {
            session.stepOnce()
        }

        XCTAssertEqual(core.frameCallCount, 5)
        XCTAssertEqual(delegate.renderedFrames.count, 2)
        XCTAssertEqual(delegate.audioEventCount, 5)
    }

    func testInvalidFrameBufferIsDroppedBeforeRenderDelegate() {
        let session = EmulatorSession()
        let core = MockEmulatorCore()
        let delegate = MockRenderDelegate()
        core.frameBufferInfo = FrameBufferInfo(data: Data(count: 8), width: 4, height: 4, pitch: 16)

        session.loadCore(core)
        session.renderDelegate = delegate
        session.start()
        session.stepOnce()

        XCTAssertTrue(delegate.renderedFrames.isEmpty)
        XCTAssertEqual(delegate.audioEventCount, 1)
    }

    func testFramePacerCatchesUpAfterDroppedDraw() {
        var pacer = EmulationFramePacer()

        XCTAssertEqual(pacer.stepsToRun(at: 0), 1)
        XCTAssertEqual(pacer.stepsToRun(at: 1.0 / 120.0), 0)
        XCTAssertEqual(pacer.stepsToRun(at: 1.0 / 60.0), 1)
        XCTAssertEqual(pacer.stepsToRun(at: 1.0 / 60.0 + (1.0 / 30.0)), 2)
    }

    func testFramePacerCapsCatchUpWorkAfterLongStall() {
        var pacer = EmulationFramePacer(maxCatchUpSteps: 3, maxDelta: 0.25)

        XCTAssertEqual(pacer.stepsToRun(at: 0), 1)
        XCTAssertEqual(pacer.stepsToRun(at: 0.25), 3)
        XCTAssertEqual(pacer.stepsToRun(at: 0.25 + (1.0 / 60.0)), 1)
    }
}

private final class MockEmulatorCore: EmulatorCore {
    let platform: Platform = .GB
    var frameCallCount = 0
    var frameBufferInfo = FrameBufferInfo(
        data: Data(count: 160 * 144 * 4),
        width: 160,
        height: 144,
        pitch: 160 * 4
    )
    var audioSamples = Data(count: 512)

    func initialize() -> Bool { true }
    func loadROM(romPath: String) -> Bool { true }
    func frame() -> Bool {
        frameCallCount += 1
        return true
    }
    func getFrameBuffer() -> Data? { frameBufferInfo.data }
    func getFrameBufferInfo() -> FrameBufferInfo? { frameBufferInfo }
    func getAudioSamples() -> Data? { audioSamples }
    func getAudioSampleRate() -> Int { 44_100 }
}

private final class MockRenderDelegate: EmulatorRenderDelegate {
    var renderedFrames: [FrameBufferInfo] = []
    var audioEventCount = 0

    func emulatorDidRenderFrameBufferInfo(_ frameBufferInfo: FrameBufferInfo) {
        renderedFrames.append(frameBufferInfo)
    }

    func emulatorDidGenerateAudio(samples: Data?, sampleRate: Int) {
        audioEventCount += 1
    }
}
