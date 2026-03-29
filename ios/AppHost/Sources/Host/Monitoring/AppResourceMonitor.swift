import Foundation
import os.log
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Safe, crash-free resource monitoring for production apps
/// Monitors memory, disk, battery, and performance metrics without complex system calls
@MainActor
final class AppResourceMonitor: ObservableObject {
    static let shared = AppResourceMonitor()

    private static let logger = Logger(subsystem: "com.xemu", category: "ResourceMonitor")

    // MARK: - Published Properties

    @Published var memoryUsagePercent: Double = 0.0
    @Published var availableMemoryMB: Double = 0.0
    @Published var diskUsagePercent: Double = 0.0
    @Published var availableDiskMB: Double = 0.0
    @Published var batteryLevel: Float = 1.0
    @Published var isMemoryPressureHigh: Bool = false
    @Published var isDiskSpaceLow: Bool = false
    @Published var isBatteryLow: Bool = false
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var cpuUsagePercent: Double = 0.0

    // MARK: - Alert Thresholds

    private var memoryAlertThreshold: Double = 0.85 // 85%
    private var diskAlertThreshold: Double = 0.90 // 90%
    private var batteryAlertThreshold: Float = 0.20 // 20%

    // MARK: - Monitoring State

    private var monitoringTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var isMonitoringInitialized = false

    // MARK: - Alert Callbacks

    var onMemoryWarning: ((MemoryWarningLevel) -> Void)?
    var onDiskSpaceWarning: ((DiskWarningLevel) -> Void)?
    var onBatteryWarning: ((BatteryWarningLevel) -> Void)?
    var onThermalStateChange: ((ProcessInfo.ThermalState) -> Void)?

    // MARK: - Warning Levels

    enum MemoryWarningLevel {
        case moderate    // 75-85% memory usage
        case high        // 85-95% memory usage
        case critical     // >95% memory usage

        var description: String {
            switch self {
            case .moderate: return "moderate"
            case .high: return "high"
            case .critical: return "critical"
            }
        }
    }

    enum DiskWarningLevel {
        case low         // 80-90% disk usage
        case critical    // >90% disk usage

        var description: String {
            switch self {
            case .low: return "low"
            case .critical: return "critical"
            }
        }
    }

    enum BatteryWarningLevel {
        case low         // 15-25% battery
        case critical    // <15% battery

        var description: String {
            switch self {
            case .low: return "low"
            case .critical: return "critical"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        // Safe initialization - don't start monitoring immediately
        // Monitoring will be started by explicit call to startMonitoring()
        Self.logger.debug("AppResourceMonitor initialized (monitoring not started)")
    }

    // MARK: - Monitoring Setup

    private func setupMonitoring() {
        guard !isMonitoringInitialized else { return }
        isMonitoringInitialized = true

        // Use very safe initialization with try-catch for everything
        do {
            #if canImport(UIKit)
            // Memory warning notifications
            NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
                .sink { [weak self] _ in
                    self?.handleMemoryWarning()
                }
                .store(in: &cancellables)

            // App lifecycle monitoring
            NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
                .sink { [weak self] _ in
                    self?.handleDidEnterBackground()
                }
                .store(in: &cancellables)

            NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
                .sink { [weak self] _ in
                    self?.handleWillEnterForeground()
                }
                .store(in: &cancellables)
            #endif

            // Thermal state monitoring
            setupThermalStateMonitoring()

            // Start periodic resource monitoring
            startPeriodicMonitoring()

            Self.logger.debug("Monitoring started successfully")
        } catch {
            Self.logger.error("Failed to setup monitoring: \(error.localizedDescription)")
        }
    }

    private func setupThermalStateMonitoring() {
        // Use safe thermal state check without complex calls
        Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateThermalState()
            }
        }
    }

