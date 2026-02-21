import XCTest
import Combine
@testable import Xemu

@MainActor
final class EmulatorSessionTests: XCTestCase {
    
    var session: EmulatorSession!
    var cancellables = Set<AnyCancellable>()
    
    override func setUp() {
        super.setUp()
        session = EmulatorSession()
    }
    
    override func tearDown() {
        session = nil
        super.tearDown()
    }
    
    func testSessionInitialization() {
        XCTAssertFalse(session.isRunning)
        XCTAssertFalse(session.isPaused)
        XCTAssertEqual(session.currentFrameRate, 0)
    }
    
    func testLoadCore() {
        let core = GBCore()
        session.loadCore(core)
        
        XCTAssertNotNil(session.core)
    }
    
    func testStartWithoutCore() {
        session.start()
        
        XCTAssertFalse(session.isRunning)
    }
    
    func testStartWithCore() {
        let core = GBCore()
        session.loadCore(core)
        session.start()
        
        XCTAssertTrue(session.isRunning)
        XCTAssertFalse(session.isPaused)
    }
    
    func testPauseResume() {
        let core = GBCore()
        session.loadCore(core)
        session.start()
        
        session.pause()
        XCTAssertTrue(session.isPaused)
        XCTAssertTrue(session.isRunning)
        
        session.resume()
        XCTAssertFalse(session.isPaused)
    }
    
    func testStop() {
        let core = GBCore()
        session.loadCore(core)
        session.start()
        
        session.stop()
        
        XCTAssertFalse(session.isRunning)
        XCTAssertFalse(session.isPaused)
    }
    
    func testGetVideoInfoWithoutCore() {
        let info = session.getVideoInfo()
        
        XCTAssertNil(info)
    }
    
    func testGetVideoInfoWithCore() {
        let core = GBCore()
        session.loadCore(core)
        
        let info = session.getVideoInfo()
        
        XCTAssertNotNil(info)
        if let info = info {
            XCTAssertEqual(info.width, 160)
            XCTAssertEqual(info.height, 144)
            XCTAssertEqual(info.pitch, 640)
        }
    }
    
    func testStepOnce() {
        let core = GBCore()
        session.loadCore(core)
        session.start()
        
        session.stepOnce()
        
        XCTAssertTrue(session.isRunning)
    }
    
    func testFrameRateTracking() {
        let core = GBCore()
        session.loadCore(core)
        session.start()
        
        for _ in 0..<60 {
            session.stepOnce()
        }
        
        XCTAssertGreaterThanOrEqual(session.currentFrameRate, 0)
    }
    
    func testMultipleStartCalls() {
        let core = GBCore()
        session.loadCore(core)
        
        session.start()
        let firstRunning = session.isRunning
        
        session.start()
        
        XCTAssertEqual(firstRunning, session.isRunning)
    }
    
    func testPauseWithoutStart() {
        session.pause()
        
        XCTAssertFalse(session.isRunning)
    }
    
    func testResumeWithoutStart() {
        session.resume()
        
        XCTAssertFalse(session.isRunning)
    }
    
    func testStopWithoutStart() {
        session.stop()
        
        XCTAssertFalse(session.isRunning)
    }
    
    func testInputBusAttachment() {
        let inputBus = InputBus()
        session.inputBus = inputBus
        
        XCTAssertEqual(session.inputBus, inputBus)
    }
    
    func testRenderDelegateAttachment() {
        class MockRenderDelegate: EmulatorRenderDelegate {
            var frameCount = 0
            func emulatorDidRender(frameBuffer: Data?) {
                frameCount += 1
            }
            func emulatorDidGenerateAudio(samples: Data) {}
        }
        
        let delegate = MockRenderDelegate()
        session.renderDelegate = delegate
        
        XCTAssertNotNil(session.renderDelegate)
    }
}
