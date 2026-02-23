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
    private let preferredScheduleFrames: UInt32
    private let minPartialScheduleFrames: UInt32
    private let softLatencyCapFrames: UInt32
    
    public init(sampleRate: Double = 44100,
                channels: AVAudioChannelCount = 2) {
        self.sampleRate = sampleRate
        self.channels = channels
        
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: sampleRate,
                                         channels: channels,
                                         interleaved: true) else {
            fatalError("Failed to create AVAudioFormat")
        }

        outputFormat = format
        maxQueuedFrames = UInt32(sampleRate * 0.22)
        minStartQueuedFrames = UInt32(sampleRate * 0.035)
        hardResetQueuedFrames = UInt32(sampleRate * 0.55)
        preferredScheduleFrames = max(768, UInt32(sampleRate / 30.0))
        minPartialScheduleFrames = 256
        softLatencyCapFrames = UInt32(sampleRate * 0.14)
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()

        setupEngine()
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

            self.pendingPCM.append(samples)

            let chunkBytes = Int(self.preferredScheduleFrames) * bytesPerFrame
            while self.pendingPCM.count >= chunkBytes {
                let chunk = self.pendingPCM.prefix(chunkBytes)
                if let buffer = self.makePCMBuffer(from: chunk, bytesPerFrame: bytesPerFrame) {
                    self.playBufferOnQueue(buffer)
                }
                self.pendingPCM.removeFirst(chunkBytes)
            }

            // If audio is starving, schedule a partial chunk, but avoid very tiny buffers
            // because they increase scheduling jitter and can produce audible crackle.
            let minPartialBytes = Int(self.minPartialScheduleFrames) * bytesPerFrame
            let shouldDrainPartial =
                self.pendingPCM.count >= minPartialBytes &&
                (self.queuedFrames == 0 || (!self.isPlaying && self.queuedFrames < self.minStartQueuedFrames))

            if shouldDrainPartial,
               let buffer = self.makePCMBuffer(from: self.pendingPCM, bytesPerFrame: bytesPerFrame) {
                self.pendingPCM.removeAll(keepingCapacity: true)
                self.playBufferOnQueue(buffer)
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

        if queuedFrames > maxQueuedFrames {
            return
        }

        // Keep latency bounded: if playback is already comfortably ahead, drop new chunks
        // rather than extending audible delay.
        if isPlaying && queuedFrames > softLatencyCapFrames {
            return
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
    
    public func configureAudioSession() {
        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            // Use a neutral playback mode for emulator audio. `.moviePlayback` can make
            // game audio feel softer/processed on some devices.
            try session.setCategory(.playback, mode: .default, options: [])
            // Prefer the core's native sample rate when possible to reduce resampling.
            try session.setPreferredSampleRate(sampleRate)
            try session.setPreferredIOBufferDuration(0.008)
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
}
