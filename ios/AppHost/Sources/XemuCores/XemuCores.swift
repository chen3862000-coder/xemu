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
    case nintendoDS = 3
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

// Memory regions for game state analysis
public enum MemoryRegion: Int32 {
    case systemRAM = 0
    case workRAM
    case videoRAM
    case cartridgeRAM
    case saveRAM
}

// Memory access info
public struct MemoryAccessInfo {
    public let data: UnsafePointer<UInt8>?
    public let size: Int

    public init(data: UnsafePointer<UInt8>?, size: Int) {
        self.data = data
        self.size = size
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

public enum NDSScreenLayout: Int32, Sendable {
    case stacked = 0
    case sideBySide = 1
    case topOnly = 2
    case bottomOnly = 3
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
        } else {
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
        case .nintendoDS:
            return NDSCoreWrapper(useNative: usingRealCores)
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
                guard let ptr = buffer.bindMemory(to: UInt8.self).baseAddress, data.count > 0 else {
                    return XEMU_ERROR_UNKNOWN
                }
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

    public func readMemory8(address: UInt16) -> UInt8? {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else { return nil }

        var value: UInt8 = 0
        let result = xemu_gb_read_memory8(handle, address, &value)
        return result == XEMU_OK ? value : nil
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

        let stateSize = xemu_gb_get_save_state_size(handle)
        guard stateSize > 0 else {
            throw XemuCoresError.saveStateFailed("Invalid save state size")
        }

        var buffer = Data(count: stateSize)
        var result: xemu_error_t = XEMU_ERROR_UNKNOWN
        buffer.withUnsafeMutableBytes { raw in
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var state = xemu_save_state_t(data: ptr, size: stateSize)
            result = xemu_gb_save_state(handle, &state)
        }

        guard result == XEMU_OK else {
            throw XemuCoresError.saveStateFailed("Failed to save state")
        }

        return buffer
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
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else {
            return Data()
        }

        let batterySize = xemu_gb_get_battery_save_size(handle)
        guard batterySize > 0 else {
            return Data()
        }

        var buffer = Data(count: batterySize)
        var result: xemu_error_t = XEMU_ERROR_UNKNOWN
        buffer.withUnsafeMutableBytes { raw in
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var battery = xemu_save_state_t(data: ptr, size: batterySize)
            result = xemu_gb_save_battery(handle, &battery)
        }

        guard result == XEMU_OK else {
            throw XemuCoresError.saveStateFailed("Failed to export GB battery save")
        }

        return buffer
    }
    
    public func loadBatteryData(_ data: Data) throws {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else { return }
        guard !data.isEmpty else { return }

        var battery = xemu_save_state_t(
            data: UnsafeMutablePointer<UInt8>(mutating: (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)),
            size: data.count
        )

        let result = xemu_gb_load_battery(handle, &battery)
        guard result == XEMU_OK else {
            throw XemuCoresError.saveStateFailed("Failed to import GB battery save")
        }
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
                guard let ptr = buffer.bindMemory(to: UInt8.self).baseAddress, data.count > 0 else {
                    return XEMU_ERROR_UNKNOWN
                }
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

        let stateSize = xemu_gba_get_save_state_size(handle)
        guard stateSize > 0 else {
            throw XemuCoresError.saveStateFailed("Invalid save state size")
        }

        var buffer = Data(count: stateSize)
        var result: xemu_error_t = XEMU_ERROR_UNKNOWN
        buffer.withUnsafeMutableBytes { raw in
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var state = xemu_save_state_t(data: ptr, size: stateSize)
            result = xemu_gba_save_state(handle, &state)
        }

        guard result == XEMU_OK else {
            throw XemuCoresError.saveStateFailed("Failed to save state")
        }

        return buffer
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
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else {
            return Data()
        }

        let batterySize = xemu_gba_get_battery_save_size(handle)
        guard batterySize > 0 else {
            return Data()
        }

        var buffer = Data(count: batterySize)
        var result: xemu_error_t = XEMU_ERROR_UNKNOWN
        buffer.withUnsafeMutableBytes { raw in
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var battery = xemu_save_state_t(data: ptr, size: batterySize)
            result = xemu_gba_save_battery(handle, &battery)
        }

        guard result == XEMU_OK else {
            throw XemuCoresError.saveStateFailed("Failed to export GBA battery save")
        }

        return buffer
    }
    
    public func loadBatteryData(_ data: Data) throws {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else { return }
        guard !data.isEmpty else { return }

        var battery = xemu_save_state_t(
            data: UnsafeMutablePointer<UInt8>(mutating: (data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count)),
            size: data.count
        )

        let result = xemu_gba_load_battery(handle, &battery)
        guard result == XEMU_OK else {
            throw XemuCoresError.saveStateFailed("Failed to import GBA battery save")
        }
    }

    public func readMemory8(address: UInt32) -> UInt8? {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else { return nil }
        var value: UInt8 = 0
        let result = xemu_gba_read_memory8(handle, address, &value)
        return result == XEMU_OK ? value : nil
    }

    public func readMemory16(address: UInt32) -> UInt16? {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else { return nil }
        var value: UInt16 = 0
        let result = xemu_gba_read_memory16(handle, address, &value)
        return result == XEMU_OK ? value : nil
    }

    public func readMemory32(address: UInt32) -> UInt32? {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else { return nil }
        var value: UInt32 = 0
        let result = xemu_gba_read_memory32(handle, address, &value)
        return result == XEMU_OK ? value : nil
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

public final class NDSCoreWrapper: CEmulatorCore {
    private var handle: OpaquePointer?
    private var isROMLoaded = false
    private let useNative: Bool
    private var inputStateMask: UInt32 = 0
    private let nativeLock = NSLock()

    public var isInitialized: Bool { handle != nil }
    public var currentSystem: EmulatorSystemType { .nintendoDS }

    public init(useNative: Bool) {
        self.useNative = useNative
    }

    public func initialize() throws {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative {
            handle = xemu_nds_create()
            guard handle != nil else {
                throw XemuCoresError.notInitialized
            }
            _ = xemu_nds_set_screen_layout(handle, XEMU_NDS_SCREEN_LAYOUT_STACKED)
        } else {
            handle = OpaquePointer(bitPattern: 1)
        }
    }

    public func loadROM(data: Data, filePath: String? = nil) throws -> ROMInfo {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            let result: xemu_error_t
            if let filePath {
                result = filePath.withCString { cPath in
                    data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> xemu_error_t in
                        guard let ptr = buffer.bindMemory(to: UInt8.self).baseAddress, data.count > 0 else {
                            return XEMU_ERROR_UNKNOWN
                        }
                        return xemu_nds_load_rom(handle, cPath, ptr, data.count)
                    }
                }
            } else {
                result = data.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) -> xemu_error_t in
                    guard let ptr = buffer.bindMemory(to: UInt8.self).baseAddress, data.count > 0 else {
                        return XEMU_ERROR_UNKNOWN
                    }
                    return xemu_nds_load_rom(handle, nil, ptr, data.count)
                }
            }

            guard result == XEMU_OK else {
                throw XemuCoresError.romLoadFailed("NDS load failed with error: \(result.rawValue)")
            }

            isROMLoaded = true
        } else {
            // Mock/fallback path for development before native backend integration.
            isROMLoaded = true
        }

        return ROMInfo(systemType: .nintendoDS, title: "Loaded NDS ROM", checksum: 0)
    }

