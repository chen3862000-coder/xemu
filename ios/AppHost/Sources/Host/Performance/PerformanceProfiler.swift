import Foundation
import Combine
import QuartzCore
import Darwin.Mach
#if canImport(UIKit)
import UIKit
#endif

enum PerformanceMode: String, CaseIterable {
    case auto
    case quality
    case battery

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .quality: return "Quality"
        case .battery: return "Battery"
        }
    }
}

struct PerfQualityProfile: Codable, Equatable {
    var renderScale: Double
    var frameSkip: Int
    var shadersEnabled: Bool
    var prefetchCovers: Bool
    var heavyUIEffects: Bool

    static let nominal = PerfQualityProfile(
        renderScale: 1.0,
        frameSkip: 0,
        shadersEnabled: true,
        prefetchCovers: true,
        heavyUIEffects: true
    )

    static let fair = PerfQualityProfile(
        renderScale: 0.95,
        frameSkip: 0,
        shadersEnabled: false,
        prefetchCovers: true,
        heavyUIEffects: false
    )

    static let serious = PerfQualityProfile(
        renderScale: 0.85,
        frameSkip: 1,
        shadersEnabled: false,
        prefetchCovers: false,
        heavyUIEffects: false
    )

    static let critical = PerfQualityProfile(
        renderScale: 0.75,
        frameSkip: 2,
        shadersEnabled: false,
        prefetchCovers: false,
        heavyUIEffects: false
    )
}

struct PerfHUDSnapshot: Equatable {
    var fps: Double
    var avgFrameMs: Double
    var p95FrameMs: Double
    var jankPerMinute: Int
    var memoryMB: Double
    var peakMemoryMB: Double
    var memoryWarnings: Int
    var thermalState: ProcessInfo.ThermalState
    var lowPowerModeEnabled: Bool
    var qualityProfile: PerfQualityProfile
}

private struct PerfSample: Codable {
    let timestamp: Date
    let fps: Double
    let avgFrameMs: Double
    let p95FrameMs: Double
    let jankCount: Int
    let severeJankCount: Int
    let stutterEvents: Int
    let memoryMB: Double
    let peakMemoryMB: Double
    let memoryWarnings: Int
    let thermalState: String
    let lowPowerModeEnabled: Bool
    let qualityProfile: PerfQualityProfile
}

private struct PerfOperationEvent: Codable {
    let name: String
    let startedAt: Date
    let finishedAt: Date
    let durationMs: Double
    let memoryBeforeMB: Double
    let memoryAfterMB: Double
    let metadata: [String: String]
}

private struct PendingOperation {
    let id: UUID
    let name: String
    let startedAt: Date
    let startedAtUptime: TimeInterval
    let memoryBeforeMB: Double
    let metadata: [String: String]
}

private struct PerfLogPayload: Codable {
    let exportedAt: Date
    let appVersion: String
    let buildNumber: String
    let platform: String
    let deviceModel: String
    let osVersion: String
    let refreshRate: Int
    let samples: [PerfSample]
    let events: [PerfOperationEvent]
}

@MainActor
final class PerformanceProfiler: ObservableObject {
    static let shared = PerformanceProfiler()

    @Published private(set) var hudSnapshot = PerfHUDSnapshot(
        fps: 0,
        avgFrameMs: 0,
        p95FrameMs: 0,
        jankPerMinute: 0,
        memoryMB: 0,
        peakMemoryMB: 0,
        memoryWarnings: 0,
        thermalState: .nominal,
        lowPowerModeEnabled: false,
        qualityProfile: .nominal
    )

    private let sampleCapacity = 600
    private let eventCapacity = 200
    private let frameWindowCapacity = 240
    private let settings = UserDefaults.standard

    private var sessionPlatform: Platform?
    private var sampleTimer: Timer?
    private var frameDeltas: [Double] = []
    private var samples: [PerfSample] = []
    private var operationEvents: [PerfOperationEvent] = []
    private var pendingOperations: [UUID: PendingOperation] = [:]
    private var observers: [NSObjectProtocol] = []
    private var thermalState: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    private var lowPowerModeEnabled: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    private var peakMemoryMB: Double = 0
    private var memoryWarningCount: Int = 0

    private var lastFrameTimestamp: TimeInterval?
    private var lastAggregateTimestamp: TimeInterval = CACurrentMediaTime()
    private var framesSinceAggregate = 0
    private var jankSinceAggregate = 0
    private var severeJankSinceAggregate = 0
    private var stutterEventsSinceAggregate = 0
    private var consecutiveSevereFrames = 0
    private var lastFps: Double = 0
    private var lastAvgMs: Double = 0
    private var lastP95Ms: Double = 0
    private var isRunning = false

    private init() {}

    var currentQualityProfile: PerfQualityProfile {
        resolvedQualityProfile()
    }

