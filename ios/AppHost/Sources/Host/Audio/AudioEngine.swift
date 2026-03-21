import Foundation
import AVFoundation

public final class AudioEngine {
    public enum LatencyProfile {
        case lowLatency
        case balanced
        case streaming
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

    private let engine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private let queue = DispatchQueue(label: "com.xemu.audio", qos: .userInteractive)
    
    private var isPlaying = false
    private var queuedFrames: UInt32 = 0
    private var pendingPCM = Data()
    private var pendingPCMReadOffset = 0
    private let sampleRate: Double
    private let channels: AVAudioChannelCount
    private let outputFormat: AVAudioFormat
    private let maxQueuedFrames: UInt32
    private let minStartQueuedFrames: UInt32
    private let hardResetQueuedFrames: UInt32
    private let softLatencyCapFrames: UInt32
    private let preferredScheduleFrames: UInt32
    private let minPartialScheduleFrames: UInt32
    private let recoveryStartQueuedFrames: UInt32
    private let underrunBridgeFrames: UInt32
    private let maxConsecutiveBridgeBuffers: Int
    private var postLoadSilenceUntil: CFTimeInterval = 0
    private var postLoadFadeStart: CFTimeInterval = 0
    private var postLoadFadeUntil: CFTimeInterval = 0
    private let saturationThreshold: Int32 = 32_200
    private let abruptDeltaThreshold: Int32 = 30_000
    private let preferredIOBufferDuration: TimeInterval
    private let debugQueueMetricsEnabled: Bool
    private var debugChunkCount: Int = 0
    private var debugLastNonZeroQueuedFrames: UInt32 = 0
    private var shouldUseRecoveryStartThreshold = false
    private var consecutiveBridgeBuffers = 0

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
        self.sampleRate = sampleRate
        self.channels = AVAudioChannelCount(channels)
        self.engine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()
        let tuning = Self.tuning(sampleRate: sampleRate, latencyProfile: latencyProfile)
        maxQueuedFrames = tuning.maxQueuedFrames
        minStartQueuedFrames = tuning.minStartQueuedFrames
        hardResetQueuedFrames = tuning.hardResetQueuedFrames
        softLatencyCapFrames = tuning.softLatencyCapFrames
        preferredScheduleFrames = tuning.preferredScheduleFrames
        minPartialScheduleFrames = tuning.minPartialScheduleFrames
        if latencyProfile == .streaming {
            recoveryStartQueuedFrames = max(
                tuning.preferredScheduleFrames * 5,
                tuning.minStartQueuedFrames
            )
            underrunBridgeFrames = max(
                tuning.minPartialScheduleFrames,
                tuning.preferredScheduleFrames
            )
            maxConsecutiveBridgeBuffers = 4
        } else {
            recoveryStartQueuedFrames = max(
                tuning.preferredScheduleFrames * 2,
                tuning.minPartialScheduleFrames
            )
            underrunBridgeFrames = tuning.minPartialScheduleFrames
            maxConsecutiveBridgeBuffers = 0
        }
        preferredIOBufferDuration = tuning.preferredIOBufferDuration
        debugQueueMetricsEnabled = latencyProfile == .streaming
        
        outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                     sampleRate: sampleRate,
                                     channels: self.channels,
                                     interleaved: true)!
        
        setupEngine()
        setVolume(volume)
    }
    
    private func setupEngine() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: outputFormat)
        playerNode.prepare(withFrameCount: preferredScheduleFrames * 4)
    }
    
    public var isEngineRunning: Bool {
        return engine.isRunning
    }
    
    public func start() throws {
        guard !engine.isRunning else { return }
        try engine.start()
    }
    
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

        let isLikelyCorrupted =
            maxSaturatedRun >= 12 ||
            saturatedSamples * 5 >= checkCount ||
            abruptTransitions * 3 >= checkCount

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
        debugQueueMetricsEnabled: Bool,
        isPlaying: Bool,
        queuedFrames: UInt32,
        pendingFrames: UInt32,
        consecutiveBridgeBuffers: Int,
        maxConsecutiveBridgeBuffers: Int
    ) -> Bool {
        guard debugQueueMetricsEnabled, isPlaying else { return false }
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
                    debugQueueMetricsEnabled: self.debugQueueMetricsEnabled,
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
                if self.debugQueueMetricsEnabled,
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
        engine.mainMixerNode.outputVolume = max(0.0, min(1.0, volume))
    }

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
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setPreferredSampleRate(sampleRate)
            try session.setPreferredIOBufferDuration(preferredIOBufferDuration)
            try session.setActive(true)
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
        guard debugQueueMetricsEnabled else { return }
        debugChunkCount += 1
        if queuedFrames > 0 {
            debugLastNonZeroQueuedFrames = queuedFrames
        }
        _ = event
        _ = incomingFrames
        _ = pendingFrames
        _ = extra
    }
}
