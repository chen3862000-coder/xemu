import Foundation
import AVFoundation

public final class AudioEngine {
    
    private let engine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private let queue = DispatchQueue(label: "com.xemu.audio", qos: .userInteractive)
    
    private var isPlaying = false
    private var queuedFrames: UInt32 = 0
    private var pendingPCM = Data()
    private let sampleRate: Double
    private let channels: AVAudioChannelCount
    private let outputFormat: AVAudioFormat
    private let maxQueuedFrames: UInt32
    private let minStartQueuedFrames: UInt32
    private let hardResetQueuedFrames: UInt32
    private let softLatencyCapFrames: UInt32
    private let preferredScheduleFrames: UInt32
    private let minPartialScheduleFrames: UInt32
    private var debugUpdateCounter: UInt64 = 0
    private var debugQueueCapHits: UInt64 = 0
    private var postLoadSilenceUntil: CFTimeInterval = 0
    private var postLoadFadeStart: CFTimeInterval = 0
    private var postLoadFadeUntil: CFTimeInterval = 0
    private var postLoadSilenceLogCounter: UInt64 = 0

    public init(sampleRate: Double = 48_000.0, channels: Int = 2, volume: Float = 1.0) {
        self.sampleRate = sampleRate
        self.channels = AVAudioChannelCount(channels)
        self.engine = AVAudioEngine()
        self.playerNode = AVAudioPlayerNode()
        
        let targetFPS: Double = 60.0
        let secondsPerFrame = 1.0 / targetFPS
        maxQueuedFrames = UInt32(sampleRate * 0.35)  // Increased buffer capacity
        minStartQueuedFrames = UInt32(sampleRate * secondsPerFrame)
        hardResetQueuedFrames = UInt32(sampleRate * 0.90)
        softLatencyCapFrames = UInt32(sampleRate * 0.20)  // Increased from 0.18
        // Match actual frame sizes (803-1000 frames from resampling)
        preferredScheduleFrames = max(800, UInt32(sampleRate / 60.0))
        minPartialScheduleFrames = max(600, UInt32(sampleRate / 80.0))  // Increased from 512
        
        outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                     sampleRate: sampleRate,
                                     channels: self.channels,
                                     interleaved: true)!
        
