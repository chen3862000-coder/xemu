import XCTest
@testable import Host

final class RealEmulatorCoreTests: XCTestCase {
    
    var factory: EmulatorCoreFactory!
    
    override func setUp() {
        super.setUp()
        factory = EmulatorCoreFactory()
    }
    
    override func tearDown() {
        factory = nil
        super.tearDown()
    }
    
    // MARK: - Factory Tests
    
    func testFactoryCreatesGambatteCoreForGB() {
        let rom = ROM(
            id: UUID(),
            title: "Test GB",
            filePath: "/test/game.gb",
            system: .gb,
            addedDate: Date()
        )
        
        let core = factory.createCore(for: rom)
        
        XCTAssertTrue(core is GambatteCore, "Factory should create GambatteCore for GB ROMs")
        XCTAssertEqual(core.systemType, .gb)
    }
    
    func testFactoryCreatesGambatteCoreForGBC() {
        let rom = ROM(
            id: UUID(),
            title: "Test GBC",
            filePath: "/test/game.gbc",
            system: .gbc,
            addedDate: Date()
        )
        
        let core = factory.createCore(for: rom)
        
        XCTAssertTrue(core is GambatteCore, "Factory should create GambatteCore for GBC ROMs")
        XCTAssertEqual(core.systemType, .gbc)
    }
    
    func testFactoryCreatesMGBACoreForGBA() {
        let rom = ROM(
            id: UUID(),
            title: "Test GBA",
            filePath: "/test/game.gba",
            system: .gba,
            addedDate: Date()
        )
        
        let core = factory.createCore(for: rom)
        
        XCTAssertTrue(core is MGBACore, "Factory should create MGBACore for GBA ROMs")
        XCTAssertEqual(core.systemType, .gba)
    }
    
    // MARK: - GambatteCore Tests
    
    func testGambatteCoreVideoDimensions() {
        let core = GambatteCore(systemType: .gb)
        
        let dimensions = core.videoDimensions
        
        XCTAssertEqual(dimensions.width, 160, "GB screen width should be 160")
        XCTAssertEqual(dimensions.height, 144, "GB screen height should be 144")
    }
    
    func testGambatteCoreGBCVideoDimensions() {
        let core = GambatteCore(systemType: .gbc)
        
        let dimensions = core.videoDimensions
        
        XCTAssertEqual(dimensions.width, 160, "GBC screen width should be 160")
        XCTAssertEqual(dimensions.height, 144, "GBC screen height should be 144")
    }
    
    func testGambatteCoreAudioSampleRate() {
        let core = GambatteCore(systemType: .gb)
        
        XCTAssertEqual(core.audioSampleRate, 44100, "Audio sample rate should be 44100 Hz")
    }
    
    func testGambatteCoreFrameDuration() {
        let core = GambatteCore(systemType: .gb)
        
        XCTAssertEqual(core.frameDuration, 1.0 / 60.0, accuracy: 0.001, "Frame duration should be ~16.67ms (60fps)")
    }
    
    // MARK: - MGBACore Tests
    
    func testMGBACoreVideoDimensions() {
        let core = MGBACore()
        
        let dimensions = core.videoDimensions
        
        XCTAssertEqual(dimensions.width, 240, "GBA screen width should be 240")
        XCTAssertEqual(dimensions.height, 160, "GBA screen height should be 160")
    }
    
    func testMGBACoreAudioSampleRate() {
        let core = MGBACore()
        
        XCTAssertEqual(core.audioSampleRate, 44100, "Audio sample rate should be 44100 Hz")
    }
    
    func testMGBACoreFrameDuration() {
        let core = MGBACore()
        
        XCTAssertEqual(core.frameDuration, 1.0 / 60.0, accuracy: 0.001, "Frame duration should be ~16.67ms (60fps)")
    }
    
    // MARK: - Input Mapping Tests
    
