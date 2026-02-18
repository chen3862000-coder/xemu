import Foundation

/// Protocol that all emulator cores must implement
/// Provides a unified interface for the host to control any supported system
public protocol EmulatorCore: AnyObject {
    
    /// The platform/system this core emulates
    var platform: Platform { get }
    
    /// Initialize the emulator core
    /// - Returns: true if initialization successful, false otherwise
    func initialize() -> Bool
    
    /// Load a ROM file into the emulator
    /// - Parameter romPath: Path to the ROM file to load
    /// - Returns: true if ROM loaded successfully, false otherwise
    func loadROM(romPath: String) -> Bool
    
    /// Start the emulation loop
    /// - Begins continuous frame generation at the core's native framerate
    func start() -> Void
    
    /// Pause emulation
    /// - Suspends the emulation loop without stopping the core
    func pause() -> Void
    
    /// Resume emulation from paused state
    /// - Restarts the emulation loop
    func resume() -> Void
    
    /// Advance emulation by one frame
    /// - Returns: true if frame generated successfully, false on error
    /// - Important: Must be called at the core's native framerate (e.g., 60 FPS for NES)
    func frame() -> Bool
    
    /// Stop emulation and clean up resources
    /// - Terminates the emulation loop and releases allocated memory
    func stop() -> Void
    
    /// Clean up all allocated resources
    /// - Should be called when the emulator is no longer needed
    func cleanup() -> Void
    
    /// Get current frame buffer for rendering
    /// - Returns: Raw pixel data in RGBA format
    /// - Expected size: Depends on core (e.g., NES: 256x240)
    func getFrameBuffer() -> Data?
    
    /// Get audio samples for the current frame
    /// - Returns: Raw audio samples (16-bit signed, stereo)
    func getAudioSamples() -> Data?
    
    /// Get current save state data
    /// - Returns: Serialized emulator state
    func saveState() -> Data?
    
    /// Load save state data
    /// - Parameter state: Serialized emulator state to restore
    /// - Returns: true if state loaded successfully
    func loadState(_ state: Data) -> Bool
    
    /// Set input state for the current frame
    /// - Parameter inputType: Type of input (button, axis, etc.)
    /// - Parameter value: Input value (pressed/released or axis value)
    func setInput(_ inputType: Int, value: Float)
    
    /// Reset the emulator to initial state
    /// - Equivalent to power-cycling the console
    func reset() -> Void
}

// MARK: - Default Implementation stubs

extension EmulatorCore {
    public func start() {}
    public func pause() {}
    public func resume() {}
    public func stop() {}
    public func cleanup() {}
    public func getFrameBuffer() -> Data? { nil }
    public func getAudioSamples() -> Data? { nil }
    public func saveState() -> Data? { nil }
    public func loadState(_ state: Data) -> Bool { false }
    public func setInput(_ inputType: Int, value: Float) {}
    public func reset() {}
}
