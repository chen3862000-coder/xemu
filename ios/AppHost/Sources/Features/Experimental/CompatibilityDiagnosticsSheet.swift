import SwiftUI

public struct CompatibilityDiagnosticsSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let compatInfo: CompatibilityInfo
    private let deviceClass: HardwareClass

    public init(
        compatInfo: CompatibilityInfo,
        deviceClass: HardwareClass
    ) {
        self.compatInfo = compatInfo
        self.deviceClass = deviceClass
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    compatibilityStatusSection
                    deviceInfoSection
                    performanceRecommendations
                    if compatInfo.tier == .experimental {
                        refundGuidanceSection
                    }
                }
                .padding()
            }
            .navigationTitle("Compatibility Diagnostics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var compatibilityStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Compatibility Status")
                .font(.headline)

            HStack {
                VStack(alignment: .leading) {
                    Text("ROM Tier")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(compatInfo.tier.rawValue.uppercased())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Spacer()

                Image(systemName: compatInfo.tier == .experimental ? "flame.fill" : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(compatInfo.tier == .experimental ? .orange : .green)
            }
            .padding()
            .background(compatInfo.tier == .experimental ? Color.orange.opacity(0.1) : Color.green.opacity(0.1))
            .cornerRadius(8)

            HStack {
                VStack(alignment: .leading) {
                    Text("Minimum Device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(compatInfo.minDeviceTier.rawValue.uppercased())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Spacer()

                Image(systemName: deviceMeetsRequirement ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(deviceMeetsRequirement ? .green : .red)
            }
            .padding()
            .background(deviceMeetsRequirement ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private var deviceInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Information")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                deviceInfoRow(label: "Hardware Class", value: deviceClass.rawValue.uppercased())
                deviceInfoRow(label: "Device Model", value: getCurrentDeviceModel())
                deviceInfoRow(label: "Platform", value: "macOS")
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private func deviceInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }

    private var performanceRecommendations: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Recommendations")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                recommendationRow(
                    icon: "speedometer",
                    text: getResolutionRecommendation(),
                    color: .blue
                )
                recommendationRow(
                    icon: "bolt.fill",
                    text: getFrameSkipRecommendation(),
                    color: .green
                )
                recommendationRow(
                    icon: "speaker.wave.2.fill",
                    text: "Close other apps to free up memory",
                    color: .purple
                )
                recommendationRow(
                    icon: "battery.100",
                    text: "Connect to charger for sustained performance",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private func recommendationRow(icon: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)

            Text(text)
                .font(.subheadline)
        }
    }

    private var refundGuidanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Refund Policy")
                .font(.headline)
                .foregroundColor(.red)

            VStack(alignment: .leading, spacing: 8) {
                Text("Since this ROM is experimental, you may experience issues. You're entitled to a refund within 14 days of purchase if:")
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Text("•")
                        Text("The ROM crashes frequently")
                    }
                    HStack(alignment: .top) {
                        Text("•")
                        Text("Performance is unplayable even with max frame skip")
                    }
                    HStack(alignment: .top) {
                        Text("•")
                        Text("Critical bugs prevent gameplay")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)

                Text("To request a refund:")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top) {
                        Image(systemName: "1.circle.fill")
                        Text("Go to Settings → Purchases")
                    }
                    HStack(alignment: .top) {
                        Image(systemName: "2.circle.fill")
                        Text("Select EXPERIMENTAL_PACK")
                    }
                    HStack(alignment: .top) {
                        Image(systemName: "3.circle.fill")
                        Text("Tap \"Request Refund\"")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.red.opacity(0.05))
            .cornerRadius(12)
        }
    }

    private var deviceMeetsRequirement: Bool {
        let deviceRank = deviceClass.rank
        let requiredRank = compatInfo.minDeviceTier.rank
        return deviceRank >= requiredRank
    }

    private func getResolutionRecommendation() -> String {
        switch deviceClass {
        case .tier1:
            return "Try 1.5x-2.0x resolution for best visuals"
        case .tier2:
            return "Try 1.0x-1.5x resolution"
        case .tier3:
            return "Use 0.75x-1.0x resolution for stability"
        case .unsupported:
            return "Use 0.5x resolution, performance may be poor"
        }
    }

    private func getFrameSkipRecommendation() -> String {
        switch deviceClass {
        case .tier1:
            return "Frame skip of 0-1 should be fine"
        case .tier2:
            return "Try frame skip of 1-2"
        case .tier3:
            return "Use frame skip of 2-3 for smooth playback"
        case .unsupported:
            return "Frame skip of 3-4 may be necessary"
        }
    }

    private func getCurrentDeviceModel() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}

private extension HardwareClass {
    var rank: Int {
        switch self {
        case .tier1: return 3
        case .tier2: return 2
        case .tier3: return 1
        case .unsupported: return 0
        }
    }
}

#Preview {
    CompatibilityDiagnosticsSheet(
        compatInfo: CompatibilityInfo(
            id: UUID(),
            romHash: "abc123",
            minDeviceTier: .tier2,
            tier: .experimental,
            notes: "Known issues with audio glitches on older devices"
        ),
        deviceClass: .tier2
    )
}
