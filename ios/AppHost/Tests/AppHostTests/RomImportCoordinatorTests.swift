import XCTest
import Combine
@testable import AppHost

@MainActor
final class RomImportCoordinatorTests: XCTestCase {
    func testInit() {
        let controller = PersistenceController(inMemory: true)
        let coordinator = RomImportCoordinator(
            persistence: controller,
            compatibility: [],
            romsDirectory: URL(fileURLWithPath: "/tmp/roms")
        )
        
        XCTAssertFalse(coordinator.isImporting)
        XCTAssertEqual(coordinator.importProgress, 0)
    }
    
    func testImportProgressPublished() {
        let controller = PersistenceController(inMemory: true)
        let coordinator = RomImportCoordinator(
            persistence: controller,
            compatibility: [],
            romsDirectory: URL(fileURLWithPath: "/tmp/roms")
        )
        
        XCTAssertFalse(coordinator.isImporting)
        XCTAssertEqual(coordinator.importProgress, 0)
    }
    
    private var cancellables = Set<AnyCancellable>()
}
