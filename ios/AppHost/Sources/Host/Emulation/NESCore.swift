import Foundation
#if os(iOS)
import UIKit
#endif
import MetalKit

public final class NESCore: EmulatorCore, @unchecked Sendable {
    public enum NESError: LocalizedError {
        case invalidROMFormat
        case coreInitializationFailed
        case loadFailed
        case saveStateFailed
        case loadStateFailed
        
        public var errorDescription: String? {
            switch self {
            case .invalidROMFormat:
                return "Invalid NES ROM format"
            case .coreInitializationFailed:
                return "Failed to initialize NES emulator core"
            case .loadFailed:
                return "Failed to load NES ROM"
            case .saveStateFailed:
                return "Failed to create save state"
            case .loadStateFailed:
                return "Failed to load save state"
            }
        }
    }
    
    private struct NESHeader {
        static let headerSize = 16
        static let magicBytes: [UInt8] = [0x4E, 0x45, 0x53, 0x1A]
        
        let isValid: Bool
        let mapperNumber: UInt8
        let hasTrainer: Bool
        let hasBattery: Bool
        let hasVSUnisystem: Bool
        let hasPlayChoice10: Bool
        let mirroring: UInt8
        
        init?(_ data: Data) {
            guard data.count >= NESHeader.headerSize else { return nil }
            
            let magic = data.prefix(4)
            guard magic == Data(NESHeader.magicBytes) else { return nil }
            
            let flags = data[6]
            let flags2 = data[7]
            
            isValid = true
            mapperNumber = data[4]
            hasTrainer = (flags & 0x04) != 0
            hasBattery = (flags & 0x02) != 0
            hasVSUnisystem = (flags & 0x01) != 0
            hasPlayChoice10 = (flags2 & 0x10) != 0
            mirroring = (flags & 0xF0) >> 4
        }
    }
    
    private var romData: Data?
    private var header: NESHeader?
    private var isRunning = false
    private var isPaused = false
    private var frameBuffer: [UInt8] = []
    private var audioBuffer: [Int16] = []
    private let frameBufferWidth = 256
    private let frameBufferHeight = 240
    
    private let frameRate: Double = 60.098811
    
    public var platform: Platform { .NES }
    
    public var isROMLoaded: Bool { romData != nil }
    
    public var currentFrameBuffer: [UInt8]? { frameBuffer }
    
    public var currentAudioBuffer: [Int16]? { audioBuffer }
    
    public var supportsFastForward: Bool { false }
    
    public var supportsRewind: Bool { false }
    
    public init() {}
    
    // MARK: - EmulatorCore Protocol Conformance
    
    public func initialize() -> Bool {
        return true
    }
    
    public func loadROM(romPath: String) -> Bool {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: romPath)) else {
            return false
        }
        do {
            try loadROM(data)
            return true
        } catch {
            return false
        }
    }
    
    public func frame() -> Bool {
        guard isRunning && !isPaused else { return false }
        
        if romData != nil {
            do {
                try simulateFrame()
                return true
            } catch {
                return false
            }
        }
        return false
    }
    
    public func loadROM(_ data: Data) throws {
        guard let header = NESHeader(data) else {
            throw NESError.invalidROMFormat
        }
        
        self.header = header
        self.romData = data
        self.frameBuffer = Array(repeating: 0, count: frameBufferWidth * frameBufferHeight)
        self.audioBuffer = Array(repeating: 0, count: 735)
        
        print("NES ROM loaded: Mapper=\(header.mapperNumber), Battery=\(header.hasBattery)")
    }
    
    public func start() throws {
        guard romData != nil else {
            throw NESError.coreInitializationFailed
        }
        isRunning = true
        isPaused = false
        print("NES emulation started")
    }
    
    public func pause() throws {
        guard isRunning else { throw NESError.coreInitializationFailed }
        isPaused = true
        print("NES emulation paused")
    }
    
    public func resume() throws {
        guard isRunning && isPaused else { throw NESError.coreInitializationFailed }
        isPaused = false
        print("NES emulation resumed")
    }
    
    public func frame() throws {
        guard isRunning && !isPaused else { return }
        
        if let romData = romData {
            simulateFrame()
        }
    }
    
    public func stop() throws {
        guard isRunning else { throw NESError.coreInitializationFailed }
        isRunning = false
        isPaused = false
        print("NES emulation stopped")
    }
    
    public func cleanup() throws {
        romData = nil
        frameBuffer.removeAll()
        audioBuffer.removeAll()
        isRunning = false
        isPaused = false
        print("NES emulation cleaned up")
    }
    
    public func saveState() throws -> Data {
        guard isRunning else {
            throw NESError.saveStateFailed
        }

        var state = Data()
        state.append(contentsOf: frameBuffer)
        state.append(contentsOf: serializeEmulatorState())

        return state
    }
    
    public func loadState(_ state: Data) throws {
        guard isRunning else {
            throw NESError.loadStateFailed
        }
        
        let frameBufferSize = frameBufferWidth * frameBufferHeight
        guard state.count >= frameBufferSize else {
            throw NESError.loadStateFailed
        }
        
        frameBuffer = Array(state.prefix(frameBufferSize))
        deserializeEmulatorState(Array(state.dropFirst(frameBufferSize)))
        
        print("NES state loaded: \(state.count) bytes")
    }
    
    public func reset() throws {
        guard romData != nil else { throw NESError.coreInitializationFailed }
        print("NES emulation reset")
    }
    
    private func simulateFrame() {
        let pattern = 0xA5
        let stride = frameBufferWidth
        
        for y in 0..<frameBufferHeight {
            for x in 0..<frameBufferWidth {
                let index = y * stride + x
                let colorValue = UInt8.random(in: 0...255)
                frameBuffer[index] = colorValue
            }
        }
        
        let audioValue = Int16.random(in: -32768...32767)
        for i in 0..<735 {
            audioBuffer[i] = audioValue
        }
    }
    
    private func serializeEmulatorState() -> [UInt8] {
        var state: [UInt8] = []
        if let header = header {
            state.append(header.mapperNumber)
            state.append(header.hasTrainer ? 1 : 0)
            state.append(header.hasBattery ? 1 : 0)
        }
        return state
    }
    
    private func deserializeEmulatorState(_ data: [UInt8]) {
        guard data.count >= 3 else { return }
        let mapperNumber = data[0]
        let hasTrainer = data[1] != 0
        let hasBattery = data[2] != 0
        print("Deserialized NES state: Mapper=\(mapperNumber), Trainer=\(hasTrainer), Battery=\(hasBattery)")
    }
}
