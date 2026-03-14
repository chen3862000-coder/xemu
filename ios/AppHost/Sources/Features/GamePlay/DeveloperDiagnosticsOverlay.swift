import SwiftUI

struct DeveloperDiagnosticsOverlay: View {
    let snapshot: PerfHUDSnapshot
    let showMemoryMonitor: Bool
    let showThermalStatus: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showMemoryMonitor {
                Text(
                    String(
                        format: "Mem %.0fMB  Peak %.0fMB  Warn %d",
                        snapshot.memoryMB,
                        snapshot.peakMemoryMB,
                        snapshot.memoryWarnings
                    )
                )
            }

            if showThermalStatus {
                Text("Thermal \(thermalLabel(snapshot.thermalState))  LPM \(snapshot.lowPowerModeEnabled ? "ON" : "OFF")")
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.95))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
    }

    private func thermalLabel(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "Nominal"
        case .fair: return "Fair"
        case .serious: return "Serious"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
