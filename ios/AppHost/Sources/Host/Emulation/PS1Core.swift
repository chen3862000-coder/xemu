import Foundation

public class PS1Core: EmulatorCore, @unchecked Sendable {
    public var platform: Platform { .PS1 }
    private var isInitialized = false
    private var isRunning = false
    private var romPath: String?
    
    public init() {}
    
    public func initialize() -> Bool {
        isInitialized = true
        return true
    }
    
    public func loadROM(romPath: String) -> Bool {
        self.romPath = romPath
        return isInitialized
    }
    
    public func start() {
        isRunning = true
    }
    
    public func pause() {
        isRunning = false
    }
    
    public func resume() {
        isRunning = true
    }
    
    public func frame() -> Bool {
        return isRunning
    }
    
    public func stop() {
        isRunning = false
    }
    
    public func cleanup() {
        isInitialized = false
        isRunning = false
    }
    
    public func getFrameBuffer() -> Data? {
        return nil
    }
    
    public func getAudioSamples() -> Data? {
        return nil
    }
    
    public func saveState() -> Data? {
        return nil
    }
    
    public func loadState(_ state: Data) -> Bool {
        return false
    }
    
    public func setInput(_ inputType: Int, value: Float) {}
    public func reset() {}
}
