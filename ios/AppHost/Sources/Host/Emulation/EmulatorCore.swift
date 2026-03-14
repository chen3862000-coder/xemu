import Foundation

/// Information about a frame buffer, returned together to avoid race conditions
public struct FrameBufferInfo {
    /// Raw pixel data in RGBA format
    public let data: Data
    /// Width in pixels
    public let width: Int
    /// Height in pixels
    public let height: Int
    /// Bytes per row (pitch) - may be larger than width * 4 due to alignment
    public let pitch: Int
    
    public init(data: Data, width: Int, height: Int, pitch: Int) {
        self.data = data
        self.width = width
        self.height = height
        self.pitch = pitch
    }
    
    /// Validates the frame buffer data size matches the expected size
    public var isValid: Bool {
        let expectedSize = pitch * height
        return data.count >= expectedSize && width > 0 && height > 0 && pitch >= width * 4
    }
}

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
    
    /// Get current frame buffer with dimensions (preferred method to avoid race conditions)
    /// - Returns: FrameBufferInfo containing data, width, height, and pitch
    /// - Note: This method should be preferred over getFrameBuffer() to ensure
    ///   dimensions are always consistent with the returned data
    func getFrameBufferInfo() -> FrameBufferInfo?
    
    /// Get audio samples for the current frame
    /// - Returns: Raw audio samples (16-bit signed, stereo)
    func getAudioSamples() -> Data?

    /// Get the current audio sample rate reported by the core.
    /// - Returns: Sample rate in Hz (e.g. 32768, 44100).
    func getAudioSampleRate() -> Int
    
    /// Get current save state data
    /// - Returns: Serialized emulator state
    func saveState() -> Data?
    
    /// Load save state data
    /// - Parameter state: Serialized emulator state to restore
    /// - Returns: true if state loaded successfully
    func loadState(_ state: Data) -> Bool

    /// Export native in-game battery save RAM.
    /// - Returns: Raw battery save payload (.sav-style), or nil when unsupported.
    func exportBatterySave() -> Data?

    /// Restore native in-game battery save RAM.
    /// - Parameter data: Raw battery save payload.
    /// - Returns: true when applied successfully.
    func importBatterySave(_ data: Data) -> Bool
    
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
    public func getFrameBufferInfo() -> FrameBufferInfo? { nil }
    public func getAudioSamples() -> Data? { nil }
    public func getAudioSampleRate() -> Int { 44_100 }
    public func saveState() -> Data? { nil }
    public func loadState(_ state: Data) -> Bool { false }
    public func exportBatterySave() -> Data? { nil }
    public func importBatterySave(_ data: Data) -> Bool { false }
    public func setInput(_ inputType: Int, value: Float) {}
    public func reset() {}
}
