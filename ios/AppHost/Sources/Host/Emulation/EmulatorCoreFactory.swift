import Foundation

/// Factory class for creating emulator cores based on platform type
/// This provides centralized core instantiation with proper error handling
public final class EmulatorCoreFactory {
    
    /// Create an emulator core for the specified platform
    /// - Parameter platform: The platform to create a core for
    /// - Returns: An initialized EmulatorCore instance
    /// - Throws: EmulatorCoreError if the platform is not supported or core initialization fails
    public static func createCore(for platform: Platform) throws -> EmulatorCore {
        let core: EmulatorCore
        
        switch platform {
        case .GB, .GBC:
            core = GBCore()
        case .GBA:
            core = GBACore()
        case .NDS:
            core = NDSCore()
        case .NES, .GENESIS, .PS1, .PS2, ._3DS:
            throw EmulatorCoreError.unsupportedPlatform(platform)
        }
        
        if !core.initialize() {
            throw EmulatorCoreError.initializationFailed(platform)
        }
        
        return core
    }
    
    /// Check if a platform is supported
    /// - Parameter platform: The platform to check
    /// - Returns: true if the platform is supported, false otherwise
    public static func isPlatformSupported(_ platform: Platform) -> Bool {
        switch platform {
        case .GB, .GBC, .GBA, .NDS:
            return true
        case .NES, .GENESIS, .PS1, .PS2, ._3DS:
            return false
        }
    }
    
    /// Get a list of all supported platforms
    /// - Returns: Array of supported Platform values
    public static func supportedPlatforms() -> [Platform] {
        return [.GB, .GBC, .GBA, .NDS]
    }
    
    /// Get a list of all unsupported platforms
    /// - Returns: Array of unsupported Platform values
    public static func unsupportedPlatforms() -> [Platform] {
        return [.NES, .GENESIS, .PS1, .PS2, ._3DS]
    }
}

/// Errors that can occur when creating or initializing emulator cores
public enum EmulatorCoreError: LocalizedError {
    case unsupportedPlatform(Platform)
    case initializationFailed(Platform)
    case coreNotFound(Platform)
    
    public var errorDescription: String? {
        switch self {
        case .unsupportedPlatform(let platform):
            return "Platform \(platform.rawValue) is not supported"
        case .initializationFailed(let platform):
            return "Failed to initialize core for platform \(platform.rawValue)"
        case .coreNotFound(let platform):
            return "Emulator core not found for platform \(platform.rawValue)"
        }
    }
}
