import Foundation
import Combine
import QuartzCore

@MainActor
final class EmulatorSession: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isPaused = false
    @Published private(set) var currentFrameRate: Double = 0
    
    private var core: EmulatorCore?
    private var lastFrameTime: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var lastFPSUpdate: CFTimeInterval = 0
    private var gameLoopTimer: Timer?
    
    private let targetFPS: Double = 60.0
    private let frameInterval: TimeInterval = 1.0 / 60.0
    
    weak var inputBus: InputBus?
    weak var renderDelegate: EmulatorRenderDelegate?
    
    init() {}
    
    func cleanup() {
        stop()
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
    
    private func startGameLoop() {
        stopGameLoop()
        
        lastFPSUpdate = CACurrentMediaTime()
        frameCount = 0
        
        gameLoopTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.gameLoopTick()
            }
        }
        
        RunLoop.current.add(gameLoopTimer!, forMode: .common)
    }
    
    private func stopGameLoop() {
        gameLoopTimer?.invalidate()
        gameLoopTimer = nil
    }
    
    private func gameLoopTick() {
        guard let core = core, isRunning, !isPaused else { return }
        
        let currentTime = CACurrentMediaTime()
        
        _ = core.frame()
        
        frameCount += 1
        
        if currentTime - lastFPSUpdate >= 1.0 {
            currentFrameRate = Double(frameCount) / (currentTime - lastFPSUpdate)
            frameCount = 0
            lastFPSUpdate = currentTime
        }
    }
    
    func saveState(to slot: Int) async throws -> Data {
        guard let core = core else {
            throw EmulatorSessionError.noCoreLoaded
        }
        
        guard let data = try core.saveState() else {
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

protocol EmulatorRenderDelegate: AnyObject {
    func emulatorDidRender()
}
