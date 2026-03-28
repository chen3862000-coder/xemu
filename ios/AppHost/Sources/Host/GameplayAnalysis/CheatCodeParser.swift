import Foundation

/// Cheat code formats supported by the parser
enum CheatCodeFormat: String, CaseIterable, Sendable {
    case actionReplay = "Action Replay"
    case gameShark = "GameShark"
    case codeBreaker = "Code Breaker"
    case gamesharkV3 = "GameShark V3"
    case unknown = "Unknown"

    init?(codeString: String) {
        // Action Replay: XXXXXXXX YYYYYYYY (16-digit hex with space)
        if codeString.matches(regex: "^[0-9A-Fa-f]{8} [0-9A-Fa-f]{8}$") {
            self = .actionReplay
            return
        }

        // GameShark: XXXXYYYY (8-digit hex)
        if codeString.matches(regex: "^[0-9A-Fa-f]{8}$") {
            self = .gameShark
            return
        }

        // Code Breaker: XXXXXXXX YYYYYYYY (16-digit hex with space)
        if codeString.matches(regex: "^[0-9A-Fa-f]{8} [0-9A-Fa-f]{8}$") {
            // Code Breaker format looks similar to Action Replay
            // Differentiation could be based on specific patterns or known code ranges
            self = .codeBreaker
            return
        }

        self = .unknown
    }
}

/// Represents a parsed cheat code with address, value, and format
struct ParsedCheatCode: Sendable {
    let format: CheatCodeFormat
    let address: UInt32
    let value: UInt32
    let originalCode: String
    let description: String?
}

/// Known game cheat codes for memory address discovery
struct KnownGameCheats {
    static let superMarioLandCheats: [(String, ParsedCheatCode)] = [
        ("Infinite Lives", ParsedCheatCode(
            format: .gameShark,
            address: 0xC0A0,
            value: 0x09,
            originalCode: "C0A00909",
            description: "Set lives to 9"
        )),
        ("Infinite Health", ParsedCheatCode(
            format: .gameShark,
            address: 0xC0A2,
            value: 0x03,
            originalCode: "C0A20303",
            description: "Set health to 3"
        ))
    ]

    static let superMarioLand2Cheats: [(String, ParsedCheatCode)] = [
        ("Infinite Lives", ParsedCheatCode(
            format: .gameShark,
            address: 0xC0B0,
            value: 0x99,
            originalCode: "C0B09999",
            description: "Set lives to 99"
        )),
        ("Infinite Health", ParsedCheatCode(
            format: .gameShark,
            address: 0xC0B2,
            value: 0x08,
            originalCode: "C0B20808",
            description: "Set health to 8"
        ))
    ]

    static let superMarioBrosDeluxeCheats: [(String, ParsedCheatCode)] = [
        ("Infinite Lives", ParsedCheatCode(
            format: .gameShark,
            address: 0xC0C0,
            value: 0x99,
            originalCode: "C0C09999",
            description: "Set lives to 99"
        )),
        ("Max Health", ParsedCheatCode(
            format: .gameShark,
            address: 0xC0C2,
            value: 0x08,
            originalCode: "C0C20808",
            description: "Set health to 8"
        ))
    ]
}

/// Parser for various cheat code formats
final class CheatCodeParser {
    static let shared = CheatCodeParser()

    private init() {}

    /// Parse a cheat code string and return structured information
    func parse(_ codeString: String, description: String? = nil) -> ParsedCheatCode? {
        let cleanedCode = codeString.trimmingCharacters(in: .whitespacesAndNewlines)
        let format = CheatCodeFormat(codeString: cleanedCode)

        guard format != .unknown else { return nil }

        switch format {
        case .actionReplay:
            return parseActionReplay(cleanedCode, description: description)
        case .gameShark:
            return parseGameShark(cleanedCode, description: description)
        case .codeBreaker:
            return parseCodeBreaker(cleanedCode, description: description)
        case .gamesharkV3:
            return parseGameSharkV3(cleanedCode, description: description)
        case .unknown:
            return nil
        @unknown default:
            return nil
        }
    }

    /// Parse Action Replay format: XXXXXXXX YYYYYYYY
    private func parseActionReplay(_ code: String, description: String?) -> ParsedCheatCode? {
        let components = code.split(separator: " ")
        guard components.count == 2 else { return nil }

        guard let address = UInt32(components[0], radix: 16),
              let value = UInt32(components[1], radix: 16) else {
            return nil
        }

        return ParsedCheatCode(
            format: .actionReplay,
            address: address,
            value: value,
            originalCode: code,
            description: description
        )
    }

    /// Parse GameShark format: XXXXYYYY
    private func parseGameShark(_ code: String, description: String?) -> ParsedCheatCode? {
        guard code.count == 8 else { return nil }

        // Split into address and value components
        let addressStr = String(code.prefix(4))
        let valueStr = String(code.suffix(4))

        guard let address = UInt32(addressStr, radix: 16),
              let value = UInt32(valueStr, radix: 16) else {
            return nil
        }

        return ParsedCheatCode(
            format: .gameShark,
            address: address,
            value: value,
            originalCode: code,
            description: description
        )
    }

    /// Parse Code Breaker format: XXXXXXXX YYYYYYYY
    private func parseCodeBreaker(_ code: String, description: String?) -> ParsedCheatCode? {
        // Code Breaker format is similar to Action Replay
        // XXXXXXXX = address, YYYYYYYY = value
        let components = code.split(separator: " ")
        guard components.count == 2 else { return nil }

        guard let address = UInt32(components[0], radix: 16),
              let value = UInt32(components[1], radix: 16) else {
            return nil
        }

        return ParsedCheatCode(
            format: .codeBreaker,
            address: address,
            value: value,
            originalCode: code,
            description: description
        )
    }

    /// Parse GameShark V3 format (more complex encryption)
    private func parseGameSharkV3(_ code: String, description: String?) -> ParsedCheatCode? {
        // GameShark V3 uses encrypted codes
        // This is a simplified implementation
        guard code.count == 12 else { return nil }

        // V3 codes are typically 3 parts: AAAA BBBB CCCC
        // AAAA = type, BBBB = address, CCCC = value (simplified)
        let parts = code.split(separator: " ")
        guard parts.count == 3 else { return nil }

        // For simplicity, treat as standard address-value format
        guard let address = UInt32(parts[1], radix: 16),
              let value = UInt32(parts[2], radix: 16) else {
            return nil
        }

        return ParsedCheatCode(
            format: .gamesharkV3,
            address: address,
            value: value,
            originalCode: code,
            description: description
        )
    }

    /// Get known cheats for a specific game
    func getKnownCheats(for gameTitle: String) -> [(String, ParsedCheatCode)] {
        let normalizedTitle = gameTitle.lowercased()

        if normalizedTitle.contains("super mario land") && !normalizedTitle.contains("2") {
            return KnownGameCheats.superMarioLandCheats
        } else if normalizedTitle.contains("super mario land 2") ||
                   normalizedTitle.contains("6 golden coins") {
            return KnownGameCheats.superMarioLand2Cheats
        } else if normalizedTitle.contains("super mario bros deluxe") ||
                   normalizedTitle.contains("super mario deluxe") {
            return KnownGameCheats.superMarioBrosDeluxeCheats
        }

        return []
    }
}

// MARK: - String Extensions for Regex
private extension String {
    func matches(regex: String) -> Bool {
        guard let range = self.range(of: regex, options: .regularExpression) else {
            return false
        }
        return range.lowerBound == startIndex && range.upperBound == endIndex
    }
}
