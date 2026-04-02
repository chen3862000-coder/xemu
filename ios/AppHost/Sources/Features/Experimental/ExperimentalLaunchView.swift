import SwiftUI

public struct ExperimentalLaunchView: View {
    @Environment(\.dismiss) private var dismiss

    private let romName: String
    private let romHash: String
    private let compatInfo: CompatibilityInfo
    private let deviceClass: HardwareClass
    private let onLaunch: (ExperimentalSettings) -> Void

    @State private var resolutionScale: Double = 1.0
    @State private var frameSkip: Int = 0
    @State private var showingDiagnostics = false

    init(
        romName: String,
        romHash: String,
        compatInfo: CompatibilityInfo,
        deviceClass: HardwareClass,
        onLaunch: @escaping (ExperimentalSettings) -> Void
    ) {
        self.romName = romName
        self.romHash = romHash
        self.compatInfo = compatInfo
        self.deviceClass = deviceClass
        self.onLaunch = onLaunch
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                warningSection
                performanceSection
                launchButton
            }
            .padding()
            .navigationTitle("Experimental Launch")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Diagnostics") { showingDiagnostics = true }
                }
            }
            .sheet(isPresented: $showingDiagnostics) {
                CompatibilityDiagnosticsSheet(
                    compatInfo: compatInfo,
                    deviceClass: deviceClass
                )
            }
        }
    }

    private var warningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Experimental ROM", systemImage: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)

            Text("This ROM is marked as experimental and may:")
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Crash or freeze unexpectedly")
                }
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Have visual or audio glitches")
                }
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Run slowly on your device")
                }
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Lose progress (save states may fail)")
                }
            }
            .font(.footnote)
            .foregroundColor(.secondary)

            if !compatInfo.notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Compatibility Notes:")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text(compatInfo.notes)
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            Text("By proceeding, you acknowledge that this emulation is experimental.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
    }

    private var performanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Resolution Scale")
                    Spacer()
                    Text(String(format: "%.0fx", resolutionScale))
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)

                Slider(value: $resolutionScale, in: 0.25...2.0, step: 0.25) {
                    Text("Resolution Scale")
                }

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text("Lower scale improves performance at the cost of visual quality")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Frame Skip")
                    Spacer()
                    Text("\(frameSkip)")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)

                Stepper("Frame Skip", value: $frameSkip, in: 0...4)

                HStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .font(.caption)
                    Text("Skip frames to improve performance (0 = no skipping)")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
    }

    private var launchButton: some View {
        Button {
            let settings = ExperimentalSettings(
                resolutionScale: resolutionScale,
                frameSkip: frameSkip
            )
            onLaunch(settings)
            dismiss()
        } label: {
            HStack {
                Spacer()
                Label("Launch \(romName)", systemImage: "play.fill")
                Spacer()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)
        }
    }
}

public struct ExperimentalSettings {
    public let resolutionScale: Double
    public let frameSkip: Int

    public init(resolutionScale: Double, frameSkip: Int) {
        self.resolutionScale = resolutionScale
        self.frameSkip = frameSkip
    }
}

#Preview {
    ExperimentalLaunchView(
        romName: "Experimental Game",
        romHash: "abc123",
        compatInfo: CompatibilityInfo(
            id: UUID(),
            romHash: "abc123",
            minDeviceTier: .tier2,
            tier: .experimental,
            notes: "Known issues with audio glitches on older devices"
        ),
        deviceClass: .tier2
    ) { _ in }
}
