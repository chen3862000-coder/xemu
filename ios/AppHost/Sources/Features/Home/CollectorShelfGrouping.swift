import Foundation

enum CollectorShelfGrouping {
    static func sectionKey(for system: String?) -> String {
        let normalized = SubpageUI.CollectorIdentity.normalizedSystemCode(system)
        return normalized.isEmpty ? "other" : normalized
    }

    static func sectionTitle(for key: String) -> String {
        switch key {
        case "gb":
            return "Game Boy Collection"
        case "gbc":
            return "Game Boy Color Collection"
        case "gba":
            return "Game Boy Advance Collection"
        case "nds":
            return "Nintendo DS Collection"
        case "other":
            return "Other Systems"
        default:
            return key.uppercased() + " Collection"
        }
    }

    static func orderedSectionKeys(for systems: [String?]) -> [String] {
        let uniqueKeys = Set(systems.map(sectionKey(for:)))
        return uniqueKeys.sorted { lhs, rhs in
            let leftRank = rank(for: lhs)
            let rightRank = rank(for: rhs)
            if leftRank != rightRank {
                return leftRank < rightRank
            }
            return sectionTitle(for: lhs).localizedCaseInsensitiveCompare(sectionTitle(for: rhs)) == .orderedAscending
        }
    }

    private static func rank(for key: String) -> Int {
        switch key {
        case "gb": return 0
        case "gbc": return 1
        case "gba": return 2
        case "nds": return 3
        case "other": return 98
        default: return 50
        }
    }
}
