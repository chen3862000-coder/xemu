import Testing
import AVFoundation
@testable import Xemu

@Suite("AudioEngine Tests")
@MainActor
struct AudioEngineTests {
    
    @Test("AudioEngine initializes with default parameters")
    func testDefaultInitialization() async throws {
        let audioEngine = AudioEngine()
        #expect(!audioEngine.isPlayingAudio)
    }
    
    @Test("AudioEngine initializes with custom parameters")
    func testCustomInitialization() async throws {
        let audioEngine = AudioEngine(sampleRate: 48000, channels: 1)
        #expect(!audioEngine.isPlayingAudio)
    }
    
    @Test("AudioEngine can update audio buffer")
    func testUpdateAudioBuffer() async throws {
        let audioEngine = AudioEngine()
        
        // Create valid stereo samples (2 bytes per sample * 2 channels = 4 bytes per frame)
        let samples = Data(repeating: 100, count: 4096)
        audioEngine.updateAudioBuffer(samples)
    }
    
    @Test("AudioEngine can set volume")
    func testSetVolume() async throws {
        let audioEngine = AudioEngine()
        
        audioEngine.setVolume(0.5)
        audioEngine.setVolume(1.0)
    }
    
    @Test("AudioEngine volume clamping")
    func testVolumeClamping() async throws {
        let audioEngine = AudioEngine()
        
        audioEngine.setVolume(2.0)  // Should clamp to 1.0
        audioEngine.setVolume(-0.5) // Should clamp to 0.0
    }
    
    @Test("AudioEngine handles empty buffer")
    func testEmptyBuffer() async throws {
        let audioEngine = AudioEngine()
        
        // Should not crash with empty buffer
        audioEngine.updateAudioBuffer(Data())
    }
    
    @Test("AudioEngine handles mono audio")
    func testMonoAudio() async throws {
        let audioEngine = AudioEngine(channels: 1)
        
        // Create valid mono samples (2 bytes per sample * 1 channel = 2 bytes per frame)
        let samples = Data(repeating: 100, count: 2048)
        audioEngine.updateAudioBuffer(samples)
    }
    
    @Test("AudioEngine stop without start")
    func testStopWithoutStart() async throws {
        let audioEngine = AudioEngine()
        
        // Should not crash when stopping without starting
        audioEngine.stop()
        #expect(!audioEngine.isPlayingAudio)
    }
    
    @Test("AudioEngine pause without start")
    func testPauseWithoutStart() async throws {
        let audioEngine = AudioEngine()
        
        // Should not crash when pausing without starting
        audioEngine.pause()
        #expect(!audioEngine.isPlayingAudio)
    }

    @Test("AudioEngine resume without queued audio stays idle")
    func testResumeWithoutQueuedAudioDoesNotForcePlayback() async throws {
        let audioEngine = AudioEngine()

        audioEngine.resume()
        try? await Task.sleep(for: .milliseconds(50))

        #expect(!audioEngine.isPlayingAudio)
    }

    @Test("AudioEngine preserves normal PCM chunks")
    func testSanitizerPreservesNormalChunks() async throws {
        let audioEngine = AudioEngine(sampleRate: 48_000)
        let samples = makePCMChunk([
            0, 512, -640, 960,
            -1024, 2048, -1536, 1024,
            256, -384, 512, -640,
            768, -896, 1024, -1152
        ], repeating: 20)

        let sanitized = audioEngine.sanitizeCorruptedAudioChunk(samples)

        #expect(sanitized.samples == samples)
        #expect(!sanitized.wasSilenced)
    }

    @Test("AudioEngine silences clearly corrupted chunks")
    func testSanitizerSilencesCorruptedChunks() async throws {
        let audioEngine = AudioEngine(sampleRate: 48_000)
        let samples = makePCMChunk([Int16.max, Int16.min, Int16.max, Int16.min], repeating: 80)

        let sanitized = audioEngine.sanitizeCorruptedAudioChunk(samples)

        #expect(sanitized.samples == Data(count: samples.count))
        #expect(sanitized.wasSilenced)
    }