    func startSession(platform: Platform) {
        sessionPlatform = platform
        if isRunning {
            return
        }
        isRunning = true
        resetTransientState()
        registerObserversIfNeeded()
        startSamplingTimer()
    }

    func stopSession() {
        isRunning = false
        sampleTimer?.invalidate()
        sampleTimer = nil
        unregisterObservers()
        pendingOperations.removeAll()
        sessionPlatform = nil
        lastFrameTimestamp = nil
    }

    func recordFrame(at timestamp: TimeInterval = CACurrentMediaTime()) {
        guard isRunning else { return }
        defer {
            lastFrameTimestamp = timestamp
        }
        guard let previous = lastFrameTimestamp else { return }
        let delta = timestamp - previous
        guard delta.isFinite, delta > 0, delta < 0.5 else { return }

        frameDeltas.append(delta)
        if frameDeltas.count > frameWindowCapacity {
            frameDeltas.removeFirst(frameDeltas.count - frameWindowCapacity)
        }

        framesSinceAggregate += 1

        let refresh = max(1, displayRefreshRate())
        let expected = 1.0 / Double(refresh)
        let jankThreshold = expected * 1.3
        let severeThreshold = expected * 2.0

        if delta > jankThreshold {
            jankSinceAggregate += 1
        }
        if delta > severeThreshold {
            severeJankSinceAggregate += 1
            consecutiveSevereFrames += 1
            if consecutiveSevereFrames == 3 {
                stutterEventsSinceAggregate += 1
            }
        } else {
            consecutiveSevereFrames = 0
        }
    }

    func beginOperation(_ name: String, metadata: [String: String] = [:]) -> UUID {
        let id = UUID()
        pendingOperations[id] = PendingOperation(
            id: id,
            name: name,
            startedAt: Date(),
            startedAtUptime: CACurrentMediaTime(),
            memoryBeforeMB: currentMemoryMB(),
            metadata: metadata
        )
        return id
    }

    func endOperation(_ id: UUID, metadata: [String: String] = [:]) {
        guard let operation = pendingOperations.removeValue(forKey: id) else { return }
        let finishedAt = Date()
        let durationMs = max(0, (CACurrentMediaTime() - operation.startedAtUptime) * 1_000)
        let memoryAfter = currentMemoryMB()
        var combined = operation.metadata
        for (key, value) in metadata {
            combined[key] = value
        }
        operationEvents.append(
            PerfOperationEvent(
                name: operation.name,
                startedAt: operation.startedAt,
                finishedAt: finishedAt,
                durationMs: durationMs,
                memoryBeforeMB: operation.memoryBeforeMB,
                memoryAfterMB: memoryAfter,
                metadata: combined
            )
        )
        trim(&operationEvents, capacity: eventCapacity)
    }

    func exportRecentLog() throws -> URL {
        let payload = PerfLogPayload(
            exportedAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
            platform: sessionPlatform?.rawValue ?? "none",
            deviceModel: deviceModel(),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            refreshRate: displayRefreshRate(),
            samples: samples,
            events: operationEvents
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("retromind-perf-\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private func startSamplingTimer() {
        sampleTimer?.invalidate()
        sampleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.captureSampleTick()
            }
        }
        if let timer = sampleTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func captureSampleTick() {
        let now = CACurrentMediaTime()
        let elapsed = max(0.001, now - lastAggregateTimestamp)
        lastAggregateTimestamp = now

        let fps = Double(framesSinceAggregate) / elapsed
        framesSinceAggregate = 0

        let frameMs = frameDeltas.map { $0 * 1_000 }
        let avgMs = frameMs.isEmpty ? 0 : frameMs.reduce(0, +) / Double(frameMs.count)
        let p95Ms: Double = {
            guard !frameMs.isEmpty else { return 0 }
            let sorted = frameMs.sorted()
            let index = Int(Double(sorted.count - 1) * 0.95)
            return sorted[max(0, min(index, sorted.count - 1))]
        }()

        let memoryMB = currentMemoryMB()
        peakMemoryMB = max(peakMemoryMB, memoryMB)
        thermalState = ProcessInfo.processInfo.thermalState
        lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled

        let quality = resolvedQualityProfile()
        let jankPerMinute = Int(round(Double(jankSinceAggregate) * 60.0 / elapsed))

        hudSnapshot = PerfHUDSnapshot(
            fps: fps,
            avgFrameMs: avgMs,
            p95FrameMs: p95Ms,
            jankPerMinute: jankPerMinute,
            memoryMB: memoryMB,
            peakMemoryMB: peakMemoryMB,
            memoryWarnings: memoryWarningCount,
            thermalState: thermalState,
            lowPowerModeEnabled: lowPowerModeEnabled,
            qualityProfile: quality
        )

        samples.append(
            PerfSample(
                timestamp: Date(),
                fps: fps,
                avgFrameMs: avgMs,
                p95FrameMs: p95Ms,
                jankCount: jankSinceAggregate,
                severeJankCount: severeJankSinceAggregate,
                stutterEvents: stutterEventsSinceAggregate,
                memoryMB: memoryMB,
                peakMemoryMB: peakMemoryMB,
                memoryWarnings: memoryWarningCount,
                thermalState: thermalStateLabel(thermalState),
                lowPowerModeEnabled: lowPowerModeEnabled,
                qualityProfile: quality
            )
        )
        trim(&samples, capacity: sampleCapacity)

        lastFps = fps
        lastAvgMs = avgMs
        lastP95Ms = p95Ms
        jankSinceAggregate = 0
        severeJankSinceAggregate = 0
        stutterEventsSinceAggregate = 0
    }

    private func registerObserversIfNeeded() {
        guard observers.isEmpty else { return }
        let center = NotificationCenter.default

        observers.append(
            center.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.thermalState = ProcessInfo.processInfo.thermalState
                }
            }
        )

