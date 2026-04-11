import Foundation
import AVFoundation

public final class AudioEngine {
    public enum LatencyProfile {
        case lowLatency
        case balanced
        case streaming
    }

    enum RouteKind: Equatable {
        case speakerOrWired
        case bluetoothA2DP
        case bluetoothVoice
        case airPlay
        case externalHighLatency
    }

    struct Tuning: Equatable {
        let maxQueuedFrames: UInt32
        let minStartQueuedFrames: UInt32
        let hardResetQueuedFrames: UInt32
        let softLatencyCapFrames: UInt32
        let preferredScheduleFrames: UInt32
        let minPartialScheduleFrames: UInt32
        let preferredIOBufferDuration: TimeInterval
    }

    private var engine: AVAudioEngine
    private var playerNode: AVAudioPlayerNode
    private let queue = DispatchQueue(label: "com.xemu.audio", qos: .userInteractive)
    private let latencyProfile: LatencyProfile
    
    private var isPlaying = false
    private var queuedFrames: UInt32 = 0
    private var pendingPCM = Data()
    private var pendingPCMReadOffset = 0
    private let sampleRate: Double
    private let channels: AVAudioChannelCount
    private let outputFormat: AVAudioFormat
    private var maxQueuedFrames: UInt32
    private var minStartQueuedFrames: UInt32
    private var hardResetQueuedFrames: UInt32
    private var softLatencyCapFrames: UInt32
    private var preferredScheduleFrames: UInt32
    private var minPartialScheduleFrames: UInt32
    private var recoveryStartQueuedFrames: UInt32
    private var underrunBridgeFrames: UInt32
    private var maxConsecutiveBridgeBuffers: Int
    private var postLoadSilenceUntil: CFTimeInterval = 0
    private var postLoadFadeStart: CFTimeInterval = 0
    private var postLoadFadeUntil: CFTimeInterval = 0
    private let saturationThreshold: Int32 = 32_200
    private let abruptDeltaThreshold: Int32 = 30_000
    private var preferredIOBufferDuration: TimeInterval
    private var debugLastNonZeroQueuedFrames: UInt32 = 0
    private var shouldUseRecoveryStartThreshold = false
    private var consecutiveBridgeBuffers = 0
    private var routeKind: RouteKind = .speakerOrWired
    private var volume: Float
    #if os(iOS)
    private var routeObserver: NSObjectProtocol?
    public var onHardwareConfigurationChanged: ((Double) -> Void)?
    #endif

    static func tuning(sampleRate: Double, latencyProfile: LatencyProfile) -> Tuning {
        let targetFPS: Double = 60.0
        let framesPerTick = max(1, Int((sampleRate / targetFPS).rounded()))
        let tickFrames = UInt32(framesPerTick)

        switch latencyProfile {
        case .lowLatency:
            return Tuning(
                maxQueuedFrames: UInt32(sampleRate * 0.18),
                minStartQueuedFrames: tickFrames,
                hardResetQueuedFrames: UInt32(sampleRate * 0.45),
                softLatencyCapFrames: UInt32(sampleRate * 0.08),
                preferredScheduleFrames: tickFrames,
                minPartialScheduleFrames: UInt32(max(64, Int(Double(framesPerTick) * 0.15))),
                preferredIOBufferDuration: 0.012
            )
        case .streaming:
            let preferredStreamingFrames = UInt32(max(384, Int((Double(framesPerTick) * 0.75).rounded())))
            return Tuning(
                maxQueuedFrames: UInt32(sampleRate * 0.7),
                minStartQueuedFrames: tickFrames * 6,
                hardResetQueuedFrames: UInt32(sampleRate * 1.2),
                softLatencyCapFrames: tickFrames * 8,
                preferredScheduleFrames: preferredStreamingFrames,
                minPartialScheduleFrames: UInt32(max(192, Int(Double(preferredStreamingFrames) * 0.5))),
                preferredIOBufferDuration: 0.035
            )
        case .balanced:
            return Tuning(
                maxQueuedFrames: UInt32(sampleRate * 0.24),
                minStartQueuedFrames: tickFrames * 2,
                hardResetQueuedFrames: UInt32(sampleRate * 0.65),
                softLatencyCapFrames: UInt32(sampleRate * 0.12),
                preferredScheduleFrames: tickFrames,
                minPartialScheduleFrames: UInt32(max(128, Int(Double(framesPerTick) * 0.25))),
                preferredIOBufferDuration: 0.018
            )
        }
    }

