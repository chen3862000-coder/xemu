import Foundation
#if canImport(XemuCores)
import XemuCores
#endif

// Debug logging toggle - set to true to enable debug logs
private let DEBUG_LOGS_ENABLED = false

private func debugLog(_ format: String, _ args: CVarArg...) {
    guard DEBUG_LOGS_ENABLED else { return }
    NSLog(format, args)
}

public final class GBCore: EmulatorCore {
    public var platform: Platform { .GB }
    
    private var coreWrapper: GBCCoreWrapper?
    private var isRunning: Bool = false
    private var isPaused: Bool = false
    private var loadedROMData: Data?
    private var loadedROMPath: String?
    private var inputState: [Int: Float] = [:]
    
    public init() {
        debugLog("[GBCore] Initialized with real core support")
    }
    
    public func initialize() -> Bool {
        debugLog("[GBCore] Initialize")
        do {
            XemuCores.shared.initialize()
            debugLog("[GBCore] XemuCores initialized, usingRealCores: %d", XemuCores.shared.usingRealCores)
            coreWrapper = XemuCores.shared.createCore(for: .gameBoy) as? GBCCoreWrapper
            try coreWrapper?.initialize()
            debugLog("[GBCore] Core wrapper initialized")
            return true
        } catch {
            debugLog("[GBCore] Failed to initialize: %@", error.localizedDescription)
            return false
        }
    }
    
    public func loadROM(romPath: String) -> Bool {
        debugLog("[GBCore] Loading ROM from: %@", romPath)
        
        guard FileManager.default.fileExists(atPath: romPath) else {
            debugLog("[GBCore] ROM file not found")
            return false
        }
        
        do {
            let romData = try Data(contentsOf: URL(fileURLWithPath: romPath))
            loadedROMData = romData
            loadedROMPath = romPath
            
            let romInfo = try coreWrapper?.loadROM(data: romData)
            debugLog("[GBCore] ROM loaded: %@ (%d bytes)", romInfo?.title ?? "Unknown", romData.count)
            
            isRunning = true
            isPaused = false
            return true
        } catch {
            debugLog("[GBCore] Failed to load ROM: %@", error.localizedDescription)
            return false
        }
    }
    
    public func start() {
        isRunning = true
        isPaused = false
        debugLog("[GBCore] Started")
    }
    
    public func pause() {
        isPaused = true
        debugLog("[GBCore] Paused")
    }
    
    public func resume() {
        isPaused = false
        debugLog("[GBCore] Resumed")
    }
    
    public func frame() -> Bool {
        guard isRunning && !isPaused else { return false }
        
        do {
            try coreWrapper?.step()
            return true
        } catch let error as XemuCoresError {
            debugLog("[GBCore] Frame error (XemuCoresError): %@", error.localizedDescription)
            return false
        } catch {
            debugLog("[GBCore] Frame error: %@", error.localizedDescription)
            return false
        }
    }
    
    public func stop() {
        isRunning = false
        debugLog("[GBCore] Stopped")
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
        coreWrapper?.getAudioSamplesCopy()
    }
    
    public func saveState() -> Data? {
        do {
            let stateData = try coreWrapper?.getSaveStateData()
            debugLog("[GBCore] Save state: %d bytes", stateData?.count ?? 0)
            return stateData
        } catch {
            debugLog("[GBCore] Save state failed: %@", error.localizedDescription)
            return nil
        }
    }
    
    public func loadState(_ state: Data) -> Bool {
        do {
            try coreWrapper?.loadSaveStateData(state)
            debugLog("[GBCore] Load state: %d bytes", state.count)
            return true
        } catch {
            debugLog("[GBCore] Load state failed: %@", error.localizedDescription)
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
        
        guard let mappedButton = buttonMap[inputType] else {
            NSLog("[InputTrace][GBCore] unmapped inputType=\(inputType) pressed=\(pressed)")
            return
        }
        NSLog("[InputTrace][GBCore] inputType=\(inputType) mappedButton=\(mappedButton) pressed=\(pressed)")
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
            debugLog("[GBCore] Reset")
        } catch {
            debugLog("[GBCore] Reset failed: %@", error.localizedDescription)
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
        debugLog("[GBCore] Cleaned up")
    }
}
