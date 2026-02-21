import Foundation
#if canImport(XemuCoresLib)
import XemuCoresLib
#endif

public enum XemuCoresError: Error {
    case notInitialized
    case romLoadFailed(String)
    case invalidROM
    case saveStateFailed(String)
    case audioError(String)
    case videoError(String)
    case libraryNotFound
    case libraryLoadFailed(String)
}

public struct XemuCoresVersion {
    public let major: Int32
    public let minor: Int32
    public let patch: Int32
    
    public init(major: Int32, minor: Int32, patch: Int32) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
}

public enum EmulatorSystemType: Int32 {
    case gameBoy = 0
    case gameBoyColor = 1
    case gameBoyAdvance = 2
}

public struct VideoBufferInfo {
    public let width: Int
    public let height: Int
    public let pitch: Int
    public let buffer: UnsafePointer<UInt8>?
    
    public init(width: Int, height: Int, pitch: Int, buffer: UnsafePointer<UInt8>?) {
        self.width = width
        self.height = height
        self.pitch = pitch
        self.buffer = buffer
    }
}

public struct AudioSampleInfo {
    public let sampleCount: Int
    public let sampleRate: Int
    public let samples: UnsafePointer<Int16>?
    
    public init(sampleCount: Int, sampleRate: Int, samples: UnsafePointer<Int16>?) {
        self.sampleCount = sampleCount
        self.sampleRate = sampleRate
        self.samples = samples
    }
}

public struct ROMInfo {
    public let systemType: EmulatorSystemType
    public let title: String
    public let checksum: UInt32
    
    public init(systemType: EmulatorSystemType, title: String, checksum: UInt32) {
        self.systemType = systemType
        self.title = title
        self.checksum = checksum
    }
}

public protocol CEmulatorCore {
    var isInitialized: Bool { get }
    var currentSystem: EmulatorSystemType { get }
    
    func initialize() throws
    func loadROM(data: Data) throws -> ROMInfo
    func unloadROM()
    func step() throws
    func getVideoBuffer() -> VideoBufferInfo
    func getAudioSamples() -> AudioSampleInfo
    func setInput(button: Int, pressed: Bool)
    func getSaveStateData() throws -> Data
    func loadSaveStateData(_ data: Data) throws
    func getBatteryData() throws -> Data
    func loadBatteryData(_ data: Data) throws
    func shutdown()
}

public class XemuCores {
    public static let shared = XemuCores()
    
    public private(set) var version: XemuCoresVersion
    public private(set) var isAvailable: Bool = false
    public private(set) var usingRealCores: Bool = false
    
    private init() {
        version = XemuCoresVersion(major: 0, minor: 1, patch: 0)
    }
    
    public func initialize() -> Bool {
        let useRealCores = ProcessInfo.processInfo.environment["USE_REAL_CORES"] != "false"
        
        if useRealCores {
            isAvailable = true
            usingRealCores = true
            print("[XemuCores] Using REAL cores (direct linking)")
        } else {
            print("[XemuCores] Using MOCK cores")
            isAvailable = true
            usingRealCores = false
        }
        
        return isAvailable
    }
    
    public func createCore(for system: EmulatorSystemType) -> CEmulatorCore? {
        switch system {
        case .gameBoy, .gameBoyColor:
            return GBCCoreWrapper(useNative: usingRealCores)
        case .gameBoyAdvance:
            return GBACoreWrapper(useNative: usingRealCores)
        }
    }
}

public class GBCCoreWrapper: CEmulatorCore {
    private var handle: OpaquePointer?
    private var isROMLoaded = false
    private var currentSystemType: EmulatorSystemType = .gameBoy
    private let useNative: Bool
    private var inputStateMask: UInt32 = 0
    private let nativeLock = NSLock()
    
    public var isInitialized: Bool { handle != nil }
    public var currentSystem: EmulatorSystemType { currentSystemType }
    
