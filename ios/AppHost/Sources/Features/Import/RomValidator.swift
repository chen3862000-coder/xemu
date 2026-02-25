import CryptoKit
import Foundation

public enum ROMSystem: String, CaseIterable, Sendable {
    case nes
    case gbc
    case gba
    case genesis
    case nds
    case ps1
    
    var displayName: String {
        switch self {
        case .nes: return "NES"
        case .gbc: return "GB / GBC"
        case .gba: return "GBA"
        case .genesis: return "Genesis / Mega Drive"
        case .nds: return "NDS"
        case .ps1: return "PS1"
        }
    }
}

enum ROMValidationError: LocalizedError {
    case invalidFormat(reason: String)
    case corruptData(reason: String)
    case unsupportedSystem(reason: String)
    case invalidChecksum(reason: String)
    case fileRejected(reason: String)
    case unsupportedArchive(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat(let reason): return "Invalid ROM format: \(reason)"
        case .corruptData(let reason): return "ROM file appears corrupted: \(reason)"
        case .unsupportedSystem(let reason): return "Unsupported system: \(reason)"
        case .invalidChecksum(let reason): return "ROM checksum verification failed: \(reason)"
        case .fileRejected(let reason): return "File rejected: \(reason)"
        case .unsupportedArchive(let reason): return "Archive import is not supported: \(reason)"
        }
    }
}

struct RomValidator {
    private static let maxRawROMBytes = 256 * 1024 * 1024
    private static let maxGBROMBytes = 8 * 1024 * 1024
    private static let minGBHeaderBytes = 0x150
    private static let minGBROMBytes = 32 * 1024
    private static let nintendoGBLogo: [UInt8] = [
        0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B,
        0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D,
        0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E,
        0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99,
        0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC,
        0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E
    ]