    public init(
        sampleRate: Double = 48_000.0,
        channels: Int = 2,
        volume: Float = 1.0,
        latencyProfile: LatencyProfile = .balanced
    ) {
        self.volume = max(0.0, min(1.0, volume))
        self.sampleRate = sampleRate
        self.channels = AVAudioChannelCount(channels)
        self.latencyProfile = latencyProfile
        self.engine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()
        let tuning = Self.tuning(sampleRate: sampleRate, latencyProfile: latencyProfile)
        maxQueuedFrames = tuning.maxQueuedFrames
        minStartQueuedFrames = tuning.minStartQueuedFrames
        hardResetQueuedFrames = tuning.hardResetQueuedFrames
        softLatencyCapFrames = tuning.softLatencyCapFrames
        preferredScheduleFrames = tuning.preferredScheduleFrames
        minPartialScheduleFrames = tuning.minPartialScheduleFrames
        let initialTuning = Self.tuned(tuning, for: .speakerOrWired, sampleRate: sampleRate)
        maxQueuedFrames = initialTuning.maxQueuedFrames
        minStartQueuedFrames = initialTuning.minStartQueuedFrames
        hardResetQueuedFrames = initialTuning.hardResetQueuedFrames
        softLatencyCapFrames = initialTuning.softLatencyCapFrames
        preferredScheduleFrames = initialTuning.preferredScheduleFrames
        minPartialScheduleFrames = initialTuning.minPartialScheduleFrames
        preferredIOBufferDuration = initialTuning.preferredIOBufferDuration
        if latencyProfile == .streaming {
            recoveryStartQueuedFrames = max(
                initialTuning.preferredScheduleFrames * 3,
                initialTuning.minStartQueuedFrames
            )
            underrunBridgeFrames = max(
                initialTuning.minPartialScheduleFrames,
                initialTuning.preferredScheduleFrames
            )
            maxConsecutiveBridgeBuffers = 4
        } else {
            recoveryStartQueuedFrames = max(
                initialTuning.preferredScheduleFrames * 2,
                initialTuning.minPartialScheduleFrames
            )
            underrunBridgeFrames = initialTuning.minPartialScheduleFrames
            maxConsecutiveBridgeBuffers = 0
        }
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                        sampleRate: sampleRate,
                                        channels: self.channels,
                                        interleaved: true) else {
            fatalError("Failed to create audio format - sampleRate: \(sampleRate), channels: \(self.channels)")
        }
        outputFormat = format

