import Foundation
#if canImport(XemuCores)
import XemuCores
#endif

public final class GBCore: EmulatorCore {
    public static let nativeAudioSampleRate = 65_536
    public var platform: Platform { .GB }
    public var isCGBModeDetected: Bool {
        coreWrapper?.currentSystem == .gameBoyColor
    }
    
    private var coreWrapper: GBCCoreWrapper?
    private var isRunning: Bool = false
    private var isPaused: Bool = false
    private var loadedROMData: Data?
    private var loadedROMPath: String?
    private var lastAudioSampleRate: Int = GBCore.nativeAudioSampleRate
    private var inputState: [Int: Float] = [:]
    
    public init() {}
    
    public func initialize() -> Bool {
        do {
            XemuCores.shared.initialize()
            coreWrapper = XemuCores.shared.createCore(for: .gameBoy) as? GBCCoreWrapper
            try coreWrapper?.initialize()
            return true
        } catch {
            return false
        }
    }
    
    public func loadROM(romPath: String) -> Bool {
        guard FileManager.default.fileExists(atPath: romPath) else {
            return false
        }
        
        do {
            let romData = try Data(contentsOf: URL(fileURLWithPath: romPath))
            loadedROMData = romData
            loadedROMPath = romPath
            
            _ = try coreWrapper?.loadROM(data: romData)
            
            isRunning = true
            isPaused = false
            return true
        } catch {
            return false
        }
    }
    
    public func start() {
        isRunning = true
        isPaused = false
    }
    
    public func pause() {
        isPaused = true
    }
    
    public func resume() {
        isPaused = false
    }
    
    public func frame() -> Bool {
        guard isRunning && !isPaused else { return false }
        
        do {
            try coreWrapper?.step()
            return true
        } catch {
            return false
        }
    }
    
    public func stop() {
        isRunning = false
    }
    
    public func getFrameBuffer() -> Data? {
        guard let frame = coreWrapper?.getVideoFrameCopy() else { return nil }
        return frame.data
    }
    
    public func getVideoInfo() -> (width: Int, height: Int, pitch: Int)? {
        guard let frame = coreWrapper?.getVideoFrameCopy() else { return nil }
        return (width: frame.width, height: frame.height, pitch: frame.pitch)
    }
    
    /// Override to ensure atomic access to framebuffer with dimensions
    /// This prevents the race condition where dimensions could change between
    /// getFrameBuffer() and getVideoInfo() calls
    public func getFrameBufferInfo() -> FrameBufferInfo? {
        guard let frame = coreWrapper?.getVideoFrameCopy() else { return nil }
        
        return FrameBufferInfo(
            data: frame.data,
            width: frame.width,
            height: frame.height,
            pitch: frame.pitch
        )
    }
    
    public func getAudioSamples() -> Data? {
        guard let info = coreWrapper?.getAudioSamples(),
              info.sampleCount > 0,
              let samples = info.samples else {
            return nil
        }
        if info.sampleRate > 0 {
            lastAudioSampleRate = info.sampleRate
        }
        let size = info.sampleCount * MemoryLayout<Int16>.size
        guard size > 0 else { return nil }
        return Data(bytes: samples, count: size)
    }

    public func getAudioSampleRate() -> Int {
        max(8_000, lastAudioSampleRate)
    }
    
    public func saveState() -> Data? {
        do {
            return try coreWrapper?.getSaveStateData()
        } catch {
            return nil
        }
    }
    
    public func loadState(_ state: Data) -> Bool {
        do {
            try coreWrapper?.loadSaveStateData(state)
            return true
        } catch {
            return false
        }
    }

    public func exportBatterySave() -> Data? {
        do {
            return try coreWrapper?.getBatteryData()
        } catch {
            return nil
        }
    }

    public func importBatterySave(_ data: Data) -> Bool {
        do {
            try coreWrapper?.loadBatteryData(data)
            return true
        } catch {
            return false
        }
    }
    
    public func setInput(_ inputType: Int, value: Float) {
        inputState[inputType] = value
        
        let pressed = value > 0.5
        
        let buttonMap: [Int: Int] = [
            0: 0,   // A
            1: 1,   // B
            2: 0,   // X -> A
            3: 1,   // Y -> B
            6: 2,   // Select
            7: 3,   // Start
            11: 6,  // D-pad Up
            12: 7,  // D-pad Down
            13: 5,  // D-pad Left
            14: 4   // D-pad Right
        ]
        
        guard let mappedButton = buttonMap[inputType] else { return }
        coreWrapper?.setInput(button: mappedButton, pressed: pressed)
    }
    
    public func reset() {
        do {
            try coreWrapper?.initialize()
            if let romData = loadedROMData {
                _ = try? coreWrapper?.loadROM(data: romData)
            }
            isRunning = true
            isPaused = false
            inputState = [:]
        } catch {
        }
    }
    
    public func cleanup() {
        coreWrapper?.shutdown()
        coreWrapper = nil
        loadedROMData = nil
        loadedROMPath = nil
        isRunning = false
        isPaused = false
        inputState = [:]
    }
}
