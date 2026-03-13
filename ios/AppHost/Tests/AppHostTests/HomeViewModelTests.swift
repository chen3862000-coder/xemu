import CoreData
import XCTest
@testable import Xemu

@MainActor
final class HomeViewModelTests: XCTestCase {
    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        context = persistence.viewContext
    }

    override func tearDown() {
        context = nil
        persistence = nil
        super.tearDown()
    }

    func testLoadDataBuildsStatsRecentGamesAndEmulatorCounts() throws {
        let now = Date()
        let gbID = try makeEntry(
            title: "Tetris",
            checksum: "gb-1",
            system: "gb",
            playtimeSeconds: 3_600,
            lastPlayedAt: now,
            dateAdded: now.addingTimeInterval(-100)
        )
        _ = try makeEntry(
            title: "Mario Land",
            checksum: "gbc-1",
            system: "gbc",
            playtimeSeconds: 7_200,
            lastPlayedAt: now.addingTimeInterval(-60),
            dateAdded: now.addingTimeInterval(-90)
        )
        _ = try makeEntry(
            title: "Advance Wars",
            checksum: "gba-1",
            system: "gba",
            playtimeSeconds: 1_800,
            lastPlayedAt: now.addingTimeInterval(-120),
            dateAdded: now.addingTimeInterval(-80)
        )
        _ = try makeEntry(
            title: "Nintendogs",
            checksum: "nds-1",
            system: "nds",
            playtimeSeconds: 900,
            lastPlayedAt: now.addingTimeInterval(-180),
            dateAdded: now.addingTimeInterval(-70)
        )
        _ = try makeEntry(
            title: "Metroid",
            checksum: "gb-2",
            system: "gb",
            playtimeSeconds: 900,
            lastPlayedAt: now.addingTimeInterval(-240),
            dateAdded: now.addingTimeInterval(-60)
        )
        _ = try makeEntry(
            title: "F-Zero",
            checksum: "gba-2",
            system: "gba",
            playtimeSeconds: 0,
            lastPlayedAt: nil,
            dateAdded: now.addingTimeInterval(-50)
        )
        try context.save()

        let viewModel = HomeViewModel()
        viewModel.loadData(in: context)

        XCTAssertEqual(viewModel.totalGames, 6)
        XCTAssertEqual(viewModel.totalHours, "4h")
        XCTAssertEqual(viewModel.recentGames.count, 5)
        XCTAssertEqual(viewModel.recentGames.first?.title, "Tetris")
        XCTAssertEqual(viewModel.recentlyAddedGames.first?.title, "F-Zero")
        XCTAssertEqual(viewModel.entry(for: gbID)?.title, "Tetris")

        let countsByShortName = Dictionary(uniqueKeysWithValues: viewModel.emulators.map { ($0.shortName, $0.gamesCount) })
        XCTAssertEqual(countsByShortName["GB"], 2)
        XCTAssertEqual(countsByShortName["GBC"], 1)
        XCTAssertEqual(countsByShortName["GBA"], 2)
        XCTAssertEqual(countsByShortName["NDS"], 1)
    }

    @discardableResult
    private func makeEntry(
        title: String,
        checksum: String,
        system: String,
        playtimeSeconds: Int64,
        lastPlayedAt: Date?,
        dateAdded: Date?
    ) throws -> UUID {
        let entity = try XCTUnwrap(NSEntityDescription.entity(forEntityName: "ROMLibraryEntry", in: context))
        let entry = ROMLibraryEntry(entity: entity, insertInto: context)
        let id = UUID()
        entry.id = id
        entry.title = title
        entry.checksum = checksum
        entry.system = system
        entry.fileName = "\(checksum).\(system)"
        entry.playtimeTotal = playtimeSeconds
        entry.lastPlayedAt = lastPlayedAt
        entry.dateAdded = dateAdded
        return id
    }
}
