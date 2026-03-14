import XCTest
@testable import Xemu

@MainActor
final class ROMLibraryOperationsTests: XCTestCase {
    func testRenameUpdatesTitleAndTrimsWhitespace() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext
        let entry = ROMLibraryEntry(context: context)
        entry.id = UUID()
        entry.title = "Metroid4USA"

        let savedTitle = try GameRenameService.shared.rename(entry: entry, to: "  Metroid Fusion  ", in: context)

        XCTAssertEqual(savedTitle, "Metroid Fusion")
        XCTAssertEqual(entry.title, "Metroid Fusion")
    }

    func testRenameRejectsEmptyTitle() {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext
        let entry = ROMLibraryEntry(context: context)
        entry.id = UUID()
        entry.title = "Advance Wars"

        XCTAssertThrowsError(try GameRenameService.shared.rename(entry: entry, to: "   ", in: context)) { error in
            XCTAssertEqual(error as? GameRenameError, .emptyTitle)
        }
        XCTAssertEqual(entry.title, "Advance Wars")
    }
}
