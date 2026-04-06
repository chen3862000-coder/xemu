import XCTest
@testable import Xemu

@MainActor
final class EmulatorSessionIntegrationTests: XCTestCase {
    func testSessionLifecycleTransitionsTrackRunningAndPausedState() {
        let session = EmulatorSession()
        let core = TestEmulatorCore()

        session.loadCore(core)

        session.start()
        XCTAssertTrue(session.isRunning)
        XCTAssertFalse(session.isPaused)
        XCTAssertEqual(core.startCallCount, 1)

        session.pause()
        XCTAssertTrue(session.isRunning)
        XCTAssertTrue(session.isPaused)
        XCTAssertEqual(core.pauseCallCount, 1)

        session.resume()
        XCTAssertTrue(session.isRunning)
        XCTAssertFalse(session.isPaused)
        XCTAssertEqual(core.resumeCallCount, 1)

        session.stop()
        XCTAssertFalse(session.isRunning)
        XCTAssertFalse(session.isPaused)
        XCTAssertEqual(core.stopCallCount, 1)
    }

    func testStepOnceDeliversFrameBufferAndAudioToRenderDelegate() {
        let session = EmulatorSession()
        let core = TestEmulatorCore()
        let delegate = TestRenderDelegate()

        session.loadCore(core)
        session.renderDelegate = delegate
        session.start()

        session.stepOnce()

        XCTAssertEqual(core.frameCallCount, 1)
        XCTAssertEqual(delegate.renderedFrames.count, 1)
        XCTAssertEqual(delegate.renderedFrames.first?.width, 160)
        XCTAssertEqual(delegate.renderedAudio.count, 1)
        XCTAssertEqual(delegate.renderedAudio.first?.sampleRate, 32_768)
        XCTAssertEqual(delegate.renderedAudio.first?.samples, core.audioSamples)
    }

    func testRenderFrameSkipSuppressesIntermediateFrames() {
        let session = EmulatorSession()
        let core = TestEmulatorCore()
        let delegate = TestRenderDelegate()

        session.loadCore(core)
        session.renderDelegate = delegate
        session.setRenderFrameSkip(1)
        session.start()

        session.stepOnce()
        XCTAssertTrue(delegate.renderedFrames.isEmpty)
        XCTAssertEqual(delegate.renderedAudio.count, 1)

        session.stepOnce()
        XCTAssertEqual(delegate.renderedFrames.count, 1)
        XCTAssertEqual(delegate.renderedAudio.count, 2)
    }

    func testSaveAndLoadStateRoundTripsThroughCore() throws {
        let session = EmulatorSession()
        let core = TestEmulatorCore()
        let savedState = Data([0xDE, 0xAD, 0xBE, 0xEF])
        core.savedState = savedState
        session.loadCore(core)

        let result = try session.saveState(to: 0)
        XCTAssertEqual(result, savedState)

        try session.loadState(from: savedState)
        XCTAssertEqual(core.lastLoadedState, savedState)
    }

    func testStateOperationsThrowWithoutLoadedCore() {
        let session = EmulatorSession()

        XCTAssertThrowsError(try session.saveState(to: 0)) { error in
            XCTAssertEqual(error as? EmulatorSessionError, .noCoreLoaded)
        }

        XCTAssertThrowsError(try session.loadState(from: Data([1, 2, 3]))) { error in
            XCTAssertEqual(error as? EmulatorSessionError, .noCoreLoaded)
        }
    }

    func testCleanupStopsAndReleasesCore() {
        let session = EmulatorSession()
        let core = TestEmulatorCore()

        session.loadCore(core)
        session.start()
        session.cleanup()

        XCTAssertFalse(session.isRunning)
        XCTAssertFalse(session.isPaused)
        XCTAssertNil(session.core)
        XCTAssertEqual(core.stopCallCount, 1)
        XCTAssertEqual(core.cleanupCallCount, 1)
    }
}

private final class TestEmulatorCore: EmulatorCore {
    let platform: Platform = .GBA

    var startCallCount = 0
    var pauseCallCount = 0
    var resumeCallCount = 0
    var stopCallCount = 0
    var cleanupCallCount = 0
    var frameCallCount = 0
    var savedState = Data([0x01, 0x02, 0x03])
    var lastLoadedState: Data?
    let audioSamples = Data([0x10, 0x20, 0x30, 0x40])

    func initialize() -> Bool { true }
    func loadROM(romPath: String) -> Bool { true }

    func start() {
        startCallCount += 1
    }

    func pause() {
        pauseCallCount += 1
    }

    func resume() {
        resumeCallCount += 1
    }

    func frame() -> Bool {
        frameCallCount += 1
        return true
    }

    func stop() {
        stopCallCount += 1
    }

    func cleanup() {
        cleanupCallCount += 1
    }

    func getFrameBuffer() -> Data? {
        makeFrameBuffer().data
    }

    func getFrameBufferInfo() -> FrameBufferInfo? {
        makeFrameBuffer()
    }

    func getAudioSamples() -> Data? {
        audioSamples
    }

    func getAudioSampleRate() -> Int {
        32_768
    }

    func saveState() -> Data? {
        savedState
    }

    func loadState(_ state: Data) -> Bool {
        lastLoadedState = state
        return true
    }

    func exportBatterySave() -> Data? {
        nil
    }

    func importBatterySave(_ data: Data) -> Bool {
        true
    }

    func setInput(_ inputType: Int, value: Float) {}

    func reset() {}

    private func makeFrameBuffer() -> FrameBufferInfo {
        let width = 160
        let height = 144
        let pitch = width * 4
        let data = Data(repeating: 0x7F, count: pitch * height)
        return FrameBufferInfo(data: data, width: width, height: height, pitch: pitch)
    }
}

@MainActor
private final class TestRenderDelegate: EmulatorRenderDelegate {
    struct AudioEvent {
        let samples: Data?
        let sampleRate: Int
    }

    var renderedFrames: [FrameBufferInfo] = []
    var renderedAudio: [AudioEvent] = []

    func emulatorDidRenderFrameBufferInfo(_ frameBufferInfo: FrameBufferInfo) {
        renderedFrames.append(frameBufferInfo)
    }

    func emulatorDidGenerateAudio(samples: Data?, sampleRate: Int) {
        renderedAudio.append(AudioEvent(samples: samples, sampleRate: sampleRate))
    }
}
