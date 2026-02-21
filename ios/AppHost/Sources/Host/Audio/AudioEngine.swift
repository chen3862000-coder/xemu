import Foundation
import AVFoundation

public final class AudioEngine {
#if targetEnvironment(simulator)
    private let simulatorAudioEnabled = false
#else
    private let simulatorAudioEnabled = true
#endif
    
    private let engine: AVAudioEngine
    private let playerNode: AVAudioPlayerNode
    private let queue = DispatchQueue(label: "com.xemu.audio", qos: .userInteractive)
    
    private var isPlaying = false
    private let sampleRate: Double
    private let channels: AVAudioChannelCount
    
    public init(sampleRate: Double = 44100,
                channels: AVAudioChannelCount = 2) {
        self.sampleRate = sampleRate
        self.channels = channels
        
        engine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        
        setupEngine()
    }
    
    private func setupEngine() {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: sampleRate,
                                         channels: channels,
                                         interleaved: true) else {
            return
        }
        
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
    }
    
    public var isEngineRunning: Bool {
        return engine.isRunning
    }
    
    public func start() throws {
        guard !engine.isRunning else { return }
        try engine.start()
    }
    
    public func updateAudioBuffer(_ samples: Data) {
        guard simulatorAudioEnabled else { return }

        let bytesPerFrame = 2 * Int(channels)
        guard bytesPerFrame > 0 else { return }
        
        let frameCount = UInt32(samples.count / bytesPerFrame)
        guard frameCount > 0 else { return }
        
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                    sampleRate: sampleRate,
                                    channels: channels,
                                    interleaved: true)
        guard let validFormat = format else { return }
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: validFormat, frameCapacity: frameCount) else {
            return
        }
        buffer.frameLength = frameCount
        
        let bytesToCopy = Int(frameCount) * bytesPerFrame
        samples.withUnsafeBytes { rawBufferPointer in
            if let baseAddress = rawBufferPointer.baseAddress,
               let int16Buffer = buffer.int16ChannelData?[0] {
                memcpy(int16Buffer, baseAddress, min(bytesToCopy, samples.count))
            }
        }
        
        playBuffer(buffer)
    }
    
    private func playBuffer(_ buffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.isPlaying {
                self.playerNode.play()
                self.isPlaying = true
            }
            
            self.playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
    }
    
    public func stop() {
        queue.async { [weak self] in
            self?.playerNode.stop()
            self?.isPlaying = false
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
        guard simulatorAudioEnabled else { return }

        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
        }
        #endif
    }
    
    public func deactivateAudioSession() {
        guard simulatorAudioEnabled else { return }

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
