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
