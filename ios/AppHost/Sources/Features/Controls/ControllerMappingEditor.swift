import CoreData
import SwiftUI

public struct ControllerMappingEditor: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ControllerMappingViewModel
    
    public init(platform: Platform, controllerType: String = "default") {
        _viewModel = StateObject(wrappedValue: ControllerMappingViewModel(
            platform: platform,
            controllerType: controllerType
        ))
    }
    
    public var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView("Loading mappings...")
                            Spacer()
                        }
                    }
                } else {
                    Section("Controller Info") {
                        LabeledContent("Platform", value: viewModel.platform.rawValue)
                        LabeledContent("Controller", value: viewModel.controllerType)
                    }
                    
                    Section("Button Mappings") {
                        ForEach(viewModel.availableButtons, id: \.self) { button in
                            ButtonMappingRow(
                                button: button,
                                currentMapping: viewModel.mapping(for: button),
                                availableInputs: viewModel.availableInputs
                            ) { input in
                                viewModel.updateMapping(button: button, input: input)
                            }
                        }
                    }
                    
                    Section {
                        Button("Reset to Defaults") {
                            viewModel.resetToDefaults()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Controller Mapping")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            let didSave = await viewModel.saveMappings()
                            if didSave {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
}

struct ButtonMappingRow: View {
    let button: ControllerButton
    let currentMapping: EmulatorInput?
    let availableInputs: [EmulatorInput]
    let onUpdate: (EmulatorInput?) -> Void
    
    @State private var showPicker = false
    
    var body: some View {
        Button(action: { showPicker = true }) {
            HStack {
                Text(buttonName)
                    .foregroundColor(.primary)
                Spacer()
                Text(currentMapping?.displayName ?? "Unmapped")
                    .foregroundColor(currentMapping == nil ? .secondary : .blue)
            }
        }
        .sheet(isPresented: $showPicker) {
            NavigationView {
                List {
                    Button("Unmapped") {
                        onUpdate(nil)
                        showPicker = false
                    }
                    .foregroundColor(.secondary)
                    
                    ForEach(availableInputs, id: \.self) { input in
                        Button(action: {
                            onUpdate(input)
                            showPicker = false
                        }) {
                            HStack {
                                Text(input.displayName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if currentMapping == input {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                .navigationTitle(buttonName)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showPicker = false
                        }
                    }
                }
            }
        }
    }
    
    private var buttonName: String {
        switch button {
        case .a: return "A Button"
        case .b: return "B Button"
        case .x: return "X Button"
        case .y: return "Y Button"
        case .dpadUp: return "D-Pad Up"
        case .dpadDown: return "D-Pad Down"
        case .dpadLeft: return "D-Pad Left"
        case .dpadRight: return "D-Pad Right"
        case .leftShoulder: return "Left Shoulder"
        case .rightShoulder: return "Right Shoulder"
        case .leftTrigger: return "Left Trigger"
        case .rightTrigger: return "Right Trigger"
        case .l: return "L Button"
        case .r: return "R Button"
        case .start: return "Start"
        case .select: return "Select"
        case .menu: return "Menu"
        case .leftStick: return "Left Stick"
        case .rightStick: return "Right Stick"
        case .home: return "Home"
        case .triggerLeft: return "Trigger Left"
        case .triggerRight: return "Trigger Right"
        }
    }
}

@MainActor
public class ControllerMappingViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var showError = false
    @Published var errorMessage = ""
    
    let platform: Platform
    let controllerType: String
    
    private var mappings: [ControllerButton: EmulatorInput] = [:]
    private var originalMappings: [ControllerButton: EmulatorInput] = [:]
    
    var availableButtons: [ControllerButton] {
        let preferredOrder: [ControllerButton] = [
            .a, .b, .x, .y,
            .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
            .leftShoulder, .rightShoulder, .leftTrigger, .rightTrigger,
            .leftStick, .rightStick,
            .start, .select, .menu
        ]
        let mappedButtons = Set(DefaultControllerMappings.mappings(for: platform).map(\.controllerButton))
        return preferredOrder.filter { mappedButtons.contains($0) || editableButtons.contains($0) }
    }
    
    var availableInputs: [EmulatorInput] {
        EmulatorInput.allCases(for: platform)
    }
    
    public init(platform: Platform, controllerType: String) {
        self.platform = platform
        self.controllerType = controllerType
        
        Task {
            await loadMappings()
        }
    }
    
    func mapping(for button: ControllerButton) -> EmulatorInput? {
        mappings[button]
    }
    
    func updateMapping(button: ControllerButton, input: EmulatorInput?) {
        if let input = input {
            mappings[button] = input
        } else {
            mappings.removeValue(forKey: button)
        }
    }
    
    func loadMappings() async {
        isLoading = true
        
        let context = PersistenceController.shared.container.viewContext
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ControllerMapping")
        fetchRequest.predicate = NSPredicate(
            format: "platformRaw == %@ AND controllerType == %@",
            platform.rawValue,
            controllerType
        )
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            if let mapping = results.first,
               let mappingData = mapping.value(forKey: "mappingData") as? String,
               let decoded = Self.decodeMappings(from: mappingData) {
                mappings = [:]
                for mapping in decoded {
                    mappings[mapping.controllerButton] = mapping.emulatorInput
                }
            } else {
                resetToDefaults()
            }
            originalMappings = mappings
        } catch {
            resetToDefaults()
        }
        
        isLoading = false
    }
    
    func saveMappings() async -> Bool {
        let context = PersistenceController.shared.container.viewContext
        
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "ControllerMapping")
        fetchRequest.predicate = NSPredicate(
            format: "platformRaw == %@ AND controllerType == %@",
            platform.rawValue,
            controllerType
        )
        fetchRequest.fetchLimit = 1
        
        do {
            let results = try context.fetch(fetchRequest)
            let mapping: NSManagedObject
            
            if let existing = results.first {
                mapping = existing
            } else {
                let entity = NSEntityDescription.entity(forEntityName: "ControllerMapping", in: context)!
                mapping = NSManagedObject(entity: entity, insertInto: context)
                mapping.setValue(platform.rawValue, forKey: "platformRaw")
                mapping.setValue(controllerType, forKey: "controllerType")
            }
            
            let mappingList = mappings.map { key, value in
                ButtonMapping(controllerButton: key, emulatorInput: value)
            }
            guard let encodedMappings = DefaultControllerMappings.toData(mappingList) else {
                throw NSError(
                    domain: "com.xemu.controller-mapping",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Unable to encode controller mappings"]
                )
            }
            mapping.setValue(encodedMappings, forKey: "mappingData")
            mapping.setValue(Date(), forKey: "updatedAt")
            
            try context.save()
            originalMappings = mappings
            InputBus.shared.reloadMappings(for: platform, controllerType: controllerType)
            return true
        } catch {
            errorMessage = "Failed to save mappings: \(error.localizedDescription)"
            showError = true
            return false
        }
    }
    
    func resetToDefaults() {
        let mappingsList = DefaultControllerMappings.mappings(for: platform)
        mappings = [:]
        for mapping in mappingsList {
            mappings[mapping.controllerButton] = mapping.emulatorInput
        }
    }

    private var editableButtons: Set<ControllerButton> {
        [.a, .b, .x, .y, .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
         .leftShoulder, .rightShoulder, .leftTrigger, .rightTrigger,
         .start, .select, .menu]
    }

    private static func decodeMappings(from rawValue: String) -> [ButtonMapping]? {
        if let mappings = DefaultControllerMappings.fromData(rawValue) {
            return mappings
        }

        guard
            let data = rawValue.data(using: .utf8),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return nil
        }

        return decoded.compactMap { key, value in
            guard let button = ControllerButton(rawValue: key),
                  let input = EmulatorInput(rawValue: value) else {
                return nil
            }
            return ButtonMapping(controllerButton: button, emulatorInput: input)
        }
    }
}

extension EmulatorInput {
    var displayName: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
        case .start: return "Start"
        case .select: return "Select"
        case .l: return "L"
        case .r: return "R"
        case .z: return "Z"
        case .up: return "D-Pad Up"
        case .down: return "D-Pad Down"
        case .left: return "D-Pad Left"
        case .right: return "D-Pad Right"
        case .l2: return "L2"
        case .r2: return "R2"
        case .l3: return "L3"
        case .r3: return "R3"
        case .cUp: return "C-Up"
        case .cDown: return "C-Down"
        case .cLeft: return "C-Left"
        case .cRight: return "C-Right"
        case .touch: return "Touch"
        case .microphone: return "Microphone"
        }
    }
    
    static func allCases(for platform: Platform) -> [EmulatorInput] {
        switch platform {
        case .NES:
            return [.a, .b, .start, .select, .up, .down, .left, .right]
        case .GB, .GBC:
            return [.a, .b, .start, .select, .up, .down, .left, .right]
        case .GBA:
            return [.a, .b, .l, .r, .start, .select, .up, .down, .left, .right]
        case .GENESIS:
            return [.a, .b, .x, .y, .z, .start, .up, .down, .left, .right]
        case .NDS, ._3DS:
            return [.a, .b, .x, .y, .l, .r, .start, .select, .up, .down, .left, .right]
        case .PS1, .PS2:
            return [.a, .b, .x, .y, .l, .r, .l2, .r2, .start, .select, .up, .down, .left, .right]
        }
    }
}
