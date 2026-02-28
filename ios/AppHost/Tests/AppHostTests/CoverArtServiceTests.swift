import XCTest
@testable import Xemu

@MainActor
final class CoverArtServiceTests: XCTestCase {
    func testNormalizedTitleStripsCommonTokens() {
        let service = CoverArtService()
        let input = "Pokemon_Red_(USA) [Rev A] v1.1"
        XCTAssertEqual(service.normalizedTitle(for: input), "pokemon red")
    }

    func testResolvePrefersCustomCoverOverEmbedded() throws {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext
        let entry = ROMLibraryEntry(context: context)
        entry.id = UUID()
        entry.title = "Metroid II"
        entry.system = "gbc"
        entry.coverImageData = Data([0x01, 0x02, 0x03])

        let service = CoverArtService()
        let customURL = service.customCoverURL(for: entry.id)
        try FileManager.default.createDirectory(
            at: customURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let customData = Data([0xAA, 0xBB, 0xCC, 0xDD])
        try customData.write(to: customURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: customURL) }

        let resolved = service.resolve(for: entry)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.source, .customOverride)
        XCTAssertEqual(resolved?.data, customData)
    }

    func testResolveFallsBackToEmbeddedCover() {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext
        let entry = ROMLibraryEntry(context: context)
        entry.id = UUID()
        entry.title = "Mario Deluxe"
        entry.system = "gbc"
        let embedded = Data([0x11, 0x22, 0x33, 0x44])
        entry.coverImageData = embedded

        let service = CoverArtService()
        service.removeCustomCover(for: entry.id)
        let resolved = service.resolve(for: entry)
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.source, .embedded)
        XCTAssertEqual(resolved?.data, embedded)
    }
}

