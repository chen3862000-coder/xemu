import Foundation
#if canImport(XemuCores)
import XemuCores
#endif

public final class GBACore: EmulatorCore {
    public var platform: Platform { .GBA }
    
    private var coreWrapper: GBACoreWrapper?
    private var isRunning: Bool = false
    private var isPaused: Bool = false
    private var loadedROMData: Data?
    private var loadedROMPath: String?
    private var inputState: [Int: Float] = [:]
    
    public init() {
        // Debug log disabled: NSLog("[GBACore] Initialized with real core support")
    }
    
    public func initialize() -> Bool {
        // Debug log disabled: NSLog("[GBACore] Initialize")
        do {
            XemuCores.shared.initialize()
            // Debug log disabled: NSLog("[GBACore] XemuCores initialized, usingRealCores: %d", XemuCores.shared.usingRealCores)
            coreWrapper = XemuCores.shared.createCore(for: .gameBoyAdvance) as? GBACoreWrapper
            try coreWrapper?.initialize()
            // Debug log disabled: NSLog("[GBACore] Core wrapper initialized")
            return true
        } catch {
            // Debug log disabled: NSLog("[GBACore] Failed to initialize: %@", error.localizedDescription)
            return false
        }
    }
    
    public func loadROM(romPath: String) -> Bool {
        // Debug log disabled: NSLog("[GBACore] Loading ROM from: %@", romPath)
        
        guard FileManager.default.fileExists(atPath: romPath) else {
            // Debug log disabled: NSLog("[GBACore] ROM file not found")
            return false
        }
        
        do {
            let romData = try Data(contentsOf: URL(fileURLWithPath: romPath))
            loadedROMData = romData
            loadedROMPath = romPath
            
            let romInfo = try coreWrapper?.loadROM(data: romData)
            // Debug log disabled: NSLog("[GBACore] ROM loaded: %@ (%d bytes)", romInfo?.title ?? "Unknown", romData.count)
            
            isRunning = true
            isPaused = false
            return true
        } catch {
            // Debug log disabled: NSLog("[GBACore] Failed to load ROM: %@", error.localizedDescription)
            return false
        }
    }
    
    public func start() {
        isRunning = true
        isPaused = false
        // Debug log disabled: NSLog("[GBACore] Started")
    }
    
    public func pause() {
        isPaused = true
        // Debug log disabled: NSLog("[GBACore] Paused")
    }
    
    public func resume() {
        isPaused = false
        // Debug log disabled: NSLog("[GBACore] Resumed")
    }
    
    public func frame() -> Bool {
        guard isRunning && !isPaused else { return false }
        
        do {
            try coreWrapper?.step()
            return true
        } catch {
            // Debug log disabled: NSLog("[GBACore] Frame error: %@", error.localizedDescription)
            return false
        }
    }
    
    public func stop() {
        isRunning = false
        // Debug log disabled: NSLog("[GBACore] Stopped")
    }
    
    public func cleanup() {
        coreWrapper?.shutdown()
        coreWrapper = nil
        loadedROMData = nil
        loadedROMPath = nil
        // Debug log disabled: NSLog("[GBACore] Cleaned up")
    }
    
    public func getFrameBuffer() -> Data? {
        guard let frame = coreWrapper?.getVideoFrameCopy() else { return nil }
        return frame.data
    }
    
    public func getAudioSamples() -> Data? {
        coreWrapper?.getAudioSamplesCopy()
    }
    
    public func saveState() -> Data? {
        do {
            let stateData = try coreWrapper?.getSaveStateData()
            // Debug log disabled: NSLog("[GBACore] Save state: %d bytes", stateData?.count ?? 0)
            return stateData
        } catch {
            // Debug log disabled: NSLog("[GBACore] Save state failed: %@", error.localizedDescription)
            return nil
        }
    }
    
    public func loadState(_ state: Data) -> Bool {
        do {
            try coreWrapper?.loadSaveStateData(state)
            // Debug log disabled: NSLog("[GBACore] Load state: %d bytes", state.count)
            return true
        } catch {
            // Debug log disabled: NSLog("[GBACore] Load state failed: %@", error.localizedDescription)
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
            4: 8,   // L
            5: 9,   // R
            6: 2,   // Select
            7: 3,   // Start
            9: 8,   // L2 -> L
            10: 9,  // R2 -> R
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
            // Debug log disabled: NSLog("[GBACore] Reset")
        } catch {
            // Debug log disabled: NSLog("[GBACore] Reset failed: %@", error.localizedDescription)
        }
    }

    public func getFrameBufferInfo() -> FrameBufferInfo? {
        guard let frame = coreWrapper?.getVideoFrameCopy() else { return nil }

        return FrameBufferInfo(
            data: frame.data,
            width: frame.width,
            height: frame.height,
            pitch: frame.pitch
        )
    }
}
