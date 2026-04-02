import SwiftUI

struct ControllerInputDebugView: View {
    @State private var listenerToken: UUID?
    @State private var controllerObserverToken: UUID?
    @State private var isControllerConnected = false
    @State private var controllerName = "—"
    @State private var averageLatencyMs: Double?
    @State private var pressedButtons: [ControllerButton] = []
    @State private var recentEvents: [InputEvent] = []

    private let maxRecentEvents = 24

    var body: some View {
        List {
            Section("Controller") {
                LabeledContent("Status", value: isControllerConnected ? "Connected" : "Not Connected")
                LabeledContent("Name", value: controllerName)
                LabeledContent(
                    "Average Latency",
                    value: averageLatencyMs.map { String(format: "%.1f ms", $0) } ?? "—"
                )
            }

            Section("Live Buttons") {
                if pressedButtons.isEmpty {
                    Text("No active button presses.")
                        .foregroundStyle(.secondary)
                } else {
                    Text(pressedButtons.map(\.rawValue).joined(separator: ", "))
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section("Recent Events") {
                if recentEvents.isEmpty {
                    Text("Waiting for controller input.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(recentEvents.enumerated()), id: \.offset) { _, event in
                        HStack {
                            Text(event.button.rawValue)
                                .font(.system(.body, design: .monospaced))
                            Spacer()
                            Text(event.isPressed ? "down" : "up")
                                .foregroundStyle(event.isPressed ? .green : .secondary)
                            Text(event.timestamp, style: .time)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Controller Input Debug")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Clear", action: clearEvents)
            }
        }
        #else
        .toolbar {
            ToolbarItem {
                Button("Clear", action: clearEvents)
            }
        }
        #endif
        .onAppear(perform: startListening)
        .onDisappear(perform: stopListening)
    }

    private func startListening() {
        refreshSnapshot()

        if controllerObserverToken == nil {
            controllerObserverToken = InputBus.shared.addControllerObserver(
                onConnected: { name in
                    isControllerConnected = true
                    controllerName = name
                },
                onDisconnected: {
                    isControllerConnected = false
                    controllerName = "—"
                    pressedButtons.removeAll()
                }
            )
        }

        guard listenerToken == nil else { return }
        listenerToken = InputBus.shared.addListener { event in
            Task { @MainActor in
                record(event)
            }
        }
    }

    private func stopListening() {
        if let listenerToken {
            InputBus.shared.removeListener(listenerToken)
            self.listenerToken = nil
        }
        if let controllerObserverToken {
            InputBus.shared.removeControllerObserver(controllerObserverToken)
            self.controllerObserverToken = nil
        }
    }

    private func refreshSnapshot() {
        isControllerConnected = InputBus.shared.isControllerConnected()
        controllerName = InputBus.shared.getActiveControllerName() ?? "—"
        averageLatencyMs = InputBus.shared.getAverageInputLatency().map { $0 * 1_000 }
    }

    private func clearEvents() {
        recentEvents.removeAll()
        pressedButtons.removeAll()
        InputBus.shared.resetLatencySamples()
        averageLatencyMs = nil
    }

    private func record(_ event: InputEvent) {
        if event.isPressed {
            if !pressedButtons.contains(event.button) {
                pressedButtons.append(event.button)
                pressedButtons.sort { $0.rawValue < $1.rawValue }
            }
        } else {
            pressedButtons.removeAll { $0 == event.button }
        }

        recentEvents.insert(event, at: 0)
        if recentEvents.count > maxRecentEvents {
            recentEvents.removeLast(recentEvents.count - maxRecentEvents)
        }

        averageLatencyMs = InputBus.shared.getAverageInputLatency().map { $0 * 1_000 }
        refreshSnapshot()
    }
}
