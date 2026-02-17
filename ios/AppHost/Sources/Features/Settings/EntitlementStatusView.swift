import SwiftUI
import Combine

struct EntitlementStatusView: View {
    @StateObject private var viewModel = EntitlementViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color.gray.opacity(0.1)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        statusCard
                        offlineGraceCard
                        deviceInfoCard
                        subscriptionDetails
                        troubleshootingSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Account Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .refreshable {
                await viewModel.refreshStatus()
            }
        }
    }

    private var statusCard: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: statusIcon)
                    .font(.system(size: 40))
                    .foregroundColor(statusColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statusTitle)
                        .font(.headline)
                    Text(statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Refresh") {
                    Task {
                        await viewModel.refreshStatus()
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)

            if viewModel.isRefreshing {
                ProgressView()
                    .padding()
            }
        }
    }

    private var offlineGraceCard: some View {
        VStack(alignment: .leading, spelling: 16) {
            Text("Offline Grace Period")
                .font(.headline)

            HStack {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.offlineGraceEnd, style: .relative)
                        .font(.subheadline)
                    Text("until next entitlement check required")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    private var deviceInfoCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Info")
                .font(.headline)

            InfoRow(label: "Device ID", value: viewModel.deviceId.uuidString.prefix(8) + "...")
            InfoRow(label: "Hardware Class", value: viewModel.hardwareClass)
            InfoRow(label: "Last Checked", value: viewModel.lastChecked)
            InfoRow(label: "ROM Storage", value: viewModel.romStorageFormatted)

            HStack {
                Text("Legit Mode")
                    .foregroundColor(.secondary)

                Spacer()

                Image(systemName: viewModel.legitModeCapable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(viewModel.legitModeCapable ? .green : .red)
            }
            .padding(.vertical, 4)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    private var subscriptionDetails: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Entitlements")
                .font(.headline)

            if viewModel.entitlements.isEmpty {
                Text("No active entitlements")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                ForEach(viewModel.entitlements) { entitlement in
                    EntitlementRow(entitlement: entitlement)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    private var troubleshootingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Troubleshooting")
                .font(.headline)

            VStack(spacing: 8) {
                Button(action: { viewModel.showTroubleshooting(.entitlementSync) }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Entitlements")
                        Spacer()
                    }
                    .padding()
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.showTroubleshooting(.deviceRefresh) }) {
                    HStack {
                        Image(systemName: "iphone")
                        Text("Refresh Device Info")
                        Spacer()
                    }
                    .padding()
                }
                .buttonStyle(.plain)

                Button(action: { viewModel.showTroubleshooting(.cacheClear) }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Cache")
                        Spacer()
                    }
                    .padding()
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }

    private var statusIcon: String {
        switch viewModel.entitlementStatus {
        case .active:
            return "checkmark.shield.fill"
        case .inactive:
            return "exclamationmark.shield.fill"
        case .unknown:
            return "questionmark.shield.fill"
        }
    }

    private var statusColor: Color {
        switch viewModel.entitlementStatus {
        case .active: return .green
        case .inactive: return .orange
        case .unknown: return .gray
        }
    }

    private var statusTitle: String {
        switch viewModel.entitlementStatus {
        case .active: return "Entitlement Active"
        case .inactive: return "Entitlement Inactive"
        case .unknown: return "Status Unknown"
        }
    }

    private var statusMessage: String {
        switch viewModel.entitlementStatus {
        case .active: return "Your account is in good standing"
        case .inactive: return "Please check your subscription"
        case .unknown: return "Unable to verify status"
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct EntitlementRow: View {
    let entitlement: CachedEntitlement

    var body: some View {
        HStack {
            Image(systemName: "badge.checkered")
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text(entitlement.productCode.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let expires = entitlement.expiresAt {
                    Text("Expires: \(expires.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Lifetime")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

final class EntitlementViewModel: ObservableObject {
    @Published var entitlementStatus: EntitlementStatus = .unknown
    @Published var isRefreshing = false
    @Published var entitlements: [CachedEntitlement] = []
    @Published var deviceId: UUID = UUID()
    @Published var hardwareClass: String = "Unknown"
    @Published var lastChecked: String = "Never"
    @Published var offlineGraceEnd: Date = Date()
    @Published var legitModeCapable: Bool = true
    @Published var romStorageBytes: Int64 = 0

    private let entitlementCache: EntitlementCache
    private let deviceProfileCache: DeviceProfileCache

    init(entitlementCache: EntitlementCache = .shared, deviceProfileCache: DeviceProfileCache = .shared) {
        self.entitlementCache = entitlementCache
        self.deviceProfileCache = deviceProfileCache
        loadCachedData()
    }

    func refreshStatus() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let azureStub = AzureApiStub.shared

        do {
            let profile = try await azureStub.fetchDeviceProfile(deviceId: deviceId)
            await MainActor.run {
                self.hardwareClass = profile.hardwareClass
                self.legitModeCapable = profile.legitModeCapable
                self.romStorageBytes = profile.romStorageBytes
                self.lastChecked = Date().formatted(date: .abbreviated, time: .shortened)
                self.entitlementStatus = .active
            }

            deviceProfileCache.cache(profile)
        } catch {
            await MainActor.run {
                self.entitlementStatus = .inactive
            }
        }

        loadCachedData()
    }

    private func loadCachedData() {
        entitlements = entitlementCache.loadEntitlements()

        if let profile = deviceProfileCache.loadProfile() {
            deviceId = profile.deviceId ?? deviceId
            hardwareClass = profile.hardwareClass ?? "Unknown"
            legitModeCapable = profile.legitModeCapable ?? true
            romStorageBytes = profile.romStorageBytes ?? 0

            if let graceEnd = profile.offlineGraceEnd {
                offlineGraceEnd = graceEnd
            }

            if let lastCheck = profile.lastEntitlementRefresh {
                lastChecked = lastCheck.formatted(date: .abbreviated, time: .shortened)
            }
        }
    }

    var romStorageFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: romStorageBytes)
    }

    func showTroubleshooting(_ action: TroubleshootingAction) {
        switch action {
        case .entitlementSync:
            Task {
                await refreshStatus()
            }
        case .deviceRefresh:
            Task {
                await refreshStatus()
            }
        case .cacheClear:
            entitlementCache.clear()
            deviceProfileCache.clear()
            loadCachedData()
        }
    }
}

enum TroubleshootingAction {
    case entitlementSync
    case deviceRefresh
    case cacheClear
}

struct CachedEntitlement: Identifiable, Codable {
    let id: UUID
    let productCode: ProductCode
    let status: EntitlementStatus
    let activatedAt: Date
    let expiresAt: Date?
}

final class EntitlementCache {
    static let shared = EntitlementCache()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileURL: URL

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("entitlements_cache.json")
    }

    func loadEntitlements() -> [CachedEntitlement] {
        guard let data = try? Data(contentsOf: fileURL),
              let entitlements = try? decoder.decode([CachedEntitlement].self, from: data) else {
            return []
        }
        return entitlements
    }

    func cache(_ entitlements: [CachedEntitlement]) {
        guard let data = try? encoder.encode(entitlements) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

final class DeviceProfileCache {
    static let shared = DeviceProfileCache()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileURL: URL

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("device_profile_cache.json")
    }

    func loadProfile() -> CachedDeviceProfile? {
        guard let data = try? Data(contentsOf: fileURL),
              let profile = try? decoder.decode(CachedDeviceProfile.self, from: data) else {
            return nil
        }
        return profile
    }

    func cache(_ profile: CachedDeviceProfile) {
        guard let data = try? encoder.encode(profile) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

struct CachedDeviceProfile: Codable {
    let deviceId: UUID
    let hardwareClass: String
    let legitModeCapable: Bool
    let romStorageBytes: Int64
    let offlineGraceEnd: Date?
    let lastEntitlementRefresh: Date?
}

extension AzureApiStub {
    func fetchDeviceProfile(deviceId: UUID) async throws -> CachedDeviceProfile {
        let compat = try await fetchCompatibilityMatrix()
        let entitlement = try await fetchEntitlements(userId: deviceId)

        return CachedDeviceProfile(
            deviceId: deviceId,
            hardwareClass: "Tier1",
            legitModeCapable: true,
            romStorageBytes: 1024 * 1024 * 100,
            offlineGraceEnd: Date().addingTimeInterval(7 * 24 * 60 * 60),
            lastEntitlementRefresh: Date()
        )
    }
}