        rebuildEngineGraph()
        #if os(iOS)
        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: nil
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
        #endif
    }

    deinit {
        #if os(iOS)
        if let routeObserver {
            NotificationCenter.default.removeObserver(routeObserver)
        }
        #endif
    }
    
    private func setupEngine() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: outputFormat)
        playerNode.prepare(withFrameCount: preferredScheduleFrames * 4)
        engine.mainMixerNode.outputVolume = volume
    }

    private func rebuildEngineGraph() {
        if engine.isRunning {
            engine.stop()
        }

        playerNode.stop()
        playerNode.reset()

        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        setupEngine()
    }
    
    public var isEngineRunning: Bool {
        return engine.isRunning
    }
    
    public func start() throws {
        guard !engine.isRunning else { return }
        try engine.start()
    }

    static func preferredHardwareSampleRate(fallback: Double) -> Double {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP])
        try? session.setPreferredSampleRate(fallback)
        try? session.setActive(true)
        let actual = session.sampleRate
        return actual > 0 ? actual : fallback
        #else
        return fallback
        #endif
    }

    static func tuned(_ tuning: Tuning, for routeKind: RouteKind, sampleRate: Double) -> Tuning {
        let multipliers: (
            maxQueuedFrames: UInt32,
            minStartQueuedFrames: UInt32,
            hardResetQueuedFrames: UInt32,
            softLatencyCapFrames: UInt32,
            preferredScheduleFrames: UInt32,
            minPartialScheduleFrames: UInt32,
            preferredIOBufferDuration: TimeInterval
        )
        let minimums: (
            scheduleFrames: UInt32,
            partialFrames: UInt32,
            startFrames: UInt32,
            softCapFrames: UInt32,
            hardResetFrames: UInt32,
            maxQueuedFrames: UInt32
        )

        switch routeKind {
        case .speakerOrWired:
            return tuning
        case .bluetoothA2DP:
            multipliers = (3, 4, 3, 4, 3, 3, 0.04)
            minimums = (
                UInt32(max(2_048, Int(sampleRate * 0.042))),
                UInt32(max(1_024, Int(sampleRate * 0.021))),
                UInt32(max(8_192, Int(sampleRate * 0.18))),
                UInt32(max(16_384, Int(sampleRate * 0.35))),
                UInt32(max(24_576, Int(sampleRate * 0.7))),
                UInt32(max(32_768, Int(sampleRate * 1.1)))
            )
        case .bluetoothVoice:
            multipliers = (4, 5, 4, 5, 4, 4, 0.05)
            minimums = (
                UInt32(max(2_560, Int(sampleRate * 0.055))),
                UInt32(max(1_280, Int(sampleRate * 0.028))),
                UInt32(max(10_240, Int(sampleRate * 0.22))),
                UInt32(max(18_432, Int(sampleRate * 0.4))),
                UInt32(max(28_672, Int(sampleRate * 0.8))),
                UInt32(max(36_864, Int(sampleRate * 1.25)))
            )
        case .airPlay:
            multipliers = (5, 6, 5, 6, 4, 4, 0.06)
            minimums = (
                UInt32(max(3_072, Int(sampleRate * 0.064))),
                UInt32(max(1_536, Int(sampleRate * 0.032))),
                UInt32(max(12_288, Int(sampleRate * 0.26))),
                UInt32(max(24_576, Int(sampleRate * 0.52))),
                UInt32(max(32_768, Int(sampleRate * 0.95))),
                UInt32(max(49_152, Int(sampleRate * 1.6)))
            )
        case .externalHighLatency:
            multipliers = (2, 3, 2, 3, 2, 2, 0.03)
            minimums = (
                UInt32(max(1_536, Int(sampleRate * 0.032))),
                UInt32(max(768, Int(sampleRate * 0.016))),
                UInt32(max(4_096, Int(sampleRate * 0.1))),
                UInt32(max(8_192, Int(sampleRate * 0.2))),
                UInt32(max(12_288, Int(sampleRate * 0.45))),
                UInt32(max(16_384, Int(sampleRate * 0.7)))
            )
        }

        return Tuning(
            maxQueuedFrames: max(tuning.maxQueuedFrames * multipliers.maxQueuedFrames, minimums.maxQueuedFrames),
            minStartQueuedFrames: max(tuning.minStartQueuedFrames * multipliers.minStartQueuedFrames, minimums.startFrames),
            hardResetQueuedFrames: max(tuning.hardResetQueuedFrames * multipliers.hardResetQueuedFrames, minimums.hardResetFrames),
            softLatencyCapFrames: max(tuning.softLatencyCapFrames * multipliers.softLatencyCapFrames, minimums.softCapFrames),
            preferredScheduleFrames: max(tuning.preferredScheduleFrames * multipliers.preferredScheduleFrames, minimums.scheduleFrames),
            minPartialScheduleFrames: max(tuning.minPartialScheduleFrames * multipliers.minPartialScheduleFrames, minimums.partialFrames),
            preferredIOBufferDuration: max(tuning.preferredIOBufferDuration, multipliers.preferredIOBufferDuration)
        )
    }

    private func applyTuning(_ tuning: Tuning, routeKind: RouteKind) {
        let effective = Self.tuned(tuning, for: routeKind, sampleRate: sampleRate)
        self.routeKind = routeKind
        maxQueuedFrames = effective.maxQueuedFrames
        minStartQueuedFrames = effective.minStartQueuedFrames
        hardResetQueuedFrames = effective.hardResetQueuedFrames
        softLatencyCapFrames = effective.softLatencyCapFrames
        preferredScheduleFrames = effective.preferredScheduleFrames
        minPartialScheduleFrames = effective.minPartialScheduleFrames
        preferredIOBufferDuration = effective.preferredIOBufferDuration

        let bridgeEnabledKinds: Set<RouteKind> = [.bluetoothA2DP, .bluetoothVoice, .airPlay, .externalHighLatency]
        if latencyProfile == .streaming || bridgeEnabledKinds.contains(routeKind) {
            recoveryStartQueuedFrames = max(
                effective.preferredScheduleFrames * 3,
                effective.minStartQueuedFrames
            )
            underrunBridgeFrames = max(
                effective.minPartialScheduleFrames,
                effective.preferredScheduleFrames
            )
            maxConsecutiveBridgeBuffers = routeKind == .speakerOrWired ? 4 : 6
        } else {
            recoveryStartQueuedFrames = max(
                effective.preferredScheduleFrames * 2,
                effective.minPartialScheduleFrames
            )
            underrunBridgeFrames = effective.minPartialScheduleFrames
            maxConsecutiveBridgeBuffers = 0
        }

        playerNode.prepare(withFrameCount: preferredScheduleFrames * 6)
    }

    #if os(iOS)
    static func routeKind(for portTypes: [AVAudioSession.Port]) -> RouteKind {
        if portTypes.contains(.airPlay) {
            return .airPlay
        }
        if portTypes.contains(.bluetoothHFP) || portTypes.contains(.bluetoothLE) {
            return .bluetoothVoice
        }
        if portTypes.contains(.bluetoothA2DP) {
            return .bluetoothA2DP
        }
        let externalHighLatencyRawValues: Set<String> = [
            AVAudioSession.Port.carAudio.rawValue,
            AVAudioSession.Port.usbAudio.rawValue,
            AVAudioSession.Port.lineOut.rawValue,
            "HDMI",
            "DisplayPort"
        ]
        if portTypes.contains(where: { externalHighLatencyRawValues.contains($0.rawValue) }) {
            return .externalHighLatency
        }
        return .speakerOrWired
    }

    static func routeKind(for outputs: [AVAudioSessionPortDescription]) -> RouteKind {
        routeKind(for: outputs.map(\.portType))
    }
    #endif
    
    public func updateAudioBuffer(_ samples: Data) {
        let bytesPerFrame = 2 * Int(channels)
        guard bytesPerFrame > 0 else { return }
        let frameCount = UInt32(samples.count / bytesPerFrame)
        guard frameCount > 0 else { return }

        queue.async { [weak self] in
            guard let self else { return }
            let now = CACurrentMediaTime()

            if now < self.postLoadSilenceUntil {
                return
            }

            var workingSamples = samples
            if now < self.postLoadFadeUntil {
                workingSamples = self.applyPostLoadFade(to: samples, atTime: now, bytesPerFrame: bytesPerFrame)
            }

            let sanitized = self.sanitizeCorruptedAudioChunk(workingSamples)
            workingSamples = sanitized.samples

            // Accumulate incoming PCM and drain in bounded chunks to avoid
            // dropping whole packets when queue pressure is transient.
            self.pendingPCM.append(workingSamples)
            self.logQueueStateIfNeeded(
                event: sanitized.wasSilenced ? "sanitized" : "enqueue",
                incomingFrames: frameCount,
                pendingFrames: UInt32(self.pendingPCM.count / bytesPerFrame),
                queuedFrames: self.queuedFrames,
                extra: sanitized.reason
            )
            self.drainPendingPCM(bytesPerFrame: bytesPerFrame)
        }
    }

    func sanitizeCorruptedAudioChunk(_ samples: Data) -> (samples: Data, wasSilenced: Bool, reason: String) {
        let sampleCount = samples.count / MemoryLayout<Int16>.size
        let checkCount = min(sampleCount, 256)
        guard checkCount >= 16 else { return (samples, false, "short") }

        var saturatedSamples = 0
        var abruptTransitions = 0
        var maxSaturatedRun = 0
        var currentSaturatedRun = 0

        samples.withUnsafeBytes { raw in
            let pcm = raw.bindMemory(to: Int16.self)
            guard pcm.count >= checkCount else { return }

            var previous = Int32(pcm[0])
            for index in 0..<checkCount {
                let sample = Int32(pcm[index])
                let magnitude = abs(sample)

                if magnitude >= saturationThreshold {
                    saturatedSamples += 1
                    currentSaturatedRun += 1
                    if currentSaturatedRun > maxSaturatedRun {
                        maxSaturatedRun = currentSaturatedRun
                    }
                } else {
                    currentSaturatedRun = 0
                }

                if index > 0, abs(sample - previous) >= abruptDeltaThreshold {
                    abruptTransitions += 1
                }
                previous = sample
            }
        }

        let isLikelyCorrupted: Bool
        if latencyProfile == .lowLatency {
            // Square-wave heavy handheld cores can have many abrupt transitions
            // without the chunk actually being corrupted.
            isLikelyCorrupted =
                maxSaturatedRun >= 12 ||
                saturatedSamples * 5 >= checkCount
        } else {
            isLikelyCorrupted =
                maxSaturatedRun >= 12 ||
                saturatedSamples * 5 >= checkCount ||
                abruptTransitions * 3 >= checkCount
        }

        guard isLikelyCorrupted else { return (samples, false, "ok") }
        let reason = "sat=\(saturatedSamples)/\(checkCount) abrupt=\(abruptTransitions) run=\(maxSaturatedRun)"
        return (Data(count: samples.count), true, reason)
    }

    private func drainPendingPCM(bytesPerFrame: Int) {
        guard bytesPerFrame > 0 else { return }
        let steadyStateCap = isPlaying ? softLatencyCapFrames : minStartQueuedFrames
        while queuedFrames < maxQueuedFrames {
            if steadyStateCap > 0, queuedFrames >= steadyStateCap {
                return
            }
            let availableFrames = pendingPCM.count / bytesPerFrame
            if availableFrames == 0 { return }

            let chunkFrames: Int
            if availableFrames >= Int(preferredScheduleFrames) {
                chunkFrames = Int(preferredScheduleFrames)
            } else if availableFrames >= Int(minPartialScheduleFrames),
                      (!isPlaying || queuedFrames < steadyStateCap) {
                // When queue depth is low, accept smaller chunks to avoid bursty
                // enqueue patterns that can underrun on variable-size core audio.
                chunkFrames = availableFrames
            } else if queuedFrames == 0 {
                // Recover quickly from underrun even if we're already marked as playing.
                chunkFrames = availableFrames
            } else if !isPlaying && queuedFrames == 0 {
                // Kickstart playback with whatever we have.
                chunkFrames = availableFrames
            } else {
                return
            }

            let chunkBytes = chunkFrames * bytesPerFrame
            let chunkStart = pendingPCMReadOffset
            let chunkEnd = chunkStart + chunkBytes
            let chunk = pendingPCM[chunkStart..<chunkEnd]
            pendingPCMReadOffset = chunkEnd
            compactPendingPCMIfNeeded()

            if let buffer = makePCMBuffer(from: Data(chunk), bytesPerFrame: bytesPerFrame) {
                playBufferOnQueue(buffer)
            } else {
                return
            }
        }
    }

    private func makePCMBuffer(from bytes: Data, bytesPerFrame: Int) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(bytes.count / bytesPerFrame)
        guard frameCount > 0 else { return nil }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount

        let bytesToCopy = Int(frameCount) * bytesPerFrame
        let audioBufferList = buffer.mutableAudioBufferList
        let mBuffer = audioBufferList.pointee.mBuffers
        guard let dst = mBuffer.mData else { return nil }

        bytes.withUnsafeBytes { rawBufferPointer in
            guard let src = rawBufferPointer.baseAddress else { return }
            memcpy(dst, src, min(bytesToCopy, bytes.count))
        }
        return buffer
    }

    private func makeSilencePCMBuffer(frameCount: UInt32) -> AVAudioPCMBuffer? {
        guard frameCount > 0 else { return nil }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else {
            return nil
        }
        buffer.frameLength = frameCount

        let audioBufferList = buffer.mutableAudioBufferList
        let mBuffer = audioBufferList.pointee.mBuffers
        guard let dst = mBuffer.mData else { return nil }
        memset(dst, 0, Int(mBuffer.mDataByteSize))
        return buffer
    }

    static func shouldBridgeUnderrun(
        bridgeUnderrunsEnabled: Bool,
        isPlaying: Bool,
        queuedFrames: UInt32,
        pendingFrames: UInt32,
        consecutiveBridgeBuffers: Int,
        maxConsecutiveBridgeBuffers: Int
    ) -> Bool {
        guard bridgeUnderrunsEnabled, isPlaying else { return false }
        guard queuedFrames == 0, pendingFrames == 0 else { return false }
        return consecutiveBridgeBuffers < maxConsecutiveBridgeBuffers
    }

    private func playBufferOnQueue(_ buffer: AVAudioPCMBuffer, isBridgeBuffer: Bool = false) {
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                return
            }
        }

        if queuedFrames > hardResetQueuedFrames {
            logQueueStateIfNeeded(
                event: "hard_reset",
                incomingFrames: buffer.frameLength,
                pendingFrames: UInt32(pendingPCM.count / max(1, Int(2 * channels))),
                queuedFrames: queuedFrames,
                extra: "threshold=\(hardResetQueuedFrames)"
            )
            playerNode.stop()
            playerNode.reset()
            queuedFrames = 0
            isPlaying = false
            pendingPCM.removeAll(keepingCapacity: true)
        }

        let frames = buffer.frameLength
        queuedFrames = queuedFrames &+ frames
        if isBridgeBuffer {
            consecutiveBridgeBuffers += 1
        } else {
            consecutiveBridgeBuffers = 0
        }
        playerNode.scheduleBuffer(buffer, completionCallbackType: .dataPlayedBack) { [weak self] _ in
            guard let self else { return }
            self.queue.async {
                self.queuedFrames = self.queuedFrames > frames ? self.queuedFrames - frames : 0
                let bytesPerFrame = max(1, Int(2 * self.channels))
                self.drainPendingPCM(bytesPerFrame: bytesPerFrame)
                let pendingFrames = UInt32(self.pendingPCM.count / bytesPerFrame)
                if Self.shouldBridgeUnderrun(
                    bridgeUnderrunsEnabled: self.maxConsecutiveBridgeBuffers > 0,
                    isPlaying: self.isPlaying,
                    queuedFrames: self.queuedFrames,
                    pendingFrames: pendingFrames,
                    consecutiveBridgeBuffers: self.consecutiveBridgeBuffers,
                    maxConsecutiveBridgeBuffers: self.maxConsecutiveBridgeBuffers
                ), let bridgeBuffer = self.makeSilencePCMBuffer(frameCount: self.underrunBridgeFrames) {
                    self.logQueueStateIfNeeded(
                        event: "bridge",
                        incomingFrames: 0,
                        pendingFrames: pendingFrames,
                        queuedFrames: self.queuedFrames,
                        extra: "frames=\(self.underrunBridgeFrames) count=\(self.consecutiveBridgeBuffers + 1)"
                    )
                    self.playBufferOnQueue(bridgeBuffer, isBridgeBuffer: true)
                    return
                }
                if self.maxConsecutiveBridgeBuffers > 0,
                   self.isPlaying,
                   self.queuedFrames == 0,
                   pendingFrames == 0,
                   self.debugLastNonZeroQueuedFrames > 0 {
                    self.shouldUseRecoveryStartThreshold = true
                    self.logQueueStateIfNeeded(
                        event: "underrun",
                        incomingFrames: 0,
                        pendingFrames: pendingFrames,
                        queuedFrames: 0,
                        extra: "last=\(self.debugLastNonZeroQueuedFrames)"
                    )
                    self.playerNode.pause()
                    self.isPlaying = false
                }
            }
        }

        let startThreshold = shouldUseRecoveryStartThreshold ? recoveryStartQueuedFrames : minStartQueuedFrames
        if !isPlaying && queuedFrames >= startThreshold {
            playerNode.play()
            isPlaying = true
            shouldUseRecoveryStartThreshold = false
            logQueueStateIfNeeded(
                event: "start_playback",
                incomingFrames: frames,
                pendingFrames: UInt32(pendingPCM.count / max(1, Int(2 * channels))),
                queuedFrames: queuedFrames,
                extra: "minStart=\(startThreshold)"
            )
        }
    }
    
    public func stop() {
        queue.async { [weak self] in
            self?.playerNode.stop()
            self?.playerNode.reset()
            self?.engine.stop()
            self?.isPlaying = false
            self?.queuedFrames = 0
            self?.pendingPCM.removeAll(keepingCapacity: false)
            self?.pendingPCMReadOffset = 0
        }
    }
    
    public func pause() {
        queue.async { [weak self] in
            self?.playerNode.pause()
            self?.engine.pause()
            self?.isPlaying = false
        }
    }
    
    public func resume() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.start()
            let bytesPerFrame = max(1, Int(2 * self.channels))
            self.drainPendingPCM(bytesPerFrame: bytesPerFrame)

            let startThreshold = self.shouldUseRecoveryStartThreshold
                ? self.recoveryStartQueuedFrames
                : self.minStartQueuedFrames
            if self.queuedFrames >= startThreshold {
                self.playerNode.play()
                self.isPlaying = true
                self.shouldUseRecoveryStartThreshold = false
            } else {
                self.isPlaying = false
            }
        }
    }
    
    public func setVolume(_ volume: Float) {
        let clamped = max(0.0, min(1.0, volume))
        self.volume = clamped
        engine.mainMixerNode.outputVolume = clamped
    }

    #if os(iOS)
    func applyRouteOverride(routeKind: RouteKind) {
        queue.sync {
            let baseTuning = Self.tuning(sampleRate: sampleRate, latencyProfile: latencyProfile)
            applyTuning(baseTuning, routeKind: routeKind)
            rebuildEngineGraph()
        }
    }
    #endif

    /// Flush queued audio and quarantine output briefly after state restore,
    /// then fade-in to avoid audible glitches from transient bad core samples.
    public func quarantineAfterStateLoad(silenceMs: Int = 350, fadeInMs: Int = 150) {
        queue.async { [weak self] in
            guard let self else { return }
            let now = CACurrentMediaTime()
            self.playerNode.stop()
            self.playerNode.reset()
            self.queuedFrames = 0
            self.pendingPCM.removeAll(keepingCapacity: true)
            self.pendingPCMReadOffset = 0
            self.isPlaying = false
            self.consecutiveBridgeBuffers = 0

            let silenceSeconds = max(0.0, Double(silenceMs) / 1000.0)
            let fadeSeconds = max(0.0, Double(fadeInMs) / 1000.0)
            self.postLoadSilenceUntil = now + silenceSeconds
            self.postLoadFadeStart = self.postLoadSilenceUntil
            self.postLoadFadeUntil = self.postLoadFadeStart + fadeSeconds
            self.shouldUseRecoveryStartThreshold = true
        }
    }

    private func applyPostLoadFade(to samples: Data, atTime now: CFTimeInterval, bytesPerFrame: Int) -> Data {
        guard bytesPerFrame > 0 else { return samples }
        let fadeDuration = max(postLoadFadeUntil - postLoadFadeStart, 0.001)
        let startProgress = max(0.0, min(1.0, (now - postLoadFadeStart) / fadeDuration))
        if startProgress >= 0.999 {
            return samples
        }

        var output = samples
        let frameCount = max(0, output.count / bytesPerFrame)
        if frameCount == 0 {
            return output
        }
        let endTime = now + (Double(frameCount) / sampleRate)
        let endProgress = max(0.0, min(1.0, (min(endTime, postLoadFadeUntil) - postLoadFadeStart) / fadeDuration))

        output.withUnsafeMutableBytes { raw in
            let pcm = raw.bindMemory(to: Int16.self)
            guard !pcm.isEmpty else { return }

            let channelsPerFrame = max(1, Int(channels))
            let frameTotal = pcm.count / channelsPerFrame
            guard frameTotal > 0 else { return }

            for frame in 0..<frameTotal {
                let t = frameTotal > 1 ? Double(frame) / Double(frameTotal - 1) : 0.0
                let gain = Float(startProgress + (endProgress - startProgress) * t)
                for ch in 0..<channelsPerFrame {
                    let idx = frame * channelsPerFrame + ch
                    let scaled = Float(pcm[idx]) * gain
                    let clipped = max(Float(Int16.min), min(Float(Int16.max), scaled))
                    pcm[idx] = Int16(clipped.rounded())
                }
            }
        }

        return output
    }

    public func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP])
            try session.setPreferredSampleRate(sampleRate)
            try session.setActive(true)
            refreshSessionConfiguration(session)
            rebuildEngineGraph()
            let actualSampleRate = session.sampleRate > 0 ? session.sampleRate : sampleRate
            if abs(actualSampleRate - sampleRate) >= 1 {
                DispatchQueue.main.async { [weak self] in
                    self?.onHardwareConfigurationChanged?(actualSampleRate)
                }
            }
        } catch {
        }
        #endif
    }
    
    public func deactivateAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setActive(false)
        } catch {
        }
        #endif
    }
    
    public var isPlayingAudio: Bool {
        return isPlaying && engine.isRunning
    }

    #if os(iOS)
    private static func shouldReconfigure(for reason: AVAudioSession.RouteChangeReason?) -> Bool {
        switch reason {
        case .some(.categoryChange):
            return false
        default:
            return true
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        let reasonRawValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
        let reason = reasonRawValue.flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
        guard Self.shouldReconfigure(for: reason) else { return }

        queue.async { [weak self] in
            guard let self else { return }
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [.allowBluetoothA2DP])
            try? session.setPreferredSampleRate(self.sampleRate)
            try? session.setActive(true)
            let actualSampleRate = session.sampleRate > 0 ? session.sampleRate : self.sampleRate
            self.refreshSessionConfiguration(session)
            self.rebuildEngineGraph()
            if abs(actualSampleRate - self.sampleRate) >= 1 {
                DispatchQueue.main.async { [weak self] in
                    self?.onHardwareConfigurationChanged?(actualSampleRate)
                }
                return
            }
            self.playerNode.stop()
            self.playerNode.reset()
            self.queuedFrames = 0
            self.pendingPCM.removeAll(keepingCapacity: true)
            self.pendingPCMReadOffset = 0
            self.isPlaying = false
            self.shouldUseRecoveryStartThreshold = true
            self.consecutiveBridgeBuffers = 0
            try? self.start()
        }
    }

    private func refreshSessionConfiguration(_ session: AVAudioSession) {
        let newRouteKind = Self.routeKind(for: session.currentRoute.outputs)
        let baseTuning = Self.tuning(sampleRate: sampleRate, latencyProfile: latencyProfile)
        applyTuning(baseTuning, routeKind: newRouteKind)
        try? session.setPreferredIOBufferDuration(preferredIOBufferDuration)
    }
    #endif

    private func compactPendingPCMIfNeeded() {
        guard pendingPCMReadOffset > 0 else { return }
        if pendingPCMReadOffset == pendingPCM.count {
            pendingPCM.removeAll(keepingCapacity: true)
            pendingPCMReadOffset = 0
            return
        }

        let consumedEnoughToCompact = pendingPCMReadOffset >= 16_384
        let consumedMostOfBuffer = pendingPCMReadOffset * 2 >= pendingPCM.count
        guard consumedEnoughToCompact || consumedMostOfBuffer else { return }

        pendingPCM.removeSubrange(0..<pendingPCMReadOffset)
        pendingPCMReadOffset = 0
    }

    private func logQueueStateIfNeeded(
        event: String,
        incomingFrames: UInt32,
        pendingFrames: UInt32,
        queuedFrames: UInt32,
        extra: String
    ) {
        _ = event
        _ = incomingFrames
        _ = pendingFrames
        _ = extra
        if queuedFrames > 0 {
            debugLastNonZeroQueuedFrames = queuedFrames
        }
    }

    #if os(iOS)
    #endif
}
