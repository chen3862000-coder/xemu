import SwiftUI

struct GameplayEventDiagnosticsOverlay: View {
    let snapshot: MarioAnalysisSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(snapshot.profileName)
                .font(.system(size: 11, weight: .bold, design: .monospaced))

            Text("Phase \(snapshot.gameplayPhase.rawValue)")
            Text("State \(snapshot.playerState.rawValue)  conf \(percent(snapshot.playerStateConfidence))")
            Text("Damage \(percent(snapshot.damageConfidence))  Death \(percent(snapshot.deathConfidence))")
            Text("Blink \(percent(snapshot.blinkConfidence))  Cooldown \(snapshot.inDamageCooldown ? time(snapshot.damageCooldownRemaining) : "off")")

            if let trackerBounds = snapshot.trackerBounds {
                Text(
                    String(
                        format: "Track x%.2f y%.2f w%.2f h%.2f",
                        trackerBounds.origin.x,
                        trackerBounds.origin.y,
                        trackerBounds.width,
                        trackerBounds.height
                    )
                )
            } else {
                Text("Track unavailable")
            }

            if let lastEvent = snapshot.lastEvent {
                Text("Last \(lastEvent.rawValue)")
            }

            if let memoryDebugSummary = snapshot.memoryDebugSummary {
                Text(memoryDebugSummary)
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .monospaced))
        .foregroundStyle(.white.opacity(0.95))
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.green.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func time(_ value: TimeInterval) -> String {
        String(format: "%.1fs", max(0, value))
    }
}