    @Test("Low-latency sanitizer preserves square-wave handheld audio")
    func testLowLatencySanitizerPreservesSquareWaveAudio() async throws {
        let audioEngine = AudioEngine(sampleRate: 48_000, latencyProfile: .lowLatency)
        let samples = makePCMChunk([12_000, -12_000, 12_000, -12_000], repeating: 96)

        let sanitized = audioEngine.sanitizeCorruptedAudioChunk(samples)

        #expect(sanitized.samples == samples)
        #expect(!sanitized.wasSilenced)
    }

    @Test("Low-latency tuning starts sooner and keeps a smaller queue")
    func testLowLatencyTuningUsesSmallerQueueThanBalanced() async throws {
        let lowLatency = AudioEngine.tuning(sampleRate: 44_100, latencyProfile: .lowLatency)
        let balanced = AudioEngine.tuning(sampleRate: 44_100, latencyProfile: .balanced)

        #expect(lowLatency.minStartQueuedFrames < balanced.minStartQueuedFrames)
        #expect(lowLatency.softLatencyCapFrames < balanced.softLatencyCapFrames)
        #expect(lowLatency.preferredIOBufferDuration < balanced.preferredIOBufferDuration)
    }

    @Test("Streaming tuning gives NDS more startup cushion than low latency")
    func testStreamingTuningBuffersMoreThanLowLatency() async throws {
        let lowLatency = AudioEngine.tuning(sampleRate: 32_768, latencyProfile: .lowLatency)
        let streaming = AudioEngine.tuning(sampleRate: 32_768, latencyProfile: .streaming)

        #expect(streaming.minStartQueuedFrames > lowLatency.minStartQueuedFrames)
        #expect(streaming.minPartialScheduleFrames > lowLatency.minPartialScheduleFrames)
        #expect(streaming.softLatencyCapFrames > lowLatency.softLatencyCapFrames)
        #expect(streaming.preferredScheduleFrames < streaming.minStartQueuedFrames)
        #expect(streaming.preferredIOBufferDuration > lowLatency.preferredIOBufferDuration)
        #expect(streaming.maxQueuedFrames > streaming.softLatencyCapFrames)
    }

    @Test("Bluetooth A2DP routes get a larger playback cushion than speaker routes")
    func testBluetoothTuningIncreasesQueueDepth() async throws {
        let base = AudioEngine.tuning(sampleRate: 44_100, latencyProfile: .balanced)
        let bluetooth = AudioEngine.tuned(base, for: .bluetoothA2DP, sampleRate: 44_100)

        #expect(bluetooth.minStartQueuedFrames > base.minStartQueuedFrames)
        #expect(bluetooth.preferredScheduleFrames > base.preferredScheduleFrames)
        #expect(bluetooth.minStartQueuedFrames >= 8_192)
        #expect(bluetooth.preferredScheduleFrames >= 2_048)
        #expect(bluetooth.preferredIOBufferDuration >= 0.04)
    }

    @Test("AirPlay and external routes get explicit high-latency tuning")
    func testExtendedRouteTuningHierarchy() async throws {
        let base = AudioEngine.tuning(sampleRate: 48_000, latencyProfile: .balanced)
        let bluetooth = AudioEngine.tuned(base, for: .bluetoothA2DP, sampleRate: 48_000)
        let airPlay = AudioEngine.tuned(base, for: .airPlay, sampleRate: 48_000)
        let external = AudioEngine.tuned(base, for: .externalHighLatency, sampleRate: 48_000)
        let bluetoothVoice = AudioEngine.tuned(base, for: .bluetoothVoice, sampleRate: 48_000)

        #expect(external.minStartQueuedFrames > base.minStartQueuedFrames)
        #expect(external.preferredScheduleFrames > base.preferredScheduleFrames)
        #expect(bluetoothVoice.minStartQueuedFrames >= bluetooth.minStartQueuedFrames)
        #expect(airPlay.minStartQueuedFrames >= bluetooth.minStartQueuedFrames)
        #expect(airPlay.maxQueuedFrames >= bluetooth.maxQueuedFrames)
        #expect(airPlay.preferredIOBufferDuration >= bluetooth.preferredIOBufferDuration)
    }

