import SwiftUI
import GameController

@MainActor
final class ControllerOverlayViewModel: ObservableObject {
    @Published var isOverlayVisible = false
    @Published var selectedProfile: ControllerProfile?
    @Published var availableProfiles: [ControllerProfile] = []
    @Published var currentLayout: [ControllerButton: LayoutPosition] = [:]
    @Published var customButtonMappings: [ControllerButton: ControllerButton] = [:]

    private let profileStore: ControllerProfileStore

    init(profileStore: ControllerProfileStore? = nil) {
        self.profileStore = profileStore ?? .shared
        loadProfiles()
    }

    func loadProfiles() {
        availableProfiles = profileStore.loadProfiles()
        selectedProfile = availableProfiles.first
    }

    func selectProfile(_ profile: ControllerProfile) {
        selectedProfile = profile
        applyProfile(profile)
    }

    func saveCurrentMapping(as name: String) {
        guard !customButtonMappings.isEmpty else { return }

        let profile = ControllerProfile(
            id: UUID(),
            name: name,
            platform: selectedProfile?.platform ?? .NES,
            mappings: customButtonMappings,
            layout: currentLayout
        )

        profileStore.saveProfile(profile)
        availableProfiles.append(profile)
        selectedProfile = profile
    }

    func resetToDefault() {
        guard let profile = selectedProfile else { return }
        applyProfile(profile)
        customButtonMappings.removeAll()
    }

    func remap(from physical: ControllerButton, to virtual: ControllerButton) {
        customButtonMappings[physical] = virtual
    }

    private func applyProfile(_ profile: ControllerProfile) {
        currentLayout = profile.layout
        customButtonMappings = profile.mappings
    }
}

