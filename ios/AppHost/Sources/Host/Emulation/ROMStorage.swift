import Foundation

enum ROMStorageError: LocalizedError {
    case fileSystemError
    case fileNotFound
    case invalidPath
    case storageFull
    case writeFailed
    
    var errorDescription: String? {
        switch self {
        case .fileSystemError:
            return "File system error occurred"
        case .fileNotFound:
            return "ROM file not found"
        case .invalidPath:
            return "Invalid ROM file path"
        case .storageFull:
            return "Device storage is full"
        case .writeFailed:
            return "Failed to write ROM file"
        }
    }
}

struct ROMStorageLocation {
    let url: URL
    let fileSize: Int64
    let checksum: String
}

@MainActor
public class ROMStorage {
    public static let shared = ROMStorage()
    
    private let fileManager = FileManager.default
    private let romsDirectory: URL
    
    private init() {
        #if os(iOS)
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        romsDirectory = documentsDir.appendingPathComponent("ROMs")
        #else
        let documentsDir = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        romsDirectory = documentsDir.appendingPathComponent("ROMs")
        #endif
        
        createROMsDirectoryIfNeeded()
    }
    
    private func createROMsDirectoryIfNeeded() {
        var isDir: ObjCBool = false
        
        guard fileManager.fileExists(atPath: romsDirectory.path, isDirectory: &isDir) else {
            do {
                try fileManager.createDirectory(at: romsDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                // Debug log disabled: print("Failed to create ROMs directory: \(error.localizedDescription)")
            }
            return
        }
        
        guard isDir.boolValue else {
            do {
                try fileManager.createDirectory(at: romsDirectory, withIntermediateDirectories: true, attributes: nil)
            } catch {
                // Debug log disabled: print("Failed to create ROMs directory: \(error.localizedDescription)")
            }
            return
        }
    }
    
    func storeROM(_ data: Data, checksum: String, fileExtension: String) -> Result<ROMStorageLocation, ROMStorageError> {
        let filename = "\(checksum).\(fileExtension)"
        let url = romsDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: url, options: .atomic)
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? Int64(data.count)
            
            return .success(ROMStorageLocation(url: url, fileSize: fileSize, checksum: checksum))
        } catch {
            return .failure(.writeFailed)
        }
    }
    
    nonisolated func getROMLocation(checksum: String, fileExtension: String) -> ROMStorageLocation? {
        let filename = "\(checksum).\(fileExtension)"
        let url = romsDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            return ROMStorageLocation(url: url, fileSize: fileSize, checksum: checksum)
        } catch {
            return nil
        }
    }
    
    func deleteROM(checksum: String, fileExtension: String) -> Result<Void, ROMStorageError> {
        let filename = "\(checksum).\(fileExtension)"
        let url = romsDirectory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return .failure(.fileNotFound)
        }
        
        do {
            try fileManager.removeItem(at: url)
            return .success(())
        } catch {
            return .failure(.fileSystemError)
        }
    }

    func deleteROMByChecksum(checksum: String, preferredExtension: String? = nil) -> Result<Void, ROMStorageError> {
        if let preferredExtension, !preferredExtension.isEmpty {
            let preferred = deleteROM(checksum: checksum, fileExtension: preferredExtension)
            if case .success = preferred {
                return .success(())
            }
        }

        do {
            let files = try fileManager.contentsOfDirectory(at: romsDirectory, includingPropertiesForKeys: nil)
            if let match = files.first(where: { $0.lastPathComponent.lowercased().hasPrefix("\(checksum.lowercased()).") }) {
                try fileManager.removeItem(at: match)
                return .success(())
            }
            return .failure(.fileNotFound)
        } catch {
            return .failure(.fileSystemError)
        }
    }
    
    func getAllROMs() -> Result<[ROMStorageLocation], ROMStorageError> {
        guard fileManager.fileExists(atPath: romsDirectory.path) else {
            return .success([])
        }
        
        do {
            let files = try fileManager.contentsOfDirectory(at: romsDirectory, includingPropertiesForKeys: nil, options: [])
            var roms: [ROMStorageLocation] = []
            
            for file in files {
                let filename = file.lastPathComponent
                guard !filename.hasPrefix(".") else { continue }
                
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: file.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    let nsFilename = filename as NSString
                    let components = nsFilename.deletingPathExtension.components(separatedBy: ".")
                    if components.count >= 2 {
                        let checksum = components[0]
                        roms.append(ROMStorageLocation(url: file, fileSize: fileSize, checksum: checksum))
                    }
                } catch {
                    continue
                }
            }
            
            return .success(roms)
        } catch {
            return .failure(.fileSystemError)
        }
    }
    
    func getTotalROMsSize() -> Int64 {
        guard fileManager.fileExists(atPath: romsDirectory.path) else { return 0 }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: romsDirectory.path)
            return (attributes[.size] as? Int64) ?? 0
        } catch {
            return 0
        }
    }
}