        NSLog("[AudioEngine] Initialized: sampleRate=\(sampleRate), preferredScheduleFrames=\(preferredScheduleFrames), minPartialScheduleFrames=\(minPartialScheduleFrames)")
        
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
                self.postLoadSilenceLogCounter &+= 1
                if self.postLoadSilenceLogCounter <= 4 || (self.postLoadSilenceLogCounter % 30) == 0 {
                    NSLog("[AudioEngine] post-load silence drop frames=%u until=%.3f now=%.3f",
                          frameCount,
                          self.postLoadSilenceUntil,
                          now)
                }
                return
            }

            var workingSamples = samples
            if now < self.postLoadFadeUntil {
                workingSamples = self.applyPostLoadFade(to: samples, atTime: now, bytesPerFrame: bytesPerFrame)
            }

            // Accumulate incoming PCM and drain in bounded chunks to avoid
            // dropping whole packets when queue pressure is transient.
            self.pendingPCM.append(workingSamples)
            self.drainPendingPCM(bytesPerFrame: bytesPerFrame)
            self.debugLogQueueStateIfNeeded(bytesPerFrame: bytesPerFrame)
        }
    }

    private func drainPendingPCM(bytesPerFrame: Int) {
        guard bytesPerFrame > 0 else { return }
        while queuedFrames < maxQueuedFrames {
            let availableFrames = pendingPCM.count / bytesPerFrame
            if availableFrames == 0 { return }

            let chunkFrames: Int
            if availableFrames >= Int(preferredScheduleFrames) {
                chunkFrames = Int(preferredScheduleFrames)
            } else if !isPlaying && availableFrames >= Int(minPartialScheduleFrames) {
                chunkFrames = availableFrames
            } else if !isPlaying && queuedFrames == 0 {
                // Kickstart playback with whatever we have.
                chunkFrames = availableFrames
            } else {
                return
            }

            let chunkBytes = chunkFrames * bytesPerFrame
            let chunk = pendingPCM.prefix(chunkBytes)
            pendingPCM.removeFirst(chunkBytes)

            if let buffer = makePCMBuffer(from: Data(chunk), bytesPerFrame: bytesPerFrame) {
                playBufferOnQueue(buffer)
            } else {
                return
            }
        }
        if queuedFrames >= maxQueuedFrames {
            debugQueueCapHits &+= 1
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

    private func playBufferOnQueue(_ buffer: AVAudioPCMBuffer) {
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                NSLog("[AudioEngine] Failed to start engine: %@", error.localizedDescription)
                return
            }
        }

        if queuedFrames > hardResetQueuedFrames {
            playerNode.stop()
            playerNode.reset()
            queuedFrames = 0
            isPlaying = false
            pendingPCM.removeAll(keepingCapacity: true)
        }

        let frames = buffer.frameLength
        queuedFrames = queuedFrames &+ frames
        playerNode.scheduleBuffer(buffer, at: nil, options: []) { [weak self] in
            guard let self else { return }
            self.queue.async {
                self.queuedFrames = self.queuedFrames > frames ? self.queuedFrames - frames : 0
            }
        }

        if !isPlaying && queuedFrames >= minStartQueuedFrames {
            playerNode.play()
            isPlaying = true
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
        }
    }
    
    public func pause() {
        queue.async { [weak self] in
            self?.engine.pause()
            self?.isPlaying = false
        }
    }
    
    public func resume() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.start()
            self.playerNode.play()
            self.isPlaying = true
        }
    }
    
    public func setVolume(_ volume: Float) {
        engine.mainMixerNode.outputVolume = max(0.0, min(1.0, volume))
    }

    /// Flush queued audio and quarantine output briefly after state restore,
    /// then fade-in to avoid audible glitches from transient bad core samples.
    public func quarantineAfterStateLoad(silenceMs: Int = 220, fadeInMs: Int = 120) {
        queue.async { [weak self] in
            guard let self else { return }
            let now = CACurrentMediaTime()
            self.playerNode.stop()
            self.playerNode.reset()
            self.queuedFrames = 0
            self.pendingPCM.removeAll(keepingCapacity: true)
            self.isPlaying = false

            let silenceSeconds = max(0.0, Double(silenceMs) / 1000.0)
            let fadeSeconds = max(0.0, Double(fadeInMs) / 1000.0)
            self.postLoadSilenceUntil = now + silenceSeconds
            self.postLoadFadeStart = self.postLoadSilenceUntil
            self.postLoadFadeUntil = self.postLoadFadeStart + fadeSeconds
            self.postLoadSilenceLogCounter = 0

            NSLog("[AudioEngine] post-load quarantine silenceMs=%d fadeInMs=%d", silenceMs, fadeInMs)
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

    private func debugLogQueueStateIfNeeded(bytesPerFrame: Int) {
        guard UserDefaults.standard.bool(forKey: "dev.audio.debugAB") else { return }
        debugUpdateCounter &+= 1
        guard debugUpdateCounter % 120 == 0 else { return }
        let pendingFrames = pendingPCM.count / max(1, bytesPerFrame)
        NSLog("[AudioAB] queue updates=%llu queuedFrames=%u pendingFrames=%d maxQueued=%u capHits=%llu isPlaying=%d",
              debugUpdateCounter,
              queuedFrames,
              pendingFrames,
              maxQueuedFrames,
              debugQueueCapHits,
              isPlaying ? 1 : 0)
    }
    
    public func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            // Use a neutral playback mode for emulator audio. `.moviePlayback` can make
            // game audio feel softer/processed on some devices.
            try session.setCategory(.playback, mode: .default, options: [])
            // Prefer the core's native sample rate when possible to reduce resampling.
            try session.setPreferredSampleRate(sampleRate)
            // Use larger buffer duration to reduce crackle (was 0.008 = 8ms)
            // Increased to ~42.7ms at 48kHz = 2048 frames for better stability
            try session.setPreferredIOBufferDuration(0.0427)
            try session.setActive(true)
            NSLog("[AudioEngine] Configured session: sampleRate=\(sampleRate), actualRate=\(session.sampleRate), bufferDuration=\(session.ioBufferDuration)")
        } catch {
            NSLog("[AudioEngine] Failed to configure audio session: %@", error.localizedDescription)
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
}
