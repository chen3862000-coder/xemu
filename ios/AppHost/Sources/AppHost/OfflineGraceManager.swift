import Foundation
import Network
import Combine
import Combine

public final class OfflineGraceManager: @unchecked Sendable {
    public let entitlementCache: EntitlementCache
    public var gracePeriodDays: Int
    public var gracePeriodWarningThresholdDays: Int
    @Published public var currentNetworkStatus: NWPath.Status = .satisfied
    public var lastOnlineTimestamp: Date?
    public private(set) var isMonitoring: Bool = false
    
    public let networkStatusChanged = PassthroughSubject<NWPath.Status, Never>()
    
    private let pathMonitor: NWPathMonitor
    private var monitorQueue: DispatchQueue
    
    public init(
        entitlementCache: EntitlementCache,
        gracePeriodDays: Int = 7,
        gracePeriodWarningThresholdDays: Int = 3
    ) {
        self.entitlementCache = entitlementCache
        self.gracePeriodDays = gracePeriodDays
        self.gracePeriodWarningThresholdDays = gracePeriodWarningThresholdDays
        self.pathMonitor = NWPathMonitor()
        self.monitorQueue = DispatchQueue(label: "com.apphost.offlinegrace")
        self.lastOnlineTimestamp = nil
    }
    
    public func canLaunchWithOfflineGrace() -> (Bool, daysRemaining: Int) {
        guard let lastOnline = lastOnlineTimestamp else { return (false, 0) }
        
        let daysElapsed = Calendar.current.dateComponents([.day], from: lastOnline, to: Date()).day ?? 0
        let daysRemaining = max(0, gracePeriodDays - daysElapsed)
        
        if daysRemaining > 0 {
            return (true, daysRemaining)
        }
        
        return (false, 0)
    }
    
    public func updateGracePeriod(_ endOfGrace: Date) {
        let daysUntilEnd = Calendar.current.dateComponents([.day], from: Date(), to: endOfGrace).day ?? 0
        gracePeriodDays = max(0, daysUntilEnd)
    }
    
    public func stopMonitoring() {
        pathMonitor.cancel()
        isMonitoring = false
    }
    
    public func startMonitoring() {
        isMonitoring = true
        pathMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let oldStatus = self.currentNetworkStatus
            self.currentNetworkStatus = path.status
            
            if oldStatus != self.currentNetworkStatus {
                self.networkStatusChanged.send(self.currentNetworkStatus)
            }
            
            if path.status == .satisfied {
                self.lastOnlineTimestamp = Date()
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }
    
    public func simulateNetworkChange(to status: NWPath.Status) {
        currentNetworkStatus = status
        networkStatusChanged.send(status)
        
        if status == .satisfied {
            lastOnlineTimestamp = Date()
        }
    }
    
    public func updateLastOnlineTimestamp() {
        lastOnlineTimestamp = Date()
    }
    
    public func showWarningIfNeeded() -> Bool {
        guard let lastOnline = lastOnlineTimestamp else { return false }
        
        let daysElapsed = Calendar.current.dateComponents([.day], from: lastOnline, to: Date()).day ?? 0
        return daysElapsed >= gracePeriodWarningThresholdDays
    }
    
    public func getDaysRemainingGracePeriod() -> Int {
        guard let lastOnline = lastOnlineTimestamp else { return 0 }
        
        let daysElapsed = Calendar.current.dateComponents([.day], from: lastOnline, to: Date()).day ?? 0
        return max(0, gracePeriodDays - daysElapsed)
    }
    
    public func scheduleExpiryNotification() {
        
    }
    
    public func hasExpiryNotificationScheduled() -> Bool {
        return false
    }
    
    public func clearGracePeriod() {
        lastOnlineTimestamp = nil
    }
    
    public func setGracePeriodEnd(_ endOfGrace: Date) {
        let deviceId = entitlementCache.getDeviceId() ?? UUID()
        let profile = DeviceProfile(deviceId: deviceId, hardwareClass: .Tier1, whitelistVersion: "1.0")
        entitlementCache.cacheDeviceProfile(profile)
    }
}
