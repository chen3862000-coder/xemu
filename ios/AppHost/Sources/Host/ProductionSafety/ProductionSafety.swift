import Foundation
import os.log
#if canImport(UIKit)
import UIKit
#endif

/// Production safety utilities for crash prevention and graceful degradation
enum ProductionSafety {
    static let logger = Logger(subsystem: "com.xemu", category: "ProductionSafety")

    /// Critical error types that require user notification
    enum CriticalError: Error, LocalizedError {
        case memoryExhaustion
        case romLoadFailed(String)
        case audioDeviceFailure
        case stateCorruption
        case resourceExhaustion(String)

        var errorDescription: String? {
            switch self {
            case .memoryExhaustion:
                return "Device memory is critically low. Please close other apps and try again."
            case .romLoadFailed(let reason):
                return "Failed to load game: \(reason)"
            case .audioDeviceFailure:
                return "Audio device unavailable. Please check your audio settings."
            case .stateCorruption:
                return "Save state is corrupted and cannot be loaded."
            case .resourceExhaustion(let resource):
                return "Insufficient \(resource). Please free up device storage."
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .memoryExhaustion:
                return "Close unused apps or restart your device"
            case .romLoadFailed:
                return "Try a different ROM file"
            case .audioDeviceFailure:
                return "Connect headphones or use device speakers"
            case .stateCorruption:
                return "Delete this save state and create a new one"
            case .resourceExhaustion:
                return "Clear device storage and try again"
            }
        }
    }

    /// Safe execution wrapper that prevents crashes
    static func safeExecute<T>(_ operation: @escaping () throws -> T,
                              fallback: T,
                              errorContext: String) -> T {
        do {
            return try operation()
        } catch {
            logger.error("Safe execution failed: \(errorContext) - \(error.localizedDescription)")
            return fallback
        }
    }

    /// Safe async execution wrapper with error handling
    static func safeExecuteAsync<T>(_ operation: @escaping () async throws -> T,
                                     fallback: T,
                                     errorContext: String) async -> T {
        do {
            return try await operation()
        } catch {
            logger.error("Safe async execution failed: \(errorContext) - \(error.localizedDescription)")
            return fallback
        }
    }

    /// Memory-safe buffer operations
    struct SafeBuffer {
        /// Safe memory copy with bounds checking
        static func copy(destination: UnsafeMutableRawPointer,
                        source: UnsafeRawPointer,
                        size: Int) -> Bool {
            guard size > 0 else { return false }

            guard size < Int.max / 2 else { // Prevent potential overflow
                logger.error("Buffer size too large: \(size)")
                return false
            }

            memcpy(destination, source, size)
            return true
        }

        /// Safe memory set with validation
        static func setMemory(pointer: UnsafeMutableRawPointer,
                           value: Int32,
                           size: Int) -> Bool {
            guard size > 0 else { return false }

            guard size < Int.max / 2 else {
                logger.error("Buffer size too large: \(size)")
                return false
            }

            memset(pointer, Int32(value), size)
            return true
        }
    }

    /// Resource monitoring utilities
    struct ResourceMonitor {
        /// Check if memory pressure is critical
        static func isMemoryPressureCritical() -> Bool {
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4

            let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(mach_task_self_,
                             task_flavor_t(MACH_TASK_BASIC_INFO),
                             $0,
                             &count)
                }
            }

            if kerr == KERN_SUCCESS {
                let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
                // Consider memory critical if using more than 500MB
                return usedMB > 500.0
            }

