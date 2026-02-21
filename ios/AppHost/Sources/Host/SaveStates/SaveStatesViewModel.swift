import Combine
import CoreData
import Foundation

@MainActor
final class SaveStatesViewModel: ObservableObject {
    private let rom: ROMLibraryEntry
    private let saveStateStorage: SaveStateStorage
    private var cancellables = Set<AnyCancellable>()
    
    @Published var saveStates: [SaveState] = []
    @Published var showingDeleteConfirmation = false
    @Published var selectedSaveState: SaveState?
    @Published var isCapturing = false
    @Published var showAllSlots = false
    
    init(rom: ROMLibraryEntry, saveStateStorage: SaveStateStorage = .shared) {
        self.rom = rom
        self.saveStateStorage = saveStateStorage
        loadSaveStates()
    }
    
    func loadSaveStates() {
        Task {
            do {
                let states = try await saveStateStorage.list(for: rom.checksum ?? "")
                saveStates = states.sorted { $0.slotIndex < $1.slotIndex }
            } catch {
                print("Failed to load save states: \(error)")
            }
        }
    }
    
    func captureSaveState() {
        guard !isCapturing else { return }
        
        isCapturing = true
        Task {
            do {
                try await saveStateStorage.capture(for: rom, slot: nextAvailableSlot() ?? 0)
                loadSaveStates()
            } catch {
                print("Failed to capture save state: \(error)")
            }
            isCapturing = false
        }
    }
    
    func load(saveState: SaveState) {
        Task {
            do {
                try await saveStateStorage.load(saveState: saveState)
                NotificationCenter.default.post(name: .saveStateLoaded, object: saveState)
            } catch {
                print("Failed to load save state: \(error)")
            }
        }
    }
    
    func loadQuickSave() {
        guard let slot = quickSaveSlot else { return }
        
        let quickSave = saveStates.first { $0.slotIndex == slot }
        if let quickSave {
            load(saveState: quickSave)
        }
    }
    
    func showDeleteConfirmation(for saveState: SaveState) {
        selectedSaveState = saveState
        showingDeleteConfirmation = true
    }
    
    func deleteSelectedSaveState() {
        guard let saveState = selectedSaveState else { return }
        
        Task {
            do {
                try await saveStateStorage.delete(saveState: saveState)
                loadSaveStates()
            } catch {
                print("Failed to delete save state: \(error)")
            }
        }
    }
    
    var quickSaveSlot: Int? {
        saveStates.firstIndex { $0.slotIndex == 0 }.map { _ in 0 }
    }
    
    func nextAvailableSlot() -> Int? {
        let occupiedSlots = Set(saveStates.map { Int($0.slotIndex) })
        for slot in 0...9 {
            if !occupiedSlots.contains(slot) {
                return slot
            }
        }
        return nil
    }
}

extension Notification.Name {
    static let saveStateLoaded = Notification.Name("SaveStateLoaded")
}
