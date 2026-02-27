import XCTest
@testable import Xemu

final class RomValidatorTests: XCTestCase {
    func testValidateAcceptsWellFormedGBROM() throws {
        let romData = makeValidGBROM()
        let url = try writeTempFile(data: romData, ext: "gb")
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try RomValidator.validate(at: url)
        XCTAssertEqual(result.system, .gbc)
        XCTAssertFalse(result.checksum.isEmpty)
    }

    func testValidateRejectsGBMissingNintendoLogo() throws {
        var romData = makeValidGBROM()
        romData[0x104] = 0x00
        let url = try writeTempFile(data: romData, ext: "gb")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try RomValidator.validate(at: url)) { error in
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            XCTAssertTrue(message.contains("Nintendo logo bytes missing at 0x0104"))
        }
    }

    func testValidateRejectsGBChecksumMismatch() throws {
        var romData = makeValidGBROM()
        romData[0x14D] = romData[0x14D] &+ 1
        let url = try writeTempFile(data: romData, ext: "gb")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try RomValidator.validate(at: url)) { error in
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            XCTAssertTrue(message.contains("header checksum mismatch at 0x014D"))
        }
    }

    func testValidateRejectsArchiveWithClearReason() throws {
        // ZIP local file header magic
        let data = Data([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00])
        let url = try writeTempFile(data: data, ext: "zip")
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try RomValidator.validate(at: url)) { error in
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            XCTAssertTrue(message.lowercased().contains("zip"))
        }
    }

    private func makeValidGBROM() -> Data {
        var rom = Data(repeating: 0, count: 32 * 1024)

        let logo: [UInt8] = [
            0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B,
            0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D,
            0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E,
            0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99,
            0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC,
            0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E
        ]
        for (idx, byte) in logo.enumerated() {
            rom[0x104 + idx] = byte
        }

        // Title (0x0134...)
        let title = Array("TESTGAME".utf8)
        for (idx, byte) in title.enumerated() {
            rom[0x134 + idx] = byte
        }

        rom[0x143] = 0x00 // DMG compatible
        rom[0x147] = 0x00 // ROM ONLY
        rom[0x148] = 0x00 // 32KB
        rom[0x149] = 0x00 // no RAM

        var checksum: UInt8 = 0
        for i in 0x134...0x14C {
            checksum = checksum &- rom[i] &- 1
        }
        rom[0x14D] = checksum

        return rom
    }

    private func writeTempFile(data: Data, ext: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try data.write(to: url, options: .atomic)
        return url
    }
}