    #if os(iOS)
    @Test("Route detection recognizes audio output classes")
    func testRouteKindDetectsOutputClasses() async throws {
        #expect(AudioEngine.routeKind(for: [.builtInSpeaker]) == .speakerOrWired)
        #expect(AudioEngine.routeKind(for: [.bluetoothA2DP]) == .bluetoothA2DP)
        #expect(AudioEngine.routeKind(for: [.bluetoothHFP]) == .bluetoothVoice)
        #expect(AudioEngine.routeKind(for: [.bluetoothLE]) == .bluetoothVoice)
        #expect(AudioEngine.routeKind(for: [.airPlay]) == .airPlay)
        #expect(AudioEngine.routeKind(for: [.usbAudio]) == .externalHighLatency)
        #expect(AudioEngine.routeKind(for: [.carAudio]) == .externalHighLatency)
    }

    @Test("Category-only session churn does not trigger a route rebuild")
    func testCategoryChangeDoesNotTriggerRouteReconfigure() async throws {
        #expect(!AudioEngine.shouldReconfigure(for: .categoryChange))
        #expect(AudioEngine.shouldReconfigure(for: .newDeviceAvailable))
    }
    #endif

    @Test("Streaming queue bridges brief underruns before hard stop")
    func testStreamingQueueBridgesBriefUnderruns() async throws {
        #expect(
            AudioEngine.shouldBridgeUnderrun(
                bridgeUnderrunsEnabled: true,
                isPlaying: true,
                queuedFrames: 0,
                pendingFrames: 0,
                consecutiveBridgeBuffers: 0,
                maxConsecutiveBridgeBuffers: 4
            )
        )

        #expect(
            !AudioEngine.shouldBridgeUnderrun(
                bridgeUnderrunsEnabled: true,
                isPlaying: true,
                queuedFrames: 0,
                pendingFrames: 0,
                consecutiveBridgeBuffers: 4,
                maxConsecutiveBridgeBuffers: 4
            )
        )

        #expect(
            !AudioEngine.shouldBridgeUnderrun(
                bridgeUnderrunsEnabled: true,
                isPlaying: true,
                queuedFrames: 547,
                pendingFrames: 0,
                consecutiveBridgeBuffers: 0,
                maxConsecutiveBridgeBuffers: 4
            )
        )
    }

    @Test("Bluetooth routes can use underrun bridging even outside streaming mode")
    func testBluetoothUnderrunBridgeUsesBridgeFlag() async throws {
        #expect(
            AudioEngine.shouldBridgeUnderrun(
                bridgeUnderrunsEnabled: true,
                isPlaying: true,
                queuedFrames: 0,
                pendingFrames: 0,
                consecutiveBridgeBuffers: 0,
                maxConsecutiveBridgeBuffers: 6
            )
        )

        #expect(
            !AudioEngine.shouldBridgeUnderrun(
                bridgeUnderrunsEnabled: false,
                isPlaying: true,
                queuedFrames: 0,
                pendingFrames: 0,
                consecutiveBridgeBuffers: 0,
                maxConsecutiveBridgeBuffers: 6
            )
        )
    }
    
    #if os(iOS)
    @Test("AudioEngine can configure audio session")
    func testConfigureAudioSession() async throws {
        let audioEngine = AudioEngine()
        audioEngine.configureAudioSession()
    }
    
    @Test("AudioEngine can deactivate audio session")
    func testDeactivateAudioSession() async throws {
        let audioEngine = AudioEngine()
        audioEngine.configureAudioSession()
        audioEngine.deactivateAudioSession()
    }
    #endif
}

private func makePCMChunk(_ seed: [Int16], repeating count: Int) -> Data {
    var samples: [Int16] = []
    samples.reserveCapacity(seed.count * count)
    for _ in 0..<count {
        samples.append(contentsOf: seed)
    }

    return samples.withUnsafeBufferPointer { buffer in
        guard let baseAddress = buffer.baseAddress else { return Data() }
        return Data(bytes: baseAddress, count: buffer.count * MemoryLayout<Int16>.size)
    }
}