struct ControllerOverlayView: View {
    @StateObject private var viewModel = ControllerOverlayViewModel()
    @Environment(\.dismiss) private var dismiss
    let onConfigUpdated: (() -> Void)?

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.8)
                    .ignoresSafeArea()

                VStack(spacing: 20) {
                    headerSection
                    profileSection
                    layoutSection
                    buttonMappingSection
                    saveResetSection
                }
                .padding()
            }
            .navigationTitle("Controller Config")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.resetToDefault()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onConfigUpdated?()
                        dismiss()
                    }
                }
            }
        }
    }

    private var headerSection: some View {
        Text("Customize your controller layout")
            .font(.headline)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Profiles")
                .font(.subheadline)
                .foregroundColor(.gray)

            Picker("Profile", selection: $viewModel.selectedProfile) {
                ForEach(viewModel.availableProfiles) { profile in
                    Text(profile.name).tag(profile as ControllerProfile?)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }

    private var layoutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Layout")
                .font(.subheadline)
                .foregroundColor(.gray)

            HStack {
                ControllerButtonPreview(button: .dpadUp, position: viewModel.currentLayout[.dpadUp])
                ControllerButtonPreview(button: .dpadDown, position: viewModel.currentLayout[.dpadDown])
                ControllerButtonPreview(button: .dpadLeft, position: viewModel.currentLayout[.dpadLeft])
                ControllerButtonPreview(button: .dpadRight, position: viewModel.currentLayout[.dpadRight])
            }

            HStack {
                ControllerButtonPreview(button: .a, position: viewModel.currentLayout[.a])
                ControllerButtonPreview(button: .b, position: viewModel.currentLayout[.b])
                ControllerButtonPreview(button: .x, position: viewModel.currentLayout[.x])
                ControllerButtonPreview(button: .y, position: viewModel.currentLayout[.y])
            }

            HStack {
                ControllerButtonPreview(button: .l, position: viewModel.currentLayout[.l])
                ControllerButtonPreview(button: .r, position: viewModel.currentLayout[.r])
                ControllerButtonPreview(button: .start, position: viewModel.currentLayout[.start])
                ControllerButtonPreview(button: .select, position: viewModel.currentLayout[.select])
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }

    private var buttonMappingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Button Remapping")
                .font(.subheadline)
                .foregroundColor(.gray)

            ForEach([ControllerButton.a, .b, .x, .y], id: \.self) { button in
                HStack {
                    Text(buttonName(for: button))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Picker("Map to", selection: Binding(
                        get: { viewModel.customButtonMappings[button] },
                        set: { viewModel.customButtonMappings[button] = $0 }
                    )) {
                        Text("None").tag(nil as ControllerButton?)
                        ForEach([ControllerButton.a, .b, .x, .y, .start, .select], id: \.self) { target in
                            Text(buttonName(for: target)).tag(target as ControllerButton?)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(10)
    }

    private var saveResetSection: some View {
        HStack(spacing: 20) {
            Button("Reset") {
                viewModel.resetToDefault()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)

            Button("Save as New") {
                viewModel.saveCurrentMapping(as: "Custom")
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
    }

    private func buttonName(for button: ControllerButton) -> String {
        switch button {
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
        case .l: return "L"
        case .r: return "R"
        case .dpadUp: return "D-Pad Up"
        case .dpadDown: return "D-Pad Down"
        case .dpadLeft: return "D-Pad Left"
        case .dpadRight: return "D-Pad Right"
        case .leftShoulder: return "Left Shoulder"
        case .rightShoulder: return "Right Shoulder"
        case .leftTrigger: return "Left Trigger"
        case .rightTrigger: return "Right Trigger"
        case .start: return "Start"
        case .select: return "Select"
        case .menu: return "Menu"
        case .triggerLeft: return "L Trigger"
        case .triggerRight: return "R Trigger"
        case .leftStick: return "Left Stick"
        case .rightStick: return "Right Stick"
        case .home: return "Home"
        }
    }
}

struct ControllerButtonPreview: View {
    let button: ControllerButton
    let position: LayoutPosition?

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.3))
                .frame(width: 40, height: 40)

            Text(buttonName(for: button))
                .font(.caption)
                .foregroundColor(.white)
        }
    }

    private func buttonName(for button: ControllerButton) -> String {
        switch button {
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
        case .l: return "L"
        case .r: return "R"
        case .dpadUp: return "↑"
        case .dpadDown: return "↓"
        case .dpadLeft: return "←"
        case .dpadRight: return "→"
        case .leftShoulder: return "LS"
        case .rightShoulder: return "RS"
        case .leftTrigger: return "LT"
        case .rightTrigger: return "RT"
        case .start: return "ST"
        case .select: return "SL"
        case .menu: return "M"
        case .triggerLeft: return "LT"
        case .triggerRight: return "RT"
        case .leftStick: return "LK"
        case .rightStick: return "RK"
        case .home: return "H"
        }
    }
}

struct ControllerProfile: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let name: String
    let platform: Platform
    let mappings: [ControllerButton: ControllerButton]
    let layout: [ControllerButton: LayoutPosition]
}

struct LayoutPosition: Codable, Equatable, Hashable, Sendable {
    let x: CGFloat
    let y: CGFloat
}

@MainActor
final class ControllerProfileStore {
    static let shared = ControllerProfileStore()
    private let queue = DispatchQueue(label: "com.xemu.controllerprofiles", qos: .userInitiated)

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileURL: URL

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("controller_profiles.json")
    }

    func loadProfiles() -> [ControllerProfile] {
        return queue.sync {
            guard let data = try? Data(contentsOf: fileURL),
                  let profiles = try? decoder.decode([ControllerProfile].self, from: data) else {
                return defaultProfiles()
            }
            return profiles
        }
    }

    func saveProfile(_ profile: ControllerProfile) {
        let fileURL = self.fileURL
        let encoder = self.encoder
        let decoder = self.decoder
        let fallbackProfiles = defaultProfiles()
        queue.async {
            let profilesData = try? Data(contentsOf: fileURL)
            var profiles = profilesData.flatMap { try? decoder.decode([ControllerProfile].self, from: $0) }
                ?? fallbackProfiles
            profiles.append(profile)

            guard let data = try? encoder.encode(profiles) else { return }
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func defaultProfiles() -> [ControllerProfile] {
        let nesDefaultLayout: [ControllerButton: LayoutPosition] = [
            .dpadUp: LayoutPosition(x: 50, y: 70),
            .dpadDown: LayoutPosition(x: 50, y: 130),
            .dpadLeft: LayoutPosition(x: 20, y: 100),
            .dpadRight: LayoutPosition(x: 80, y: 100),
            .a: LayoutPosition(x: 300, y: 100),
            .b: LayoutPosition(x: 240, y: 120),
            .start: LayoutPosition(x: 170, y: 100),
            .select: LayoutPosition(x: 130, y: 100)
        ]

        let gbaDefaultLayout: [ControllerButton: LayoutPosition] = [
            .dpadUp: LayoutPosition(x: 50, y: 70),
            .dpadDown: LayoutPosition(x: 50, y: 130),
            .dpadLeft: LayoutPosition(x: 20, y: 100),
            .dpadRight: LayoutPosition(x: 80, y: 100),
            .a: LayoutPosition(x: 300, y: 100),
            .b: LayoutPosition(x: 240, y: 120),
            .l: LayoutPosition(x: 50, y: 30),
            .r: LayoutPosition(x: 300, y: 30),
            .start: LayoutPosition(x: 170, y: 100),
            .select: LayoutPosition(x: 130, y: 100)
        ]

        return [
            ControllerProfile(
                id: UUID(),
                name: "NES Default",
                platform: .NES,
                mappings: [:],
                layout: nesDefaultLayout
            ),
            ControllerProfile(
                id: UUID(),
                name: "GBA Default",
                platform: .GBA,
                mappings: [:],
                layout: gbaDefaultLayout
            )
        ]
    }
}
