import XCTest
@testable import Xemu

@MainActor
final class EmulatorCoreFactoryTests: XCTestCase {
    
    func testCreateCoreForNES() throws {
        let core = try EmulatorCoreFactory.createCore(for: .NES)
        XCTAssertNotNil(core)
        XCTAssertEqual(core.platform, .NES)
    }
    
    func testCreateCoreForGB() throws {
        let core = try EmulatorCoreFactory.createCore(for: .GB)
        XCTAssertNotNil(core)
        XCTAssertEqual(core.platform, .GB)
    }
    
    func testCreateCoreForGBC() throws {
        let core = try EmulatorCoreFactory.createCore(for: .GBC)
        XCTAssertNotNil(core)
        XCTAssertEqual(core.platform, .GB, "GBC uses GBCore which reports .GB as its native platform")
    }
    
    func testCreateCoreForGBA() throws {
        let core = try EmulatorCoreFactory.createCore(for: .GBA)
        XCTAssertNotNil(core)
        XCTAssertEqual(core.platform, .GBA)
    }
    
    func testCreateCoreForGenesis() throws {
        let core = try EmulatorCoreFactory.createCore(for: .GENESIS)
        XCTAssertNotNil(core)
        XCTAssertEqual(core.platform, .GENESIS)
    }
    
    func testCreateCoreForNDS() throws {
        let core = try EmulatorCoreFactory.createCore(for: .NDS)
        XCTAssertNotNil(core)
        XCTAssertEqual(core.platform, .NDS)
    }
    
    func testCreateCoreForPS1() throws {
        let core = try EmulatorCoreFactory.createCore(for: .PS1)
        XCTAssertNotNil(core)
        XCTAssertEqual(core.platform, .PS1)
    }
    
    func testIsPlatformSupported() {
        XCTAssertTrue(EmulatorCoreFactory.isPlatformSupported(.NES))
        XCTAssertTrue(EmulatorCoreFactory.isPlatformSupported(.GB))
        XCTAssertTrue(EmulatorCoreFactory.isPlatformSupported(.GBC))
        XCTAssertTrue(EmulatorCoreFactory.isPlatformSupported(.GBA))
        XCTAssertTrue(EmulatorCoreFactory.isPlatformSupported(.GENESIS))
        XCTAssertTrue(EmulatorCoreFactory.isPlatformSupported(.NDS))
        XCTAssertTrue(EmulatorCoreFactory.isPlatformSupported(.PS1))
    }
    
    func testSupportedPlatforms() {
        let platforms = EmulatorCoreFactory.supportedPlatforms()
        XCTAssertFalse(platforms.isEmpty)
        XCTAssertTrue(platforms.contains(.NES))
        XCTAssertTrue(platforms.contains(.GB))
        XCTAssertTrue(platforms.contains(.GBA))
        XCTAssertTrue(platforms.contains(.GENESIS))
        XCTAssertTrue(platforms.contains(.NDS))
        XCTAssertTrue(platforms.contains(.PS1))
    }
    
    func testAllCoresCanInitialize() throws {
        let platforms: [Platform] = [.NES, .GB, .GBC, .GBA, .GENESIS, .NDS, .PS1]
        for platform in platforms {
            let core = try EmulatorCoreFactory.createCore(for: platform)
            XCTAssertTrue(core.initialize(), "Core should initialize for \(platform)")
        }
    }
    
    func testAllCoresHavePlatformProperty() throws {
        let testCases: [(Platform, Platform)] = [
            (.NES, .NES),
            (.GB, .GB),
            (.GBC, .GB),  // GBC uses GBCore which reports .GB as native platform
            (.GBA, .GBA),
            (.GENESIS, .GENESIS),
            (.NDS, .NDS),
            (.PS1, .PS1)
        ]
        for (requestedPlatform, expectedPlatform) in testCases {
            let core = try EmulatorCoreFactory.createCore(for: requestedPlatform)
            XCTAssertEqual(core.platform, expectedPlatform, "Core platform should match for \(requestedPlatform)")
        }
    }
    
    func testCoreCanStartAndStop() throws {
        let core = try EmulatorCoreFactory.createCore(for: .NES)
        XCTAssertTrue(core.initialize())
        core.start()
        core.stop()
        core.cleanup()
    }
}
