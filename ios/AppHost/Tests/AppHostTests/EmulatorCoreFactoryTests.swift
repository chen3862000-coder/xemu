import XCTest
@testable import Xemu

@MainActor
final class EmulatorCoreFactoryTests: XCTestCase {
    
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
    
    func testCreateCoreForNDS() throws {
        let core = try EmulatorCoreFactory.createCore(for: .NDS)
        XCTAssertNotNil(core)
        XCTAssertEqual(core.platform, .NDS)
    }
    
    func testIsPlatformSupported() {
        XCTAssertTrue(EmulatorCoreFactory.isPlatformSupported(.GB))
        XCTAssertTrue(EmulatorCoreFactory.isPlatformSupported(.GBC))
        XCTAssertTrue(EmulatorCoreFactory.isPlatformSupported(.GBA))
        XCTAssertTrue(EmulatorCoreFactory.isPlatformSupported(.NDS))
        XCTAssertFalse(EmulatorCoreFactory.isPlatformSupported(.NES))
        XCTAssertFalse(EmulatorCoreFactory.isPlatformSupported(.GENESIS))
        XCTAssertFalse(EmulatorCoreFactory.isPlatformSupported(.PS1))
    }
    
    func testSupportedPlatforms() {
        let platforms = EmulatorCoreFactory.supportedPlatforms()
        XCTAssertFalse(platforms.isEmpty)
        XCTAssertTrue(platforms.contains(.GB))
        XCTAssertTrue(platforms.contains(.GBA))
        XCTAssertTrue(platforms.contains(.NDS))
        XCTAssertFalse(platforms.contains(.NES))
        XCTAssertFalse(platforms.contains(.GENESIS))
        XCTAssertFalse(platforms.contains(.PS1))
    }
    
    func testAllCoresCanInitialize() throws {
        let platforms: [Platform] = [.GB, .GBC, .GBA, .NDS]
        for platform in platforms {
            let core = try EmulatorCoreFactory.createCore(for: platform)
            XCTAssertTrue(core.initialize(), "Core should initialize for \(platform)")
        }
    }
    
    func testAllCoresHavePlatformProperty() throws {
        let testCases: [(Platform, Platform)] = [
            (.GB, .GB),
            (.GBC, .GB),  // GBC uses GBCore which reports .GB as native platform
            (.GBA, .GBA),
            (.NDS, .NDS)
        ]
        for (requestedPlatform, expectedPlatform) in testCases {
            let core = try EmulatorCoreFactory.createCore(for: requestedPlatform)
            XCTAssertEqual(core.platform, expectedPlatform, "Core platform should match for \(requestedPlatform)")
        }
    }
    
    func testCoreCanStartAndStop() throws {
        let core = try EmulatorCoreFactory.createCore(for: .GB)
        XCTAssertTrue(core.initialize())
        core.start()
        core.stop()
        core.cleanup()
    }

    func testPlaceholderSystemsThrowUnsupportedErrors() {
        XCTAssertThrowsError(try EmulatorCoreFactory.createCore(for: .NES))
        XCTAssertThrowsError(try EmulatorCoreFactory.createCore(for: .GENESIS))
        XCTAssertThrowsError(try EmulatorCoreFactory.createCore(for: .PS1))
    }
}
