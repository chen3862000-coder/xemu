import Foundation
import MetalKit
import CryptoKit
import Network
import Combine

public protocol EmulationCore {
    var platform: Platform { get }
}

public final class StableSystemsCoordinator: @unchecked Sendable {
    public enum CoreError: Error, Equatable {
        case unsupportedPlatform
        case noCoreLoaded
        case romLoadFailed
        case noROMLoaded
        case saveStateLoadFailed
        case coreAlreadyLoaded
    }
    private let inputBus: InputBus
    private let saveStateStorage: SaveStateStorage
    
    public var activeCore: EmulationCore?
    public var targetFrameRate: Int = 60
    public var audioBuffer: MTLBuffer?
    
    private var currentROMURL: URL?
    private var isEmulating: Bool = false
    
    public init(inputBus: InputBus, saveStateStorage: SaveStateStorage) {
        self.inputBus = inputBus
        self.saveStateStorage = saveStateStorage
    }
    
    public func loadCore(for platform: Platform) throws {
        if activeCore != nil {
            activeCore = nil
        }
        
        guard platform != .PS2 else {
            throw CoreError.unsupportedPlatform
        }
        
        activeCore = StubCore(platform: platform)
    }
    
    public func loadROM(at url: URL) throws {
        guard activeCore != nil else {
            throw CoreError.noCoreLoaded
        }
        
        currentROMURL = url
    }
    
    public func startEmulation(on view: MTKView) throws {
        guard let core = activeCore else {
            throw CoreError.noCoreLoaded
        }
        
        guard currentROMURL != nil else {
            throw CoreError.noROMLoaded
        }
        
        isEmulating = true
        setupInputHandling()
        
        let audioBufferSize = 4096 * MemoryLayout<Float>.size
        audioBuffer = view.device?.makeBuffer(length: audioBufferSize, options: .storageModeShared)
    }
    
    public func pauseEmulation() {
        isEmulating = false
    }
    
    public func stopEmulation() {
        isEmulating = false
        currentROMURL = nil
    }
    
    public func saveState(at url: URL) throws -> URL {
        guard let core = activeCore else {
            throw CoreError.noCoreLoaded
        }
        
        guard let romURL = currentROMURL else {
            throw CoreError.noROMLoaded
        }
        
        let data = try Data(contentsOf: romURL)
        let hash = try computeSHA256Hash(for: data)
        let metadata = SaveStateMetadata(
            stateId: UUID(),
            romHash: hash,
            platform: core.platform,
            timestamp: Date(),
            screenshotPath: "",
            fileSize: data.count,
            checksum: data.md5()
        )
        
        let encoder = JSONEncoder()
        let metadataData = try encoder.encode(metadata)
        try metadataData.write(to: url)
        
        return url
    }
    
    public func loadState(from url: URL) throws {
        guard activeCore != nil else {
            throw CoreError.noCoreLoaded
        }
    }
    
    public func setupInputHandling() {
        inputBus.events.sink { event in
            
        }.store(in: &cancellables)
    }
    
    public func resetEmulation() {
        
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func computeSHA256Hash(for data: Data) throws -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

private class StubCore: EmulationCore {
    let platform: Platform
    
    init(platform: Platform) {
        self.platform = platform
    }
}

public class ImportPersistence {
    nonisolated(unsafe) static let shared = ImportPersistence()
}
