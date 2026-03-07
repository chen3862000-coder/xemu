import Foundation
import Combine
import QuartzCore

@MainActor
final class EmulatorSession: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var currentFrameRate: Double = 0
    
    internal var core: EmulatorCore?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var lastFPSUpdate: CFTimeInterval = 0
    private var gameLoopTimer: Timer?
    private var renderFrameInterval: Int = 1
    private var renderFrameCounter: Int = 0
    
    private let targetFPS: Double = 60.0
    private let frameInterval: TimeInterval = 1.0 / 60.0
    
    weak var inputBus: InputBus?
    weak var renderDelegate: EmulatorRenderDelegate?
    
    init() {}
    
    func getVideoInfo() -> (width: Int, height: Int, pitch: Int)? {
        guard let core = core else { return nil }
        
        if let gbCore = core as? GBCore {
            return gbCore.getVideoInfo()
        }
        
        return nil
    }
    
    func loadCore(_ core: EmulatorCore) {
        self.core = core
    }
    
    func start() {
        guard let core = core else { return }
        
        isRunning = true
        isPaused = false
        
        _ = core.start()
        
        startGameLoop()
    }
    
    func pause() {
        guard let core = core, isRunning else { return }
        
        isPaused = true
        core.pause()
        
        stopGameLoop()
    }
    
    func resume() {
        guard let core = core, isPaused else { return }
        
        isPaused = false
        
        _ = core.resume()
        
        startGameLoop()
    }
    
    func stop() {
        guard isRunning else { return }
        
        isRunning = false
        isPaused = false
        
        core?.stop()
        
        stopGameLoop()
    }
    
    func cleanup() {
        // Debug log disabled: NSLog("[EmulatorSession] Cleanup called")
        stop()
        core?.cleanup()
        core = nil
        renderFrameCounter = 0
        renderFrameInterval = 1
        // Debug log disabled: NSLog("[EmulatorSession] Cleanup complete")
    }

    func setRenderFrameSkip(_ skip: Int) {
        renderFrameInterval = max(1, skip + 1)
        if renderFrameCounter >= renderFrameInterval {
            renderFrameCounter = 0
        }
    }
    
    private func startGameLoop() {
        stopGameLoop()
        
        lastFPSUpdate = CACurrentMediaTime()
        frameCount = 0
    }
    
    private func stopGameLoop() {
        gameLoopTimer?.invalidate()
        gameLoopTimer = nil
    }
    
    func stepOnce() {
        guard let core = core, isRunning, !isPaused else { return }
        
        // Run one frame of emulation
        _ = core.frame()
        renderFrameCounter += 1
        let shouldEmitRenderFrame = renderFrameCounter >= renderFrameInterval
        if shouldEmitRenderFrame {
            renderFrameCounter = 0
            // Use atomic getFrameBufferInfo to prevent race conditions
            if let fbInfo = core.getFrameBufferInfo() {
                let neededSize = fbInfo.pitch * fbInfo.height
                guard fbInfo.data.count >= neededSize else { return }
                renderDelegate?.emulatorDidRenderFrameBufferInfo(fbInfo)
            }
        }

        let audioSamples = core.getAudioSamples()
        renderDelegate?.emulatorDidGenerateAudio(samples: audioSamples, sampleRate: core.getAudioSampleRate())
        
        frameCount += 1
        
        let currentTime = CACurrentMediaTime()
        if currentTime - lastFPSUpdate >= 1.0 {
            currentFrameRate = Double(frameCount) / (currentTime - lastFPSUpdate)
            frameCount = 0
            lastFPSUpdate = currentTime
        }
    }
    
    private func createTestPattern(width: Int, height: Int) -> Data {
        var data = Data(count: width * height * 4)
        let bpr = width * 4
        data.withUnsafeMutableBytes { (raw: UnsafeMutableRawBufferPointer) in
            for y in 0..<height {
                for x in 0..<width {
                    let i = y * bpr + x * 4
                    raw[i+0] = UInt8(x * 255 / width)     // R
                    raw[i+1] = UInt8(y * 255 / height)    // G
                    raw[i+2] = 0                           // B
                    raw[i+3] = 255                         // A
                }
            }
        }
        return data
    }
    
    private func gameLoopTick() {
        guard let core = core, isRunning, !isPaused else { return }
        
        let currentTime = CACurrentMediaTime()
        
        _ = core.frame()
        renderFrameCounter += 1
        let shouldEmitRenderFrame = renderFrameCounter >= renderFrameInterval
        if shouldEmitRenderFrame {
            renderFrameCounter = 0
            // Use getFrameBufferInfo to atomically get data + dimensions together
            // This prevents race condition where dimensions change between separate calls
            if let fbInfo = core.getFrameBufferInfo() {
                // Validate before passing to renderer
                let neededSize = fbInfo.pitch * fbInfo.height
                guard fbInfo.data.count >= neededSize else {
                    // Buffer too small - skip frame
                    return
                }
                renderDelegate?.emulatorDidRenderFrameBufferInfo(fbInfo)
            }
        }
        
        let audioSamples = core.getAudioSamples()
        renderDelegate?.emulatorDidGenerateAudio(samples: audioSamples, sampleRate: core.getAudioSampleRate())
        
        frameCount += 1
        
        if currentTime - lastFPSUpdate >= 1.0 {
            currentFrameRate = Double(frameCount) / (currentTime - lastFPSUpdate)
            frameCount = 0
            lastFPSUpdate = currentTime
        }
    }
    
    func saveState(to slot: Int) throws -> Data {
        guard let core = core else {
            throw EmulatorSessionError.noCoreLoaded
        }
        
        guard let data = core.saveState() else {
            throw EmulatorSessionError.saveStateFailed
        }
        
        return data
    }
    
    func loadState(from data: Data) throws {
        guard let core = core else {
            throw EmulatorSessionError.noCoreLoaded
        }
        
        let success = core.loadState(data)
        if !success {
            throw EmulatorSessionError.loadStateFailed
        }
    }
    
    func reset() {
        core?.stop()
        core?.reset()
    }
}

enum EmulatorSessionError: Error {
    case noCoreLoaded
    case saveStateFailed
    case loadStateFailed
}

@MainActor
protocol EmulatorRenderDelegate: AnyObject {
    func emulatorDidRenderFrameBufferInfo(_ frameBufferInfo: FrameBufferInfo)
    func emulatorDidGenerateAudio(samples: Data?, sampleRate: Int)
}