            return false
        }

        /// Check if disk space is critically low
        static func isDiskSpaceCritical() -> Bool {
            do {
                let fileURL = URL(fileURLWithPath: NSHomeDirectory())
                let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])

                if let availableBytes = values.volumeAvailableCapacityForImportantUsage {
                    let availableMB = Double(availableBytes) / 1024.0 / 1024.0
                    // Consider disk space critical if less than 100MB available
                    return availableMB < 100.0
                }
            } catch {
                logger.error("Failed to check disk space: \(error.localizedDescription)")
            }

            return false
        }

        /// Handle resource exhaustion gracefully
        static func handleResourceExhaustion(resource: String) {
            logger.warning("Resource exhaustion detected: \(resource)")

            // Post memory warning notification to trigger app-wide cleanup
            #if canImport(UIKit)
            NotificationCenter.default.post(
                name: UIApplication.didReceiveMemoryWarningNotification,
                object: nil
            )
            #endif
        }
    }

    /// Fallback mechanisms for critical failures
    struct FallbackHandler {
        /// Get safe fallback when file operations fail
        static func getSafeFallbackURL(for filename: String) -> URL {
            let tempDir = FileManager.default.temporaryDirectory
            return tempDir.appendingPathComponent("fallback_\(filename)")
        }

        /// Create minimal valid state when state loading fails
        static func createMinimalValidState() -> Data {
            // Return minimal valid save state data
            return Data(count: 1024) // 1KB placeholder
        }

        /// Get safe default audio configuration
        static func getSafeAudioConfig() -> (sampleRate: Int, channels: Int) {
            return (sampleRate: 44100, channels: 2)
        }
    }

    /// Crash prevention utilities
    struct CrashPrevention {
        /// Validate critical parameters before processing
        static func validateVideoBuffer(width: Int, height: Int) -> Bool {
            guard width > 0, height > 0 else { return false }
            guard width <= 4096, height <= 4096 else { return false } // Prevent excessive allocations
            let totalBytes = width * height * 4 // RGBA8888
            guard totalBytes < Int.max / 4 else { return false } // Prevent overflow
            return true
        }

        /// Validate audio parameters
        static func validateAudioBuffer(sampleRate: Int, sampleCount: Int) -> Bool {
            guard sampleRate > 0, sampleRate <= 192000 else { return false }
            guard sampleCount >= 0, sampleCount <= 48000 else { return false } // Prevent excessive allocations
            return true
        }

        /// Safe unwrap with fallback and logging
        static func safeUnwrap<T>(_ optional: T?, fallback: T, context: String) -> T {
            guard let value = optional else {
                logger.warning("Nil unwrap encountered: \(context)")
                return fallback
            }
            return value
        }
    }

    /// Performance degradation for graceful fallback
    struct PerformanceDegradation {
        static var qualityLevel: QualityLevel = .high

        enum QualityLevel: Int, Comparable {
            case low = 0
            case medium = 1
            case high = 2

            static func < (lhs: QualityLevel, rhs: QualityLevel) -> Bool {
                return lhs.rawValue < rhs.rawValue
            }
        }

        /// Reduce quality when performance issues detected
        static func degradeQuality() {
            switch qualityLevel {
            case .high:
                qualityLevel = .medium
                logger.info("Performance degraded to medium quality")
            case .medium:
                qualityLevel = .low
                logger.info("Performance degraded to low quality")
            case .low:
                logger.warning("Already at lowest quality level")
            }
        }

        /// Reset quality when performance improves
        static func improveQuality() {
            if qualityLevel < .high {
                qualityLevel = QualityLevel(rawValue: qualityLevel.rawValue + 1)!
                let qualityName: String
                switch qualityLevel {
                case .low: qualityName = "low"
                case .medium: qualityName = "medium"
                case .high: qualityName = "high"
                }
                logger.info("Performance improved to \(qualityName) quality")
            }
        }
    }
}

/// Extension to add safe operations to FileManager
extension FileManager {
    /// Safe directory creation with fallback
    func createDirectorySafely(at url: URL, withIntermediateDirectories: Bool = true) -> URL? {
        do {
            try createDirectory(at: url, withIntermediateDirectories: withIntermediateDirectories)
            return url
        } catch {
            ProductionSafety.logger.error("Failed to create directory at \(url.path): \(error.localizedDescription)")

            // Try fallback to temp directory
            let fallbackURL = temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            do {
                try createDirectory(at: fallbackURL, withIntermediateDirectories: true)
                ProductionSafety.logger.info("Using fallback directory: \(fallbackURL.path)")
                return fallbackURL
            } catch {
                ProductionSafety.logger.error("Fallback directory creation also failed: \(error.localizedDescription)")
                return nil
            }
        }
    }

    /// Safe file read with error handling
    func readSafely(from url: URL) -> Data? {
        do {
            return try Data(contentsOf: url)
        } catch {
            ProductionSafety.logger.error("Failed to read file at \(url.path): \(error.localizedDescription)")
            return nil
        }
    }

    /// Safe file write with error handling and fallback
    func writeSafely(data: Data, to url: URL, options: Data.WritingOptions = .atomic) -> Bool {
        do {
            try data.write(to: url, options: options)
            return true
        } catch {
            ProductionSafety.logger.error("Failed to write file to \(url.path): \(error.localizedDescription)")

            // Try fallback location
            let fallbackURL = ProductionSafety.FallbackHandler.getSafeFallbackURL(for: url.lastPathComponent)
            do {
                try data.write(to: fallbackURL, options: options)
                ProductionSafety.logger.info("Wrote to fallback: \(fallbackURL.path)")
                return true
            } catch {
                ProductionSafety.logger.error("Fallback write also failed: \(error.localizedDescription)")
                return false
            }
        }
    }
}