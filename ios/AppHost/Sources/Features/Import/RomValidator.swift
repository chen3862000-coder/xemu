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
        // Only access security scope if needed (original file picker URLs)
        // Temp files don't need security scope access
        let needsSecurityScope = !url.path.contains("/tmp/")
        if needsSecurityScope {
            guard url.startAccessingSecurityScopedResource() else {
                throw ROMValidationError.invalidFormat
            }
        }
        defer {
            if needsSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
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
        
        if isNESROM(data) { return .nes }
        if isGBROM(data) { return .gbc }
        if isGBAROM(data) { return .gba }
        if isGenesisROM(data) { return .genesis }
        if isNDSROM(data) { return .nds }
        if isPS1ROM(data) { return .ps1 }
        
        throw ROMValidationError.unsupportedSystem
    }
    
    private static func isNESROM(_ data: Data) -> Bool {
        guard data.count >= 4 else { return false }
        return data[0] == 0x4E && data[1] == 0x45 && data[2] == 0x53 && data[3] == 0x1A
    }
    
    private static func isGBROM(_ data: Data) -> Bool {
        guard data.count >= 0x150 else { return false }
        let cgbFlag = data[0x143]
        if cgbFlag == 0x80 || cgbFlag == 0xC0 {
            return true
        }
        if data.count >= 0x104 {
            let nintendoLogo: [UInt8] = [0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B, 0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D]
            for i in 0..<nintendoLogo.count {
                if data[0x104 + i] != nintendoLogo[i] {
                    return false
                }
            }
            return true
        }
        return false
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
        guard data.count >= 512 else { return false }
        let header = Array(data[0..<512])
        return header[0x00] == 0x00 && header[0x0C] == 0x00
    }
    
    private static func isPS1ROM(_ data: Data) -> Bool {
        guard data.count >= 0x10 else { return false }
        let headerData = data.prefix(16)
        let str = String(data: headerData, encoding: .ascii) ?? ""
        return str.hasPrefix("PS-X")
    }
}
