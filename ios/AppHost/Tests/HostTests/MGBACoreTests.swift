import XCTest
import Combine
@testable import Host
import XemuCoreBridge

@available(iOS 17.0, *)
final class MGBACoreTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    func testMGBACoreInitialization() {
        let core = mGBACore()
        
        XCTAssertEqual(core.frameWidth, 240)
        XCTAssertEqual(core.frameHeight, 160)
        XCTAssertEqual(core.preferredAudioSampleRate, 48000)
        XCTAssertEqual(core.clockSpeedMhz, 16.78, accuracy: 0.01)
        XCTAssertEqual(core.emulatorType, .gba)
        XCTAssertEqual(core.systemType, .gba)
    }
    
    func testMGBACoreSupportsOnlyGBA() {
        let core = mGBACore()
        
        XCTAssertTrue(core.supportedSystems.contains(.gba))
        XCTAssertFalse(core.supportedSystems.contains(.gb))
        XCTAssertFalse(core.supportedSystems.contains(.gbc))
    }
    
    func testMGBACoreInitializationState() {
        let core = mGBACore()
        
        XCTAssertFalse(core.isInitialized)
        XCTAssertNil(core.currentROM)
        XCTAssertTrue(core.canLoadROM(ofType: .gba))
        XCTAssertFalse(core.canLoadROM(ofType: .gb))
        XCTAssertFalse(core.canLoadROM(ofType: .gbc))
    }
    
    func testFrameBufferGeneration() {
        let core = mGBACore()
        let frameBuffer = core.getFrameBuffer()
        
        XCTAssertEqual(frameBuffer.count, 240 * 160)
        XCTAssertEqual(frameBuffer.count, 38400)
    }
    
    func testFrameBufferDimensions() {
        let core = mGBACore()
        
        XCTAssertEqual(core.frameWidth, 240)
        XCTAssertEqual(core.frameHeight, 160)
    }
    
    func testAudioSampleRate() {
        let core = mGBACore()
        
        XCTAssertEqual(core.preferredAudioSampleRate, 48000)
    }
    
    func testClockSpeed() {
        let core = mGBACore()
        
        XCTAssertEqual(core.clockSpeedMhz, 16.78, accuracy: 0.01)
    }
    
    func testInputMappingGBA() {
        let core = mGBACore()
        
        let mappings: [(GamepadButton, Int)] = [
            (.a, 1),
            (.b, 2),
            (.select, 3),
            (.start, 4),
            (.up, 5),
            (.down, 6),
            (.left, 7),
            (.right, 8),
            (.l, 9),
            (.r, 10)
        ]
        
        for (button, expectedMapping) in mappings {
            XCTAssertEqual(core.mapGamepadButton(button), expectedMapping)
        }
    }
    
    func testInvalidROMFileFormat() {
        let core = mGBACore()
        let invalidURL = URL(fileURLWithPath: "/tmp/test.txt")
        
        XCTAssertThrowsError(try core.loadROM(from: invalidURL)) { error in
            XCTAssertEqual(error as? EmulatorCoreError, .invalidROMFormat)
        }
    }
    
    func testStatePersistenceWithoutLoad() {
        let core = mGBACore()
        
        do {
            _ = try core.saveState()
            XCTFail("Should throw error when saving state before loading ROM")
        } catch {
            XCTAssertEqual(error as? EmulatorCoreError, .notInitialized)
        }
    }
    
    func testLoadStateWithoutInitialization() {
        let core = mGBACore()
        let invalidState = Data()
        
        XCTAssertThrowsError(try core.loadState(from: invalidState)) { error in
            XCTAssertEqual(error as? EmulatorCoreError, .notInitialized)
        }
    }
    
    func testFrameGenerationPerformance() {
        let core = mGBACore()
        let frameBuffer = UnsafeMutablePointer<UInt32>.allocate(capacity: 240 * 160)
        defer { frameBuffer.deallocate() }
        
        measure {
            _ = core.generateFrame(into: frameBuffer)
        }
    }
    
    func testAudioBufferSize() {
        let core = mGBACore()
        let bufferSize = 2048
        let audioBuffer = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize)
        defer { audioBuffer.deallocate() }
        
        let samplesGenerated = core.generateAudioSamples(into: audioBuffer, count: bufferSize)
        
        XCTAssertEqual(samplesGenerated, bufferSize)
    }
    
    func testResetClearsState() {
        let core = mGBACore()
        
        XCTAssertFalse(core.isInitialized)
        core.reset()
        XCTAssertFalse(core.isInitialized)
    }
    
    func testLAndRButtonMapping() {
        let core = mGBACore()
        
        let lMapping = core.mapGamepadButton(.l)
        let rMapping = core.mapGamepadButton(.r)
        
        XCTAssertGreaterThan(lMapping, 0)
        XCTAssertGreaterThan(rMapping, 0)
        XCTAssertNotEqual(lMapping, rMapping)
    }
    
    func testMultipleInputCombinations() {
        let core = mGBACore()
        
        let combinations: [(GamepadButton, GamepadButton)] = [
            (.up, .left),
            (.down, .right),
            (.a, .b),
            (.l, .r),
            (.start, .select)
        ]
        
        for (button1, button2) in combinations {
            let mapping1 = core.mapGamepadButton(button1)
            let mapping2 = core.mapGamepadButton(button2)
            XCTAssertGreaterThan(mapping1, 0)
            XCTAssertGreaterThan(mapping2, 0)
            XCTAssertNotEqual(mapping1, mapping2)
        }
    }
}
