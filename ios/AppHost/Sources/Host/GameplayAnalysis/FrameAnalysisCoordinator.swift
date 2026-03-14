import Foundation

final class FrameAnalysisCoordinator {
    private let profile: MarioGameProfile
    private let queue: DispatchQueue
    private let analyzer: MarioFrameAnalyzer
    private let stateMachine: GameplayEventStateMachine
    private let onResult: @MainActor ([GameplayEvent], MarioAnalysisSnapshot) -> Void

    private var lastSampleAt: Date?
    private var isProcessing = false
    private var pendingFrame: (frame: FrameBufferInfo, timestamp: Date)?

    init(
        profile: MarioGameProfile,
        onResult: @escaping @MainActor ([GameplayEvent], MarioAnalysisSnapshot) -> Void
    ) {
        self.profile = profile
        self.queue = DispatchQueue(label: "com.xemu.gameplay-analysis.\(profile.id)", qos: .userInitiated)
        self.analyzer = MarioFrameAnalyzer(profile: profile)
        self.stateMachine = GameplayEventStateMachine(profile: profile)
        self.onResult = onResult
    }

    func enqueue(frameBufferInfo: FrameBufferInfo, timestamp: Date = Date()) {
        if let lastSampleAt, timestamp.timeIntervalSince(lastSampleAt) < profile.minSampleInterval {
            return
        }
        lastSampleAt = timestamp

        if isProcessing {
            pendingFrame = (frameBufferInfo, timestamp)
            return
        }

        isProcessing = true
        process(frameBufferInfo, timestamp: timestamp)
    }

    func reset() {
        lastSampleAt = nil
        pendingFrame = nil
        isProcessing = false
    }

    private func process(_ frameBufferInfo: FrameBufferInfo, timestamp: Date) {
        queue.async { [weak self] in
            guard let self else { return }
            let observation = self.analyzer.analyze(frameBufferInfo: frameBufferInfo, timestamp: timestamp)
            let result = self.stateMachine.consume(observation)
            DispatchQueue.main.async {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.onResult(result.events, result.snapshot)
                    self.finishProcessing()
                }
            }
        }
    }

    private func finishProcessing() {
        if let pendingFrame {
            self.pendingFrame = nil
            process(pendingFrame.frame, timestamp: pendingFrame.timestamp)
            return
        }
        isProcessing = false
    }
}