    static func validate(at url: URL) throws -> (checksum: String, system: ROMSystem) {
        try preflightCheck(url)

        // Only access security scope if needed (original file picker URLs)
        // Temp files don't need security scope access
        let needsSecurityScope = !url.path.contains("/tmp/")
        if needsSecurityScope {
            guard url.startAccessingSecurityScopedResource() else {
                throw ROMValidationError.fileRejected(reason: "Unable to access security-scoped file")
            }
        }
        defer {
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        
        guard !data.isEmpty else {
            throw ROMValidationError.corruptData(reason: "File is empty")
        }
        
        let checksum = computeChecksum(data: data)
        let system = try detectSystem(data: data, fileExtension: url.pathExtension.lowercased())
        
        return (checksum, system)
    }
    
    static func computeChecksum(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    static func detectSystem(data: Data, fileExtension: String? = nil) throws -> ROMSystem {
        guard data.count >= 16 else {
            throw ROMValidationError.invalidFormat(reason: "File smaller than minimum header size")
        }

        let ext = (fileExtension ?? "").lowercased()
        if ext == "gb" || ext == "gbc" || ext == "cgb" {
            if try isGBROM(data) { return .gbc }
        } else if ext == "gba" {
            if isGBAROM(data) { return .gba }
        } else if ext == "nds" {
            if isNDSROM(data) { return .nds }
        } else if ext == "nes" {
            if isNESROM(data) { return .nes }
        }
        
        if isNESROM(data) { return .nes }
        if matchesGBNintendoLogo(data) {
            if try isGBROM(data) { return .gbc }
        }
        if isGBAROM(data) { return .gba }
        if isGenesisROM(data) { return .genesis }
        if isNDSROM(data) { return .nds }
        if isPS1ROM(data) { return .ps1 }
        
        throw ROMValidationError.unsupportedSystem(reason: "Content signature did not match supported systems")
    }
    
    private static func isNESROM(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        return data[0] == 0x4E && data[1] == 0x45 && data[2] == 0x53 && data[3] == 0x1A
    }
    
    private static func isGBROM(_ data: Data) throws -> Bool {
        guard data.count >= minGBHeaderBytes else {
            throw ROMValidationError.invalidFormat(reason: "GB/GBC header is incomplete (< 0x150 bytes)")
        }
        guard data.count >= minGBROMBytes else {
            throw ROMValidationError.invalidFormat(reason: "GB/GBC ROM is too small (< 32KB)")
        }
        guard data.count <= maxGBROMBytes else {
            throw ROMValidationError.fileRejected(reason: "GB/GBC ROM exceeds safe size limit (8MB)")
        }

        if !matchesGBNintendoLogo(data) {
            throw ROMValidationError.invalidFormat(reason: "Nintendo logo bytes missing at 0x0104")
        }

        guard hasValidGBHeaderChecksum(data) else {
            throw ROMValidationError.invalidChecksum(reason: "GB/GBC header checksum mismatch at 0x014D")
        }

        let cartType = data[0x147]
        guard isKnownGBCartridgeType(cartType) else {
            throw ROMValidationError.invalidFormat(reason: String(format: "Unknown cartridge type 0x%02X", cartType))
        }

        let romSizeCode = data[0x148]
        guard let declaredROMSize = gbDeclaredROMSize(for: romSizeCode) else {
            throw ROMValidationError.invalidFormat(reason: String(format: "Unknown GB ROM size code 0x%02X", romSizeCode))
        }
        if data.count < declaredROMSize {
            throw ROMValidationError.corruptData(reason: "File length is smaller than declared GB ROM size")
        }

        let ramSizeCode = data[0x149]
        guard isKnownGBRAMSizeCode(ramSizeCode) else {
            throw ROMValidationError.invalidFormat(reason: String(format: "Unknown GB RAM size code 0x%02X", ramSizeCode))
        }

        let cgbFlag = data[0x143]
        if !(cgbFlag == 0x00 || cgbFlag == 0x80 || cgbFlag == 0xC0) {
            throw ROMValidationError.invalidFormat(reason: String(format: "Invalid CGB flag 0x%02X", cgbFlag))
        }

        return true
    }
    
    private static func isGBAROM(_ data: Data) -> Bool {
        guard data.count >= 0xC0 else { return false }
        if data[0xB2] != 0x96 { return false }
        return true
    }
    
    private static func isGenesisROM(_ data: Data) -> Bool {
        guard data.count >= 0x104 else { return false }
        let header = Array(data.prefix(0x104))
        return header[0x100] == 0x53 && header[0x101] == 0x45 && header[0x102] == 0x47 && header[0x103] == 0x41
    }
    
    private static func isNDSROM(_ data: Data) -> Bool {
        guard data.count >= 0x160 else { return false }

        // NDS headers contain a fixed Nintendo logo blob at 0xC0..0x15B.
        // This is a much more reliable signature than checking title bytes.
        let expectedLogo: [UInt8] = [
            0x24, 0xFF, 0xAE, 0x51, 0x69, 0x9A, 0xA2, 0x21,
            0x3D, 0x84, 0x82, 0x0A, 0x84, 0xE4, 0x09, 0xAD,
            0x11, 0x24, 0x8B, 0x98, 0xC0, 0x81, 0x7F, 0x21,
            0xA3, 0x52, 0xBE, 0x19, 0x93, 0x09, 0xCE, 0x20
        ]

        for i in 0..<expectedLogo.count {
            if data[0xC0 + i] != expectedLogo[i] {
                return false
            }
        }

        // Additional basic sanity check: ARM9 ROM offset is typically non-zero
        // and inside the file.
        guard data.count >= 0x24 else { return false }
        let arm9Offset = Int(data[data.startIndex + 0x20]) |
            (Int(data[data.startIndex + 0x21]) << 8) |
            (Int(data[data.startIndex + 0x22]) << 16) |
            (Int(data[data.startIndex + 0x23]) << 24)
        return arm9Offset > 0 && arm9Offset < data.count
    }
    
    private static func isPS1ROM(_ data: Data) -> Bool {
        guard data.count >= 0x10 else { return false }
        let headerData = data.prefix(16)
        let str = String(data: headerData, encoding: .ascii) ?? ""
        return str.hasPrefix("PS-X")
    }

    private static func preflightCheck(_ url: URL) throws {
        let ext = url.pathExtension.lowercased()
        if ext == "zip" || ext == "7z" || ext == "rar" {
            throw ROMValidationError.unsupportedArchive(reason: "Import raw ROM files for now (archives will be supported later)")
        }

        let values = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey
        ])

        if values.isSymbolicLink == true {
            throw ROMValidationError.fileRejected(reason: "Symbolic links are not allowed")
        }
        if values.isRegularFile != true {
            throw ROMValidationError.fileRejected(reason: "Selected item is not a regular file")
        }
        if let fileSize = values.fileSize {
            if fileSize <= 0 {
                throw ROMValidationError.fileRejected(reason: "Selected file is empty")
            }
            if fileSize > maxRawROMBytes {
                throw ROMValidationError.fileRejected(reason: "File exceeds safe import size limit (256MB)")
            }
        }
    }

    private static func matchesGBNintendoLogo(_ data: Data) -> Bool {
        guard data.count >= 0x134 else { return false }
        for i in 0..<nintendoGBLogo.count where data[0x104 + i] != nintendoGBLogo[i] {
            return false
        }
        return true
    }

    private static func hasValidGBHeaderChecksum(_ data: Data) -> Bool {
        guard data.count > 0x14D else { return false }
        var x: UInt8 = 0
        for i in 0x134...0x14C {
            x = x &- data[i] &- 1
        }
        return x == data[0x14D]
    }

    private static func isKnownGBCartridgeType(_ value: UInt8) -> Bool {
        let known: Set<UInt8> = [
            0x00, 0x01, 0x02, 0x03,
            0x05, 0x06,
            0x08, 0x09,
            0x0B, 0x0C, 0x0D,
            0x0F, 0x10, 0x11, 0x12, 0x13,
            0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E,
            0x20,
            0x22,
            0xFC, 0xFD, 0xFE, 0xFF
        ]
        return known.contains(value)
    }

    private static func gbDeclaredROMSize(for code: UInt8) -> Int? {
        switch code {
        case 0x00...0x08:
            // 32KB << code
            return 32 * 1024 << Int(code)
        case 0x52:
            return 72 * 16 * 1024
        case 0x53:
            return 80 * 16 * 1024
        case 0x54:
            return 96 * 16 * 1024
        default:
            return nil
        }
    }

    private static func isKnownGBRAMSizeCode(_ value: UInt8) -> Bool {
        // Includes legacy and newer MBC2/MBC5-compatible codes
        let known: Set<UInt8> = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
        return known.contains(value)
    }
}