    public init(useNative: Bool) {
        self.useNative = useNative
    }
    
    public func initialize() throws {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative {
            handle = xemu_gb_create()
            guard handle != nil else {
                throw XemuCoresError.notInitialized
            }
        } else {
            handle = OpaquePointer(bitPattern: 1)
        }
    }
    
    public func loadROM(data: Data) throws -> ROMInfo {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            let result = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> xemu_error_t in
                let ptr = buffer.bindMemory(to: UInt8.self).baseAddress!
                return xemu_gb_load_rom(handle, nil, ptr, data.count)
            }
            
            guard result == XEMU_OK else {
                throw XemuCoresError.romLoadFailed("Load failed with error: \(result.rawValue)")
            }
            
            isROMLoaded = true
            
            if xemu_gb_is_cgb_mode(handle) != 0 {
                currentSystemType = .gameBoyColor
            } else {
                currentSystemType = .gameBoy
            }
        } else {
            isROMLoaded = true
            if data.count > 0x143 {
                currentSystemType = data[0x143] & 0x80 != 0 ? .gameBoyColor : .gameBoy
            } else {
                currentSystemType = .gameBoy
            }
        }
        
        return ROMInfo(systemType: currentSystemType, title: "Loaded ROM", checksum: 0)
    }
    
    public func unloadROM() {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            xemu_gb_set_input(handle, 0)
            _ = xemu_gb_unload_rom(handle)
        }
        inputStateMask = 0
        isROMLoaded = false
    }
    
    public func step() throws {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            let result = xemu_gb_run_frame(handle)
            guard result == XEMU_OK else {
                throw XemuCoresError.romLoadFailed("Run frame failed with error: \(result.rawValue)")
            }
        }
    }
    
    public func getVideoBuffer() -> VideoBufferInfo {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            let buffer = xemu_gb_get_video_buffer(handle)
            return VideoBufferInfo(
                width: Int(buffer.width),
                height: Int(buffer.height),
                pitch: Int(buffer.pitch),
                buffer: buffer.data.map { UnsafePointer<UInt8>($0) }
            )
        }
        
        return VideoBufferInfo(width: 160, height: 144, pitch: 160 * 4, buffer: nil)
    }

    public func getVideoFrameCopy() -> (data: Data, width: Int, height: Int, pitch: Int)? {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle else { return nil }

        let buffer = xemu_gb_get_video_buffer(handle)
        let width = Int(buffer.width)
        let height = Int(buffer.height)
        let pitch = Int(buffer.pitch)

        guard width > 0, height > 0, pitch > 0, let dataPtr = buffer.data else { return nil }

        let size = pitch * height
        guard size > 0 else { return nil }

        return (Data(bytes: dataPtr, count: size), width, height, pitch)
    }
    
    public func getAudioSamples() -> AudioSampleInfo {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            let buffer = xemu_gb_get_audio_buffer(handle)
            return AudioSampleInfo(
                sampleCount: Int(buffer.sample_count),
                sampleRate: Int(buffer.sample_rate),
                samples: buffer.data.map { UnsafePointer<Int16>($0) }
            )
        }
        
        return AudioSampleInfo(sampleCount: 0, sampleRate: 44100, samples: nil)
    }

    public func getAudioSamplesCopy() -> Data? {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle else { return nil }

        let buffer = xemu_gb_get_audio_buffer(handle)
        guard let samples = buffer.data, buffer.sample_count > 0 else { return nil }

        let sampleCount = Int(buffer.sample_count)
        let size = sampleCount * MemoryLayout<Int16>.size
        guard size > 0 else { return nil }

        return Data(bytes: samples, count: size)
    }
    
    public func setInput(button: Int, pressed: Bool) {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle else { return }
        
        let buttonMap: [Int: UInt32] = [
            0: UInt32(XEMU_BUTTON_A),
            1: UInt32(XEMU_BUTTON_B),
            2: UInt32(XEMU_BUTTON_SELECT),
            3: UInt32(XEMU_BUTTON_START),
            4: UInt32(XEMU_BUTTON_RIGHT),
            5: UInt32(XEMU_BUTTON_LEFT),
            6: UInt32(XEMU_BUTTON_UP),
            7: UInt32(XEMU_BUTTON_DOWN)
        ]
        
        guard let buttonMask = buttonMap[button] else { return }
        if pressed {
            inputStateMask |= buttonMask
        } else {
            inputStateMask &= ~buttonMask
        }
        xemu_gb_set_input(handle, inputStateMask)
    }
    
    public func getSaveStateData() throws -> Data {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else {
            throw XemuCoresError.saveStateFailed("No ROM loaded")
        }
        
        var state = xemu_save_state_t(data: nil, size: 0)
        let result = xemu_gb_save_state(handle, &state)
        
        guard result == XEMU_OK, let data = state.data, state.size > 0 else {
            throw XemuCoresError.saveStateFailed("Failed to save state")
        }
        
        let savedData = Data(bytes: data, count: state.size)
        return savedData
    }
    
    public func loadSaveStateData(_ data: Data) throws {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else {
            throw XemuCoresError.saveStateFailed("No ROM loaded")
        }
        
        var state = xemu_save_state_t(
            data: UnsafeMutablePointer<UInt8>(mutating: (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)),
            size: data.count
        )
        
        let result = xemu_gb_load_state(handle, &state)
        guard result == XEMU_OK else {
            throw XemuCoresError.saveStateFailed("Failed to load state")
        }
    }
    
    public func getBatteryData() throws -> Data {
        return Data()
    }
    
    public func loadBatteryData(_ data: Data) throws {
    }
    
    public func shutdown() {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            xemu_gb_set_input(handle, 0)
            xemu_gb_destroy(handle)
        }
        inputStateMask = 0
        self.handle = nil
    }
}

