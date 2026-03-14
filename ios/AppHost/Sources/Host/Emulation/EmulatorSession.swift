import Foundation
import Combine
import QuartzCore

@MainActor
final class EmulatorSession: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var currentFrameRate: Double = 0
    
    internal var core: EmulatorCore?
    private var frameCount: Int = 0
    private var lastFPSUpdate: CFTimeInterval = 0
    private var renderFrameInterval: Int = 1
    private var renderFrameCounter: Int = 0
    
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
                if fbInfo.data.count >= neededSize {
                    renderDelegate?.emulatorDidRenderFrameBufferInfo(fbInfo)
                }
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
