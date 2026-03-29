import Foundation
import Network
import SwiftUI
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class OfflineGraceManager: ObservableObject {
    static let shared = OfflineGraceManager()
    
    @Published var isOffline = false
    @Published var gracePeriodEnd: Date?
    @Published var daysRemaining: Int = 0
    @Published var shouldShowWarning = false
    @Published var warningMessage: String?

    private let networkMonitor = NWPathMonitor()
    private var isTesting = false
    private let queue = DispatchQueue(label: "com.xemu.network")
    private let entitlementCache: EntitlementCache
    private let deviceProfileCache: DeviceProfileCache
    private lazy var notificationCenter: UNUserNotificationCenter = {
        UNUserNotificationCenter.current()
    }()

    init(entitlementCache: EntitlementCache = .shared, deviceProfileCache: DeviceProfileCache = .shared) {
        #if DEBUG
        self.isTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        #endif
        self.entitlementCache = entitlementCache
        self.deviceProfileCache = deviceProfileCache
        if !isTesting {
            setupNetworkMonitoring()
        }
        loadGracePeriod()
    }

    func startMonitoring() {
        networkMonitor.start(queue: queue)
    }

    func stopMonitoring() {
        networkMonitor.cancel()
    }

    func canLaunchGame() -> Bool {
        guard let graceEnd = gracePeriodEnd else {
            return false
        }

        return Date() < graceEnd
    }

    func canLaunchWithOfflineGrace() -> (Bool, Int) {
        guard let graceEnd = gracePeriodEnd else {
            return (false, 0)
        }

        let remaining = graceEnd.timeIntervalSinceNow
        let days = Int(remaining / (24 * 60 * 60))

        return (remaining > 0, days)
    }

    func recordOfflineGameplay() {
        let now = Date()

        if let cachedProfile = deviceProfileCache.loadProfile() {
            var updatedProfile = cachedProfile
            updatedProfile.offlineGraceEnd = (cachedProfile.offlineGraceEnd ?? now).addingTimeInterval(-24 * 60 * 60)
            deviceProfileCache.cache(updatedProfile)
        }

        loadGracePeriod()
        checkGracePeriodStatus()
    }

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            Task { @MainActor in
                let wasOffline = self.isOffline
                self.isOffline = path.status != .satisfied

                if self.isOffline && !wasOffline {
                    self.handleOfflineTransition()
                } else if !self.isOffline && wasOffline {
                    self.handleOnlineTransition()
                }
            }
        }
    }

    private func handleOfflineTransition() {
        loadGracePeriod()
        checkGracePeriodStatus()

        if canLaunchGame() {
            showNotification(title: "Offline Mode", body: "You can play offline for \(daysRemaining) more days")
        }
    }

    private func handleOnlineTransition() {
        Task {
            do {
                _ = try await AzureApiStub.shared.fetchEntitlements()
                loadGracePeriod()

                await MainActor.run {
                    self.shouldShowWarning = false
                    self.warningMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.warningMessage = "Failed to sync with server while online"
                }
            }
        }
    }

    private func loadGracePeriod() {
        if let profile = deviceProfileCache.loadProfile() {
            gracePeriodEnd = profile.offlineGraceEnd
            updateDaysRemaining()
        }
    }

    private func updateDaysRemaining() {
        guard let graceEnd = gracePeriodEnd else {
            daysRemaining = 0
            return
        }

        let remaining = graceEnd.timeIntervalSinceNow
        daysRemaining = max(0, Int(remaining / (24 * 60 * 60)))
    }

    private func checkGracePeriodStatus() {
        updateDaysRemaining()

        if daysRemaining <= 0 {
            shouldShowWarning = true
            warningMessage = "Your offline grace period has expired. Please connect to the internet to continue playing."
        } else if daysRemaining <= 2 {
            shouldShowWarning = true
            warningMessage = "Your offline grace period expires in \(daysRemaining) day(s). Connect to the internet to refresh."
        } else {
            shouldShowWarning = false
            warningMessage = nil
        }
    }

    private func showNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error)")
            }
        }
    }

    func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    func extendGracePeriod(by days: Int) {
        let now = Date()
        let newEnd = now.addingTimeInterval(Double(days) * 24 * 60 * 60)

        if let cachedProfile = deviceProfileCache.loadProfile() {
            var updatedProfile = cachedProfile
            updatedProfile.offlineGraceEnd = newEnd
            deviceProfileCache.cache(updatedProfile)
        }

        loadGracePeriod()
        checkGracePeriodStatus()
    }

    func resetGracePeriod() {
        if let cachedProfile = deviceProfileCache.loadProfile() {
            var updatedProfile = cachedProfile
            updatedProfile.offlineGraceEnd = nil
            deviceProfileCache.cache(updatedProfile)
        }

        gracePeriodEnd = nil
        daysRemaining = 0
        shouldShowWarning = true
        warningMessage = "Grace period reset. Please connect to the internet."
    }
}

@MainActor
final class OfflineGraceAlertViewModel: ObservableObject {
    @Published var isPresented = false
    @Published var title = ""
    @Published var message = ""
    @Published var primaryButtonTitle = "OK"
    @Published var primaryButtonAction: () -> Void = {}
    @Published var secondaryButtonTitle: String?
    @Published var secondaryButtonAction: (() -> Void)?

    private let offlineGraceManager: OfflineGraceManager

    init(offlineGraceManager: OfflineGraceManager) {
        self.offlineGraceManager = offlineGraceManager
    }

    func checkAndShowAlertIfNeeded() {
        guard offlineGraceManager.shouldShowWarning else { return }

        title = "Offline Grace Period Warning"
        message = offlineGraceManager.warningMessage ?? "Please check your offline status."

        if !offlineGraceManager.canLaunchGame() {
            primaryButtonTitle = "Go Online"
            primaryButtonAction = {
                self.isPresented = false
            }
            secondaryButtonTitle = nil
            secondaryButtonAction = nil
        } else {
            primaryButtonTitle = "Continue Offline"
            primaryButtonAction = {
                self.isPresented = false
            }
            secondaryButtonTitle = "Go Online"
            secondaryButtonAction = {
                self.isPresented = false
            }
        }

        isPresented = true
    }

    func dismiss() {
        isPresented = false
    }
}

struct OfflineGraceAlert: View {
    @ObservedObject var viewModel: OfflineGraceAlertViewModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismiss()
                }

            VStack(spacing: 20) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)

                Text(viewModel.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(viewModel.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    if let secondaryTitle = viewModel.secondaryButtonTitle,
                       let secondaryAction = viewModel.secondaryButtonAction {
                        Button(secondaryTitle) {
                            secondaryAction()
                            viewModel.dismiss()
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    }

                    Button(viewModel.primaryButtonTitle) {
                        viewModel.primaryButtonAction()
                        viewModel.dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(32)
            .background(Color.systemBackground)
            .cornerRadius(16)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
    }
}

extension Color {
    #if canImport(UIKit)
    static let systemBackground = Color(UIColor.systemBackground)
    #else
    static let systemBackground = Color.primary
    #endif
}
