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
    case invalidFormat
    case corruptData
    case unsupportedSystem
    case invalidChecksum
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat: return "Invalid or unsupported ROM format"
        case .corruptData: return "ROM file appears to be corrupted"
        case .unsupportedSystem: return "This system is not supported"
        case .invalidChecksum: return "ROM checksum verification failed"
        }
    }
}

struct RomValidator {
    static func validate(at url: URL) throws -> (checksum: String, system: ROMSystem) {
        guard url.startAccessingSecurityScopedResource() else {
            throw ROMValidationError.invalidFormat
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let data = try Data(contentsOf: url)
        
        guard !data.isEmpty else {
            throw ROMValidationError.corruptData
        }
        
        let checksum = computeChecksum(data: data)
        let system: ROMSystem
    do {
        system = try detectSystem(data: data)
    } catch {
        throw ROMValidationError.unsupportedSystem
    }
        
        return (checksum, system)
    }
    
    static func computeChecksum(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    static func detectSystem(data: Data) throws -> ROMSystem {
        guard data.count >= 16 else {
            throw ROMValidationError.invalidFormat
        }
        
        let header = Array(data.prefix(16))
        
        if isNESROM(header) { return .nes }
        if isGBROM(header) { return .gbc }
        if isGBAROM(header) { return .gba }
        if isGenesisROM(header) { return .genesis }
        if isNDSROM(data) { return .nds }
        if isPS1ROM(header) { return .ps1 }
        
        throw ROMValidationError.unsupportedSystem
    }
    
    private static func isNESROM(_ header: [UInt8]) -> Bool {
        guard header.count >= 4 else { return false }
        return header[0] == 0x4E && header[1] == 0x45
    }
    
    private static func isGBROM(_ header: [UInt8]) -> Bool {
        guard header.count >= 0x150 else { return false }
        return header[0x143] == 0x80 || header[0x143] == 0xC0
    }
    
    private static func isGBAROM(_ header: [UInt8]) -> Bool {
        guard header.count >= 4 else { return false }
        return header[0] == 0x00 && header[3] == 0x00 && header[2] == 0x00
    }
    
    private static func isGenesisROM(_ header: [UInt8]) -> Bool {
        guard header.count >= 4 else { return false }
        return header[0x100] == 0x53 && header[0x101] == 0x45 && header[0x102] == 0x47 && header[0x103] == 0x41
    }
    
    private static func isNDSROM(_ data: Data) -> Bool {
        guard data.count >= 512 else { return false }
        let header = Array(data[0..<512])
        return header[0x00] == 0x00 && header[0x0C] == 0x00
    }
    
    private static func isPS1ROM(_ header: [UInt8]) -> Bool {
        guard header.count >= 16 else { return false }
        let str = String(bytes: header, encoding: .ascii) ?? ""
        return str.hasPrefix("PS-X")
    }
}