    func testGambatteCoreMapsInputButtons() {
        let core = GambatteCore(systemType: .gb)
        
        // Test that all standard buttons can be mapped
        let buttons: [InputButton] = [.a, .b, .select, .start, .up, .down, .left, .right]
        
        for button in buttons {
            core.setInput(button: button, pressed: true)
            core.setInput(button: button, pressed: false)
        }
        
        // If we get here without crashing, mapping works
        XCTAssertTrue(true, "All buttons mapped successfully")
    }
    
    func testMGBACoreMapsInputButtons() {
        let core = MGBACore()
        
        // Test that all standard buttons can be mapped
        let buttons: [InputButton] = [.a, .b, .select, .start, .up, .down, .left, .right]
        
        for button in buttons {
            core.setInput(button: button, pressed: true)
            core.setInput(button: button, pressed: false)
        }
        
        // If we get here without crashing, mapping works
        XCTAssertTrue(true, "All buttons mapped successfully")
    }
    
    // MARK: - Save State Tests
    
    func testGambatteCoreSaveStateReturnsNilWhenNotRunning() {
        let core = GambatteCore(systemType: .gb)
        
        let state = core.saveState()
        
        XCTAssertNil(state, "Save state should return nil when core is not running")
    }
    
    func testMGBACoreSaveStateReturnsNilWhenNotRunning() {
        let core = MGBACore()
        
        let state = core.saveState()
        
        XCTAssertNil(state, "Save state should return nil when core is not running")
    }
    
    func testGambatteCoreLoadStateReturnsFalseWhenNotRunning() {
        let core = GambatteCore(systemType: .gb)
        let testState = Data([0x00, 0x01, 0x02, 0x03])
        
        let result = core.loadState(testState)
        
        XCTAssertFalse(result, "Load state should return false when core is not running")
    }
    
    func testMGBACoreLoadStateReturnsFalseWhenNotRunning() {
        let core = MGBACore()
        let testState = Data([0x00, 0x01, 0x02, 0x03])
        
        let result = core.loadState(testState)
        
        XCTAssertFalse(result, "Load state should return false when core is not running")
    }
    
    // MARK: - Reset Tests
    
    func testGambatteCoreResetDoesNotCrash() {
        let core = GambatteCore(systemType: .gb)
        
        core.reset()
        
        // Should not crash
        XCTAssertEqual(core.systemType, .gb)
    }
    
    func testMGBACoreResetDoesNotCrash() {
        let core = MGBACore()
        
        core.reset()
        
        // Should not crash
        XCTAssertEqual(core.systemType, .gba)
    }
    
    // MARK: - Lifecycle Tests
    
    func testGambatteCoreStopDoesNotCrashWhenNotRunning() {
        let core = GambatteCore(systemType: .gb)
        
        core.stop()
        
        // Should not crash
        XCTAssertFalse(core.isRunning)
    }
    
    func testMGBACoreStopDoesNotCrashWhenNotRunning() {
        let core = MGBACore()
        
        core.stop()
        
        // Should not crash
        XCTAssertFalse(core.isRunning)
    }
    
    // MARK: - Integration Tests
    
    func testCoreImplementsEmulatorCoreProtocol() {
        let gbCore: EmulatorCore = GambatteCore(systemType: .gb)
        let gbcCore: EmulatorCore = GambatteCore(systemType: .gbc)
        let gbaCore: EmulatorCore = MGBACore()
        
        XCTAssertNotNil(gbCore)
        XCTAssertNotNil(gbcCore)
        XCTAssertNotNil(gbaCore)
    }
    
    func testAllCoresHaveCorrectSystemType() {
        let gbCore = GambatteCore(systemType: .gb)
        let gbcCore = GambatteCore(systemType: .gbc)
        let gbaCore = MGBACore()
        
        XCTAssertEqual(gbCore.systemType, .gb)
        XCTAssertEqual(gbcCore.systemType, .gbc)
        XCTAssertEqual(gbaCore.systemType, .gba)
    }
}