public class GBACoreWrapper: CEmulatorCore {
    private var handle: OpaquePointer?
    private var isROMLoaded = false
    private let useNative: Bool
    private var inputStateMask: UInt32 = 0
    private let nativeLock = NSLock()
    
    public var isInitialized: Bool { handle != nil }
    public var currentSystem: EmulatorSystemType { .gameBoyAdvance }
    
    public init(useNative: Bool) {
        self.useNative = useNative
    }
    
    public func initialize() throws {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative {
            handle = xemu_gba_create()
            guard handle != nil else {
                throw XemuCoresError.notInitialized
            }
        } else {
            handle = OpaquePointer(bitPattern: 1)
        }
    }
    
    public func loadROM(data: Data) throws -> ROMInfo {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            let result = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> xemu_error_t in
                let ptr = buffer.bindMemory(to: UInt8.self).baseAddress!
                return xemu_gba_load_rom(handle, nil, ptr, data.count)
            }
            
            guard result == XEMU_OK else {
                throw XemuCoresError.romLoadFailed("Load failed with error: \(result.rawValue)")
            }
            
            isROMLoaded = true
        } else {
            isROMLoaded = true
        }
        
        return ROMInfo(systemType: .gameBoyAdvance, title: "Loaded ROM", checksum: 0)
    }
    
    public func unloadROM() {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            xemu_gba_set_input(handle, 0)
            _ = xemu_gba_unload_rom(handle)
        }
        inputStateMask = 0
        isROMLoaded = false
    }
    
    public func step() throws {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            let result = xemu_gba_run_frame(handle)
            guard result == XEMU_OK else {
                throw XemuCoresError.romLoadFailed("Run frame failed with error: \(result.rawValue)")
            }
        }
    }
    
    public func getVideoBuffer() -> VideoBufferInfo {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            let buffer = xemu_gba_get_video_buffer(handle)
            return VideoBufferInfo(
                width: Int(buffer.width),
                height: Int(buffer.height),
                pitch: Int(buffer.pitch),
                buffer: buffer.data.map { UnsafePointer<UInt8>($0) }
            )
        }
        
        return VideoBufferInfo(width: 240, height: 160, pitch: 240 * 4, buffer: nil)
    }

    public func getVideoFrameCopy() -> (data: Data, width: Int, height: Int, pitch: Int)? {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle else { return nil }

        let buffer = xemu_gba_get_video_buffer(handle)
        let width = Int(buffer.width)
        let height = Int(buffer.height)
        let pitch = Int(buffer.pitch)

        guard width > 0, height > 0, pitch > 0, let dataPtr = buffer.data else { return nil }

        let size = pitch * height
        guard size > 0 else { return nil }

        return (Data(bytes: dataPtr, count: size), width, height, pitch)
    }
    
    public func getAudioSamples() -> AudioSampleInfo {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            let buffer = xemu_gba_get_audio_buffer(handle)
            return AudioSampleInfo(
                sampleCount: Int(buffer.sample_count),
                sampleRate: Int(buffer.sample_rate),
                samples: buffer.data.map { UnsafePointer<Int16>($0) }
            )
        }
        
        return AudioSampleInfo(sampleCount: 0, sampleRate: 44100, samples: nil)
    }

    public func getAudioSamplesCopy() -> Data? {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle else { return nil }

        let buffer = xemu_gba_get_audio_buffer(handle)
        guard let samples = buffer.data, buffer.sample_count > 0 else { return nil }

        let sampleCount = Int(buffer.sample_count)
        let size = sampleCount * MemoryLayout<Int16>.size
        guard size > 0 else { return nil }

        return Data(bytes: samples, count: size)
    }
    
    public func setInput(button: Int, pressed: Bool) {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle else { return }
        
        let buttonMap: [Int: UInt32] = [
            0: UInt32(XEMU_BUTTON_A),
            1: UInt32(XEMU_BUTTON_B),
            2: UInt32(XEMU_BUTTON_SELECT),
            3: UInt32(XEMU_BUTTON_START),
            4: UInt32(XEMU_BUTTON_RIGHT),
            5: UInt32(XEMU_BUTTON_LEFT),
            6: UInt32(XEMU_BUTTON_UP),
            7: UInt32(XEMU_BUTTON_DOWN),
            8: UInt32(XEMU_BUTTON_L),
            9: UInt32(XEMU_BUTTON_R)
        ]
        
        guard let buttonMask = buttonMap[button] else { return }
        if pressed {
            inputStateMask |= buttonMask
        } else {
            inputStateMask &= ~buttonMask
        }
        xemu_gba_set_input(handle, inputStateMask)
    }
    
    public func getSaveStateData() throws -> Data {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else {
            throw XemuCoresError.saveStateFailed("No ROM loaded")
        }
        
        var state = xemu_save_state_t(data: nil, size: 0)
        let result = xemu_gba_save_state(handle, &state)
        
        guard result == XEMU_OK, let data = state.data, state.size > 0 else {
            throw XemuCoresError.saveStateFailed("Failed to save state")
        }
        
        let savedData = Data(bytes: data, count: state.size)
        return savedData
    }
    
    public func loadSaveStateData(_ data: Data) throws {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else {
            throw XemuCoresError.saveStateFailed("No ROM loaded")
        }
        
        var state = xemu_save_state_t(
            data: UnsafeMutablePointer<UInt8>(mutating: (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)),
            size: data.count
        )
        
        let result = xemu_gba_load_state(handle, &state)
        guard result == XEMU_OK else {
            throw XemuCoresError.saveStateFailed("Failed to load state")
        }
    }
    
    public func getBatteryData() throws -> Data {
        return Data()
    }
    
    public func loadBatteryData(_ data: Data) throws {
    }
    
    public func shutdown() {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            xemu_gba_set_input(handle, 0)
            xemu_gba_destroy(handle)
        }
        inputStateMask = 0
        self.handle = nil
    }
}