    private func startPeriodicMonitoring() {
        // Update resource metrics every 10 seconds (safe interval)
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateResourceMetrics()
            }
        }
    }

    // MARK: - Resource Updates

    private func updateResourceMetrics() {
        // Only update safe, non-complex metrics
        updateDiskMetrics()
        updateBatteryMetrics()
        checkResourceAlerts()
    }

    private func updateDiskMetrics() {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])

            if let totalBytes = values.volumeTotalCapacity,
               let availableBytes = values.volumeAvailableCapacityForImportantUsage {

                let totalMB = Double(totalBytes) / 1024.0 / 1024.0
                let availableMB = Double(availableBytes) / 1024.0 / 1024.0

                self.diskUsagePercent = ((totalMB - availableMB) / totalMB) * 100.0
                self.availableDiskMB = availableMB

                self.isDiskSpaceLow = self.diskUsagePercent > self.diskAlertThreshold * 100.0

                Self.logger.debug("Disk: \(String(format: "%.1f", availableMB))MB available (\(String(format: "%.1f", self.diskUsagePercent))%)")
            }
        } catch {
            Self.logger.error("Failed to get disk metrics: \(error.localizedDescription)")
        }
    }

    private func updateBatteryMetrics() {
        #if canImport(UIKit)
        let device = UIDevice.current

        // Safe battery access
        self.batteryLevel = device.batteryLevel

        if self.batteryLevel < 0 { // Not available
            self.isBatteryLow = false
        } else {
            self.isBatteryLow = self.batteryLevel < self.batteryAlertThreshold
        }

        Self.logger.debug("Battery: \(Int(self.batteryLevel * 100))%")
        #else
        // For non-iOS platforms, provide default values
        self.batteryLevel = 1.0
        self.isBatteryLow = false
        #endif
    }

    private func updateThermalState() {
        let newThermalState = ProcessInfo.processInfo.thermalState

        if newThermalState != self.thermalState {
            self.thermalState = newThermalState
            self.onThermalStateChange?(newThermalState)

            let stateName: String
            switch newThermalState {
            case .nominal: stateName = "nominal"
            case .fair: stateName = "fair"
            case .serious: stateName = "serious"
            case .critical: stateName = "critical"
            @unknown default: stateName = "unknown"
            }

            Self.logger.info("Thermal state changed: \(stateName)")
        }
    }

    // MARK: - Alert Handling

    private func checkResourceAlerts() {
        checkDiskAlerts()
        checkBatteryAlerts()
    }

    private func checkDiskAlerts() {
        guard self.isDiskSpaceLow else { return }

        let level: DiskWarningLevel
        if self.diskUsagePercent > 90.0 {
            level = .critical
        } else {
            level = .low
        }

        self.onDiskSpaceWarning?(level)
        Self.logger.warning("Disk space warning: \(level.description) - \(String(format: "%.1f", self.diskUsagePercent))%")
    }

    private func checkBatteryAlerts() {
        guard self.isBatteryLow else { return }

        let level: BatteryWarningLevel
        if self.batteryLevel < 0.15 {
            level = .critical
        } else {
            level = .low
        }

        self.onBatteryWarning?(level)
        Self.logger.warning("Battery warning: \(level.description) - \(Int(self.batteryLevel * 100))%")
    }

    // MARK: - Memory Warning Handling

    private func handleMemoryWarning() {
        Self.logger.warning("Memory warning received")

        // Simplified memory handling without complex system calls
        let level: MemoryWarningLevel = .moderate
        self.onMemoryWarning?(level)

        // Update basic memory metrics
        self.isMemoryPressureHigh = true
        self.memoryUsagePercent = 90.0 // Estimate when under pressure
    }

    // MARK: - App Lifecycle Handling

    private func handleDidEnterBackground() {
        Self.logger.info("App entered background - reducing monitoring frequency")

        // Reduce monitoring frequency when in background
        self.monitoringTimer?.invalidate()
        self.monitoringTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateResourceMetrics()
            }
        }
    }

    private func handleWillEnterForeground() {
        Self.logger.info("App will enter foreground - restoring monitoring frequency")

        // Restore normal monitoring frequency
        self.monitoringTimer?.invalidate()
        startPeriodicMonitoring()

        // Immediate update
        updateResourceMetrics()
    }

    // MARK: - Public API

    /// Force immediate resource check
    func checkResourcesNow() {
        updateResourceMetrics()
    }

    /// Get comprehensive resource status
    func getResourceStatus() -> ResourceStatus {
        ResourceStatus(
            memoryUsagePercent: memoryUsagePercent,
            diskUsagePercent: diskUsagePercent,
            batteryLevel: batteryLevel,
            thermalState: thermalState,
            isMemoryPressureHigh: isMemoryPressureHigh,
            isDiskSpaceLow: isDiskSpaceLow,
            isBatteryLow: isBatteryLow,
            overallStatus: calculateOverallStatus()
        )
    }

    private func calculateOverallStatus() -> OverallStatus {
        if isMemoryPressureHigh && isDiskSpaceLow && isBatteryLow {
            return .critical
        } else if isMemoryPressureHigh || thermalState == .critical {
            return .poor
        } else if isDiskSpaceLow || isBatteryLow || thermalState == .serious {
            return .moderate
        } else {
            return .good
        }
    }

    /// Start monitoring
    func startMonitoring() {
        if monitoringTimer == nil {
            setupMonitoring()
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        cancellables.removeAll()
        isMonitoringInitialized = false
    }

    /// Configure alert thresholds
    func configureThresholds(
        memoryAlert: Double = 0.85,
        diskAlert: Double = 0.90,
        batteryAlert: Float = 0.20
    ) {
        self.memoryAlertThreshold = memoryAlert
        self.diskAlertThreshold = diskAlert
        self.batteryAlertThreshold = batteryAlert
    }

    // MARK: - Data Models

    struct ResourceStatus {
        let memoryUsagePercent: Double
        let diskUsagePercent: Double
        let batteryLevel: Float
        let thermalState: ProcessInfo.ThermalState
        let isMemoryPressureHigh: Bool
        let isDiskSpaceLow: Bool
        let isBatteryLow: Bool
        let overallStatus: OverallStatus
    }

    enum OverallStatus {
        case good       // All resources in good condition
        case moderate   // Some resources under pressure but acceptable
        case poor       // Significant resource pressure
        case critical   // Critical resource shortage
    }
}