import Foundation
#if canImport(XemuCores)
import XemuCores
#endif

public final class NDSCore: EmulatorCore, @unchecked Sendable {
    public var platform: Platform { .NDS }

    private var coreWrapper: NDSCoreWrapper?
    private var isRunning = false
    private var isPaused = false
    private var loadedROMData: Data?
    private var loadedROMPath: String?
    private var pendingBatterySaveData: Data?
    private var lastAudioSampleRate: Int = 32_728
    private var inputState: [Int: Float] = [:]

    public init() {}

    public func initialize() -> Bool {
        do {
            XemuCores.shared.initialize()
            coreWrapper = XemuCores.shared.createCore(for: .nintendoDS) as? NDSCoreWrapper
            try coreWrapper?.initialize()
            coreWrapper?.setScreenLayoutStacked()
            return true
        } catch {
            return false
        }
    }

    public func loadROM(romPath: String) -> Bool {
        guard FileManager.default.fileExists(atPath: romPath) else {
            return false
        }

        do {
            let romData = try Data(contentsOf: URL(fileURLWithPath: romPath))
            loadedROMData = romData
            loadedROMPath = romPath
            if let pending = pendingBatterySaveData {
                _ = writeBatterySaveSidecar(pending)
                pendingBatterySaveData = nil
            }

            _ = try coreWrapper?.loadROM(data: romData, filePath: romPath)
            isRunning = true
            isPaused = false
            return true
        } catch {
            print("[NDSCore] loadROM failed for \(romPath): \(error)")
            return false
        }
    }

    public func start() {
        isRunning = true
        isPaused = false
    }

    public func pause() {
        isPaused = true
    }

    public func resume() {
        isPaused = false
    }

    public func frame() -> Bool {
        guard isRunning && !isPaused else { return false }

        do {
            try coreWrapper?.step()
            return true
        } catch {
            return false
        }
    }

    public func stop() {
        isRunning = false
    }

    public func cleanup() {
        coreWrapper?.shutdown()
        coreWrapper = nil
        loadedROMData = nil
        loadedROMPath = nil
        pendingBatterySaveData = nil
        isRunning = false
        isPaused = false
        inputState = [:]
    }

    public func getFrameBuffer() -> Data? {
        guard let frame = coreWrapper?.getVideoFrameCopy() else { return nil }
        return frame.data
    }

    public func getFrameBufferInfo() -> FrameBufferInfo? {
        guard let frame = coreWrapper?.getVideoFrameCopy() else { return nil }
        return FrameBufferInfo(data: frame.data, width: frame.width, height: frame.height, pitch: frame.pitch)
    }

    public func getAudioSamples() -> Data? {
        guard let info = coreWrapper?.getAudioSamples(),
              info.sampleCount > 0,
              let samples = info.samples else {
            return nil
        }
        if info.sampleRate > 0 {
            lastAudioSampleRate = info.sampleRate
        }
        let size = info.sampleCount * MemoryLayout<Int16>.size
        guard size > 0 else { return nil }
        return Data(bytes: samples, count: size)
    }

    public func getAudioSampleRate() -> Int {
        max(8_000, lastAudioSampleRate)
    }

    public func saveState() -> Data? {
        do {
            return try coreWrapper?.getSaveStateData()
        } catch {
            return nil
        }
    }

    public func loadState(_ state: Data) -> Bool {
        do {
            try coreWrapper?.loadSaveStateData(state)
            return true
        } catch {
            return false
        }
    }

    public func exportBatterySave() -> Data? {
        guard let url = nativeSaveSidecarURL(),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    public func importBatterySave(_ data: Data) -> Bool {
        guard !data.isEmpty else {
            return false
        }
        guard nativeSaveSidecarURL() != nil else {
            pendingBatterySaveData = data
            return true
        }
        return writeBatterySaveSidecar(data)
    }

    public func setInput(_ inputType: Int, value: Float) {
        inputState[inputType] = value
        let pressed = value > 0.5

        // NDSCoreWrapper already understands the canonical inputType IDs used by
        // GamePlayViewModel/InputBus (A/B/X/Y/L/R/Select/Start/D-pad...).
        // Keep this mapping aligned to those IDs; remapping D-pad to Start/Select
        // caused touch controls to trigger the wrong actions.
        let buttonMap: [Int: Int] = [
            0: 0,   // A
            1: 1,   // B
            2: 2,   // X
            3: 3,   // Y
            4: 4,   // L
            5: 5,   // R
            6: 6,   // Select
            7: 7,   // Start
            9: 4,   // L2 -> L
            10: 5,  // R2 -> R
            11: 11, // D-pad Up
            12: 12, // D-pad Down
            13: 13, // D-pad Left
            14: 14  // D-pad Right
        ]

        guard let mappedButton = buttonMap[inputType] else { return }
        coreWrapper?.setInput(button: mappedButton, pressed: pressed)
    }

    public func reset() {
        do {
            try coreWrapper?.initialize()
            coreWrapper?.setScreenLayoutStacked()
            if let romData = loadedROMData {
                _ = try? coreWrapper?.loadROM(data: romData, filePath: loadedROMPath)
            }
            isRunning = true
            isPaused = false
            inputState = [:]
        } catch {
        }
    }

    public func setStylus(x: Int, y: Int, pressed: Bool) {
        coreWrapper?.setTouch(x: x, y: y, pressed: pressed)
    }

    public func clearStylus() {
        coreWrapper?.setTouch(x: 0, y: 0, pressed: false)
    }

    @discardableResult
    public func setScreenLayout(_ layout: NDSScreenLayout) -> Bool {
        coreWrapper?.setScreenLayout(layout) ?? false
    }

    public func getScreenLayout() -> NDSScreenLayout {
        coreWrapper?.getScreenLayout() ?? .stacked
    }

    private func nativeSaveSidecarURL() -> URL? {
        guard let loadedROMPath else { return nil }
        let romURL = URL(fileURLWithPath: loadedROMPath)
        return romURL.deletingPathExtension().appendingPathExtension("sav")
    }

    private func writeBatterySaveSidecar(_ data: Data) -> Bool {
        guard let url = nativeSaveSidecarURL() else { return false }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            NSLog("[NDSCore] Failed to write save sidecar path=%@ error=%@", url.path, error.localizedDescription)
            return false
        }
    }
}
