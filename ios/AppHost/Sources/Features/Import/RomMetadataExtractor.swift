import Foundation

struct RomMetadataExtractor {
    static func extract(from data: Data, system: ROMSystem) -> RomMetadata {
        switch system {
        case .nes:
            return extractNESMetadata(data)
        case .gbc:
            return extractGBMetadata(data)
        case .gba:
            return extractGBAMetadata(data)
        case .genesis:
            return extractGenesisMetadata(data)
        case .nds:
            return extractNDSMetadata(data)
        case .ps1:
            return extractPS1Metadata(data)
        }
    }
    
    private static func extractNESMetadata(_ data: Data) -> RomMetadata {
        guard data.count >= 16 else {
            return RomMetadata(title: "Unknown NES ROM", region: "Unknown")
        }
        
        let header = Array(data.prefix(16))
        
        let title = String(bytes: header[0...3], encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown NES ROM"
        
        let region: String
        if header[7] & 0x01 != 0 {
            region = "Japan"
        } else if header[7] & 0x02 != 0 {
            region = "USA/Canada"
        } else {
            region = "Europe"
        }
        
        return RomMetadata(title: title, region: region)
    }
    
    private static func extractGBMetadata(_ data: Data) -> RomMetadata {
        guard data.count >= 0x150 else {
            return RomMetadata(title: "Unknown GB ROM", region: "Unknown")
        }
        
        let titleBytes = Array(data[0x134..<0x143])
        let title = String(bytes: titleBytes, encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown GB ROM"
        
        let regionCode = data[0x143]
        let region: String
        switch regionCode {
        case 0x00: region = "Japan"
        case 0x01: region = "International"
        case 0x02, 0x03, 0x04: region = "Europe"
        case 0x05, 0x06, 0x07: region = "USA/Canada"
        default: region = "Unknown"
        }
        
        return RomMetadata(title: title, region: region)
    }
    
    private static func extractGBAMetadata(_ data: Data) -> RomMetadata {
        guard data.count >= 0xC0 else {
            return RomMetadata(title: "Unknown GBA ROM", region: "Unknown")
        }
        
        let titleBytes = Array(data[0xA0..<0xAC])
        let title = String(bytes: titleBytes, encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown GBA ROM"
        
        let regionCode = data[0x3D]
        let region: String
        switch regionCode {
        case 0x00: region = "Europe"
        case 0x01: region = "USA"
        case 0x02: region = "Australia"
        case 0x03: region = "Japan"
        case 0x04, 0x05, 0x06, 0x07: region = "China"
        default: region = "Unknown"
        }
        
        return RomMetadata(title: title, region: region)
    }
    
    private static func extractGenesisMetadata(_ data: Data) -> RomMetadata {
        guard data.count >= 512 else {
            return RomMetadata(title: "Unknown Genesis ROM", region: "Unknown")
        }
        
        let header = Array(data[0x100..<0x1FF])
        let titleBytes = Array(header[0x10..<0x30])
        let title = String(bytes: titleBytes, encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Genesis ROM"
        
        let countryCode = header[0x1F]
        let region: String
        switch countryCode {
        case 0x41, 0x42, 0x43: region = "USA/Canada"
        case 0x45, 0x46, 0x47, 0x48, 0x49: region = "Europe"
        case 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F: region = "Japan"
        default: region = "Unknown"
        }
        
        return RomMetadata(title: title, region: region)
    }
    
    private static func extractNDSMetadata(_ data: Data) -> RomMetadata {
        guard data.count >= 512 else {
            return RomMetadata(title: "Unknown NDS ROM", region: "Unknown")
        }
        
        let header = Array(data.prefix(512))
        let titleBytes = Array(header[0x00..<0x0C])
        let title = String(bytes: titleBytes, encoding: .utf16LittleEndian)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown NDS ROM"
        
        let regionCode = header[0x1F]
        let region: String
        switch regionCode {
        case 0x41, 0x42, 0x43: region = "USA/Canada"
        case 0x45, 0x46, 0x47, 0x48: region = "Europe"
        case 0x4A, 0x4B: region = "Japan"
        case 0x4C, 0x4D, 0x4E, 0x4F: region = "Australia"
        default: region = "Unknown"
        }
        
        return RomMetadata(title: title, region: region)
    }
    
    private static func extractPS1Metadata(_ data: Data) -> RomMetadata {
        guard data.count >= 32 else {
            return RomMetadata(title: "Unknown PS1 ROM", region: "Unknown")
        }
        
        let titleBytes = Array(data[0x00..<0x10])
        let title = String(bytes: titleBytes, encoding: .ascii)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown PS1 ROM"
        
        let regionCode = data[0x04]
        let region: String
        switch regionCode {
        case 0x41, 0x42, 0x43: region = "USA/Canada"
        case 0x45, 0x46, 0x47: region = "Europe"
        case 0x4A, 0x4B: region = "Japan"
        default: region = "Unknown"
        }
        
        return RomMetadata(title: title, region: region)
    }
}

struct RomMetadata {
    let title: String
    let region: String
}
