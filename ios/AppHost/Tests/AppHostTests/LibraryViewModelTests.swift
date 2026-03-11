import CoreData
import XCTest
@testable import Xemu

@MainActor
final class LibraryViewModelTests: XCTestCase {
    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        context = persistence.viewContext
        CompatibilityDataStore.shared.reload()
    }

    override func tearDown() {
        context = nil
        persistence = nil
        super.tearDown()
    }

    func testApplyFilterSupportsFavoritesRecentStableAndExperimental() throws {
        let now = Date()
        try makeEntry(
            title: "Stable Game",
            checksum: "nes-super-mario",
            system: "nes",
            isFavorite: true,
            lastPlayedAt: now.addingTimeInterval(-300)
        )
        try makeEntry(
            title: "Experimental Game",
            checksum: "ps2-shadow-colossus",
            system: "ps2",
            isFavorite: false,
            lastPlayedAt: now.addingTimeInterval(-120)
        )
        try makeEntry(
            title: "Old Favorite",
            checksum: "unknown-hash",
            system: "gba",
            isFavorite: true,
            lastPlayedAt: now.addingTimeInterval(-10 * 24 * 60 * 60)
        )
        try context.save()

        let viewModel = LibraryViewModel { checksum in
            switch checksum {
            case "nes-super-mario":
                return .stable
            case "ps2-shadow-colossus":
                return .experimental
            default:
                return .unknown
            }
        }
        viewModel.loadEntries(in: context)
        XCTAssertEqual(viewModel.filteredEntries.count, 3)

        viewModel.applyFilter(.favorites)
        XCTAssertEqual(Set(viewModel.filteredEntries.compactMap(\.title)), ["Stable Game", "Old Favorite"])

        viewModel.applyFilter(.recent)
        XCTAssertEqual(Set(viewModel.filteredEntries.compactMap(\.title)), ["Stable Game", "Experimental Game"])

        viewModel.applyFilter(.stable)
        XCTAssertEqual(viewModel.filteredEntries.compactMap(\.title), ["Stable Game"])

        viewModel.applyFilter(.experimental)
        XCTAssertEqual(viewModel.filteredEntries.compactMap(\.title), ["Experimental Game"])
    }

    private func makeEntry(
        title: String,
        checksum: String,
        system: String,
        isFavorite: Bool,
        lastPlayedAt: Date
    ) throws {
        let entity = try XCTUnwrap(NSEntityDescription.entity(forEntityName: "ROMLibraryEntry", in: context))
        let entry = ROMLibraryEntry(entity: entity, insertInto: context)
        entry.id = UUID()
        entry.title = title
        entry.checksum = checksum
        entry.system = system
        entry.fileName = "\(checksum).\(system)"
        entry.isFavorite = isFavorite
        entry.lastPlayedAt = lastPlayedAt
        entry.dateAdded = lastPlayedAt
    }
}
