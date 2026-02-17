import Foundation

public enum SaveStateError: Error, Equatable {
    case notFound
}

public struct SaveStateMetadata: Codable, Equatable {
    public let stateId: UUID
    public let romHash: String
    public let platform: Platform
    public let timestamp: Date
    public let screenshotPath: String
    public let fileSize: Int
    public let checksum: String
    
    public init(stateId: UUID, romHash: String, platform: Platform, timestamp: Date, screenshotPath: String, fileSize: Int, checksum: String) {
        self.stateId = stateId
        self.romHash = romHash
        self.platform = platform
        self.timestamp = timestamp
        self.screenshotPath = screenshotPath
        self.fileSize = fileSize
        self.checksum = checksum
    }
}

public struct SaveState: Equatable {
    public let metadata: SaveStateMetadata
    public let data: Data
    
    public init(metadata: SaveStateMetadata, data: Data) {
        self.metadata = metadata
        self.data = data
    }
}

public final class SaveStateStorage: @unchecked Sendable {
    private let baseURL: URL
    private let statesDirectory: URL
    private let screenshotsDirectory: URL
    private let fileManager = FileManager.default
    
    public init(baseURL: URL) {
        self.baseURL = baseURL
        self.statesDirectory = baseURL.appendingPathComponent("states")
        self.screenshotsDirectory = baseURL.appendingPathComponent("screenshots")
        
        try? fileManager.createDirectory(at: statesDirectory, withIntermediateDirectories: true, attributes: nil)
        try? fileManager.createDirectory(at: screenshotsDirectory, withIntermediateDirectories: true, attributes: nil)
    }
    
    public func createSaveState(
        romHash: String,
        platform: Platform,
        stateData: Data,
        screenshot: Data
    ) throws -> SaveStateMetadata {
        let stateId = UUID()
        let timestamp = Date()
        
        let stateFileName = "\(stateId).sav"
        let statePath = statesDirectory.appendingPathComponent(stateFileName)
        try stateData.write(to: statePath)
        
        let screenshotFileName = "\(stateId).png"
        let screenshotPath = screenshotsDirectory.appendingPathComponent(screenshotFileName)
        try screenshot.write(to: screenshotPath)
        
        let checksum = stateData.md5()
        
        let metadata = SaveStateMetadata(
            stateId: stateId,
            romHash: romHash,
            platform: platform,
            timestamp: timestamp,
            screenshotPath: screenshotPath.path,
            fileSize: stateData.count,
            checksum: checksum
        )
        
        let metadataPath = statesDirectory.appendingPathComponent("\(stateId).json")
        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: metadataPath)
        
        return metadata
    }
    
    public func loadSaveState(stateId: UUID) throws -> SaveState {
        let statePath = statesDirectory.appendingPathComponent("\(stateId).sav")
        let metadataPath = statesDirectory.appendingPathComponent("\(stateId).json")
        
        guard fileManager.fileExists(atPath: statePath.path) else {
            throw SaveStateError.notFound
        }
        
        guard fileManager.fileExists(atPath: metadataPath.path) else {
            throw SaveStateError.notFound
        }
        
        let data = try Data(contentsOf: statePath)
        let metadataData = try Data(contentsOf: metadataPath)
        let decoder = JSONDecoder()
        let metadata = try decoder.decode(SaveStateMetadata.self, from: metadataData)
        
        return SaveState(metadata: metadata, data: data)
    }
    
    public func listSaveStates(forRomHash romHash: String) throws -> [SaveStateMetadata] {
        let files = try fileManager.contentsOfDirectory(at: statesDirectory, includingPropertiesForKeys: nil)
        var metadatas: [SaveStateMetadata] = []
        
        let decoder = JSONDecoder()
        
        for file in files {
            guard file.pathExtension == "json" else { continue }
            
            let metadataData = try Data(contentsOf: file)
            let metadata = try decoder.decode(SaveStateMetadata.self, from: metadataData)
            
            if metadata.romHash == romHash {
                metadatas.append(metadata)
            }
        }
        
        return metadatas.sorted { $0.timestamp > $1.timestamp }
    }
    
    public func deleteSaveState(stateId: UUID) throws {
        let statePath = statesDirectory.appendingPathComponent("\(stateId).sav")
        let metadataPath = statesDirectory.appendingPathComponent("\(stateId).json")
        
        guard fileManager.fileExists(atPath: statePath.path) else {
            throw SaveStateError.notFound
        }
        
        try fileManager.removeItem(at: statePath)
        try fileManager.removeItem(at: metadataPath)
    }
    
    public func getSaveStateCount(forRomHash romHash: String) throws -> Int {
        let metadatas = try listSaveStates(forRomHash: romHash)
        return metadatas.count
    }
}
