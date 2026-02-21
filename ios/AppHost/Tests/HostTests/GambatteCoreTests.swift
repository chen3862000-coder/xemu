import XCTest
import Combine
@testable import Host
import XemuCoreBridge

@available(iOS 17.0, *)
final class GambatteCoreTests: XCTestCase {
    
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = []
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    func testGambatteCoreInitialization() {
        let core = GambatteCore()
        
        XCTAssertEqual(core.frameWidth, 160)
        XCTAssertEqual(core.frameHeight, 144)
        XCTAssertEqual(core.preferredAudioSampleRate, 48000)
        XCTAssertEqual(core.clockSpeedMhz, 4.194, accuracy: 0.01)
        XCTAssertEqual(core.emulatorType, .gb)
        XCTAssertEqual(core.systemType, .gb)
    }
    
    func testGambatteCoreSupportsGBAndGBC() {
        let core = GambatteCore()
        
        XCTAssertTrue(core.supportedSystems.contains(.gb))
        XCTAssertTrue(core.supportedSystems.contains(.gbc))
    }
    
    func testGambatteCoreInitializationState() {
        let core = GambatteCore()
        
        XCTAssertFalse(core.isInitialized)
        XCTAssertNil(core.currentROM)
        XCTAssertTrue(core.canLoadROM(ofType: .gb))
        XCTAssertTrue(core.canLoadROM(ofType: .gbc))
        XCTAssertFalse(core.canLoadROM(ofType: .gba))
    }
    
    func testFrameBufferGeneration() {
        let core = GambatteCore()
        let frameBuffer = core.getFrameBuffer()
        
        XCTAssertEqual(frameBuffer.count, 160 * 144)
        XCTAssertEqual(frameBuffer.count, 23040)
    }
    
    func testFrameBufferDimensions() {
        let core = GambatteCore()
        
        XCTAssertEqual(core.frameWidth, 160)
        XCTAssertEqual(core.frameHeight, 144)
    }
    
    func testAudioSampleRate() {
        let core = GambatteCore()
        
        XCTAssertEqual(core.preferredAudioSampleRate, 48000)
    }
    
    func testClockSpeed() {
        let core = GambatteCore()
        
        XCTAssertEqual(core.clockSpeedMhz, 4.194, accuracy: 0.001)
    }
    
    func testInputMappingGB() {
        let core = GambatteCore()
        
        let mappings: [(GamepadButton, Int)] = [
            (.a, 1),
            (.b, 2),
            (.select, 3),
            (.start, 4),
            (.up, 5),
            (.down, 6),
            (.left, 7),
            (.right, 8)
        ]
        
        for (button, expectedMapping) in mappings {
            XCTAssertEqual(core.mapGamepadButton(button), expectedMapping)
        }
    }
    
    func testInvalidROMFileFormat() {
        let core = GambatteCore()
        let invalidURL = URL(fileURLWithPath: "/tmp/test.txt")
        
        XCTAssertThrowsError(try core.loadROM(from: invalidURL)) { error in
            XCTAssertEqual(error as? EmulatorCoreError, .invalidROMFormat)
        }
    }
    
    func testStatePersistenceWithoutLoad() {
        let core = GambatteCore()
        
        do {
            _ = try core.saveState()
            XCTFail("Should throw error when saving state before loading ROM")
        } catch {
            XCTAssertEqual(error as? EmulatorCoreError, .notInitialized)
        }
    }
    
    func testLoadStateWithoutInitialization() {
        let core = GambatteCore()
        let invalidState = Data()
        
        XCTAssertThrowsError(try core.loadState(from: invalidState)) { error in
            XCTAssertEqual(error as? EmulatorCoreError, .notInitialized)
        }
    }
    
    func testFrameGenerationPerformance() {
        let core = GambatteCore()
        let frameBuffer = UnsafeMutablePointer<UInt32>.allocate(capacity: 160 * 144)
        defer { frameBuffer.deallocate() }
        
        measure {
            _ = core.generateFrame(into: frameBuffer)
        }
    }
    
    func testAudioBufferSize() {
        let core = GambatteCore()
        let bufferSize = 2048
        let audioBuffer = UnsafeMutablePointer<Float>.allocate(capacity: bufferSize)
        defer { audioBuffer.deallocate() }
        
        let samplesGenerated = core.generateAudioSamples(into: audioBuffer, count: bufferSize)
        
        XCTAssertEqual(samplesGenerated, bufferSize)
    }
    
    func testResetClearsState() {
        let core = GambatteCore()
        
        XCTAssertFalse(core.isInitialized)
        core.reset()
        XCTAssertFalse(core.isInitialized)
    }
    
    func testMultipleInputCombinations() {
        let core = GambatteCore()
        
        let combinations: [(GamepadButton, GamepadButton)] = [
            (.up, .left),
            (.down, .right),
            (.a, .b),
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