    public func loadROM(data: Data) throws -> ROMInfo {
        try loadROM(data: data, filePath: nil)
    }

    public func unloadROM() {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            xemu_nds_set_input(handle, 0)
            _ = xemu_nds_unload_rom(handle)
        }
        inputStateMask = 0
        isROMLoaded = false
    }

    public func step() throws {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            let result = xemu_nds_run_frame(handle)
            // During scaffold stage, the native stub returns NOT_INITIALIZED but still
            // emits placeholder video for host pipeline validation.
            if result != XEMU_OK && result != XEMU_ERROR_NOT_INITIALIZED {
                throw XemuCoresError.romLoadFailed("NDS run frame failed with error: \(result.rawValue)")
            }
        }
    }

    public func getVideoBuffer() -> VideoBufferInfo {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            let buffer = xemu_nds_get_video_buffer(handle)
            return VideoBufferInfo(
                width: Int(buffer.width),
                height: Int(buffer.height),
                pitch: Int(buffer.pitch),
                buffer: buffer.data.map { UnsafePointer<UInt8>($0) }
            )
        }

        return VideoBufferInfo(width: 256, height: 384, pitch: 256 * 4, buffer: nil)
    }

    public func getVideoFrameCopy() -> (data: Data, width: Int, height: Int, pitch: Int)? {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle else { return nil }

        let buffer = xemu_nds_get_video_buffer(handle)
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
            let buffer = xemu_nds_get_audio_buffer(handle)
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

        let buffer = xemu_nds_get_audio_buffer(handle)
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
            2: UInt32(XEMU_BUTTON_X),
            3: UInt32(XEMU_BUTTON_Y),
            6: UInt32(XEMU_BUTTON_SELECT),
            7: UInt32(XEMU_BUTTON_START),
            11: UInt32(XEMU_BUTTON_UP),
            12: UInt32(XEMU_BUTTON_DOWN),
            13: UInt32(XEMU_BUTTON_LEFT),
            14: UInt32(XEMU_BUTTON_RIGHT),
            4: UInt32(XEMU_BUTTON_L),
            5: UInt32(XEMU_BUTTON_R),
            9: UInt32(XEMU_BUTTON_L),
            10: UInt32(XEMU_BUTTON_R)
        ]

        guard let mask = buttonMap[button] else { return }
        if pressed {
            inputStateMask |= mask
        } else {
            inputStateMask &= ~mask
        }
        xemu_nds_set_input(handle, inputStateMask)
    }

    public func setTouch(x: Int, y: Int, pressed: Bool) {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle else { return }
        let clampedX = max(0, min(255, x))
        let clampedY = max(0, min(191, y))
        let touch = xemu_nds_touch_state_t(x: Int32(clampedX), y: Int32(clampedY), is_pressed: pressed ? 1 : 0)
        xemu_nds_set_touch(handle, touch)
    }

    public func setScreenLayoutStacked() {
        _ = setScreenLayout(.stacked)
    }

    @discardableResult
    public func setScreenLayout(_ layout: NDSScreenLayout) -> Bool {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle else { return false }

        let nativeLayout: xemu_nds_screen_layout_t
        switch layout {
        case .stacked:
            nativeLayout = XEMU_NDS_SCREEN_LAYOUT_STACKED
        case .sideBySide:
            nativeLayout = XEMU_NDS_SCREEN_LAYOUT_SIDE_BY_SIDE
        case .topOnly:
            nativeLayout = XEMU_NDS_SCREEN_LAYOUT_TOP_ONLY
        case .bottomOnly:
            nativeLayout = XEMU_NDS_SCREEN_LAYOUT_BOTTOM_ONLY
        }

        return xemu_nds_set_screen_layout(handle, nativeLayout) == XEMU_OK
    }

    public func getScreenLayout() -> NDSScreenLayout {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle else { return .stacked }
        let layout = xemu_nds_get_screen_layout(handle)
        switch layout {
        case XEMU_NDS_SCREEN_LAYOUT_SIDE_BY_SIDE:
            return .sideBySide
        case XEMU_NDS_SCREEN_LAYOUT_TOP_ONLY:
            return .topOnly
        case XEMU_NDS_SCREEN_LAYOUT_BOTTOM_ONLY:
            return .bottomOnly
        default:
            return .stacked
        }
    }

    public func getSaveStateData() throws -> Data {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        guard useNative, let handle = handle, isROMLoaded else {
            throw XemuCoresError.saveStateFailed("No ROM loaded")
        }

        let stateSize = xemu_nds_get_save_state_size(handle)
        guard stateSize > 0 else {
            throw XemuCoresError.saveStateFailed("Invalid NDS save state size")
        }

        var buffer = Data(count: stateSize)
        var result: xemu_error_t = XEMU_ERROR_UNKNOWN
        buffer.withUnsafeMutableBytes { raw in
            guard let ptr = raw.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            var state = xemu_save_state_t(data: ptr, size: stateSize)
            result = xemu_nds_save_state(handle, &state)
        }

        guard result == XEMU_OK else {
            throw XemuCoresError.saveStateFailed("Failed to save NDS state")
        }

        return buffer
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
        let result = xemu_nds_load_state(handle, &state)
        guard result == XEMU_OK else {
            throw XemuCoresError.saveStateFailed("Failed to load NDS state")
        }
    }

    public func getBatteryData() throws -> Data { Data() }
    public func loadBatteryData(_ data: Data) throws { }

    public func shutdown() {
        nativeLock.lock()
        defer { nativeLock.unlock() }

        if useNative, let handle = handle {
            xemu_nds_set_input(handle, 0)
            let touch = xemu_nds_touch_state_t(x: 0, y: 0, is_pressed: 0)
            xemu_nds_set_touch(handle, touch)
            xemu_nds_destroy(handle)
        }
        inputStateMask = 0
        handle = nil
        isROMLoaded = false
    }
}