        observers.append(
            center.addObserver(
                forName: Notification.Name.NSProcessInfoPowerStateDidChange,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
                }
            }
        )

        #if canImport(UIKit)
        observers.append(
            center.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.memoryWarningCount += 1
                    self.peakMemoryMB = max(self.peakMemoryMB, self.currentMemoryMB())
                }
            }
        )
        #endif
    }

    private func unregisterObservers() {
        guard !observers.isEmpty else { return }
        let center = NotificationCenter.default
        for observer in observers {
            center.removeObserver(observer)
        }
        observers.removeAll()
    }

    private func resetTransientState() {
        frameDeltas.removeAll(keepingCapacity: true)
        samples.removeAll(keepingCapacity: true)
        operationEvents.removeAll(keepingCapacity: true)
        memoryWarningCount = 0
        peakMemoryMB = currentMemoryMB()
        lastFrameTimestamp = nil
        lastAggregateTimestamp = CACurrentMediaTime()
        framesSinceAggregate = 0
        jankSinceAggregate = 0
        severeJankSinceAggregate = 0
        stutterEventsSinceAggregate = 0
        consecutiveSevereFrames = 0
        thermalState = ProcessInfo.processInfo.thermalState
        lowPowerModeEnabled = ProcessInfo.processInfo.isLowPowerModeEnabled
        hudSnapshot = PerfHUDSnapshot(
            fps: lastFps,
            avgFrameMs: lastAvgMs,
            p95FrameMs: lastP95Ms,
            jankPerMinute: 0,
            memoryMB: peakMemoryMB,
            peakMemoryMB: peakMemoryMB,
            memoryWarnings: 0,
            thermalState: thermalState,
            lowPowerModeEnabled: lowPowerModeEnabled,
            qualityProfile: resolvedQualityProfile()
        )
    }

    private func resolvedQualityProfile() -> PerfQualityProfile {
        let modeRaw = settings.string(forKey: "performanceMode") ?? PerformanceMode.auto.rawValue
        let mode = PerformanceMode(rawValue: modeRaw) ?? .auto
        let respectsLowPower = settings.object(forKey: "respectLowPowerMode") as? Bool ?? true

        if mode == .quality {
            return .nominal
        }
        if mode == .battery {
            return .serious
        }

        if respectsLowPower && lowPowerModeEnabled {
            switch thermalState {
            case .nominal: return .fair
            case .fair: return .serious
            case .serious, .critical: return .critical
            @unknown default: return .serious
            }
        }

        switch thermalState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .serious
        }
    }

    private func currentMemoryMB() -> Double {
        Double(currentMemoryBytes()) / (1024.0 * 1024.0)
    }

    private func currentMemoryBytes() -> UInt64 {
        let pageSize = UInt64(vm_kernel_page_size)

        var vmInfo = task_vm_info_data_t()
        var vmInfoCount = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let vmResult: kern_return_t = withUnsafeMutablePointer(to: &vmInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(vmInfoCount)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &vmInfoCount)
            }
        }
        if vmResult == KERN_SUCCESS {
            return vmInfo.phys_footprint
        }

        var basicInfo = mach_task_basic_info()
        var basicCount = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let basicResult: kern_return_t = withUnsafeMutablePointer(to: &basicInfo) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(basicCount)) { rebound in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), rebound, &basicCount)
            }
        }
        if basicResult == KERN_SUCCESS {
            return UInt64(basicInfo.resident_size)
        }

        return pageSize
    }

    private func displayRefreshRate() -> Int {
        #if canImport(UIKit)
        return max(60, UIScreen.main.maximumFramesPerSecond)
        #else
        return 60
        #endif
    }

    private func thermalStateLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private func deviceModel() -> String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        return mirror.children.reduce(into: "") { value, element in
            guard let c = element.value as? Int8, c != 0 else { return }
            value.append(Character(UnicodeScalar(UInt8(c))))
        }
        #endif
    }

    private func trim<T>(_ array: inout [T], capacity: Int) {
        guard array.count > capacity else { return }
        array.removeFirst(array.count - capacity)
    }
}
