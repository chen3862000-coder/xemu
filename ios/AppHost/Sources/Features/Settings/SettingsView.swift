import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeController: ThemeController
    @EnvironmentObject private var shellThemeManager: ShellThemeManager

    @State private var showingUpgrade = false
    @State private var showingShareSheet = false
    @State private var versionTapCount = 0
    @State private var showResetStatsConfirm = false

    @AppStorage("audioQuality") private var audioQuality = 1
    @AppStorage("respectLowPowerMode") private var respectLowPowerMode = true
    @AppStorage("performanceMode") private var performanceModeRaw = PerformanceMode.auto.rawValue
    @AppStorage("showFPSMeter") private var showFPSMeter = false
    @AppStorage("showCartridgeLaunchIntro") private var showCartridgeLaunchIntro = true
    @AppStorage("dynamicConsoleLightingEnabled") private var dynamicConsoleLightingEnabled = true

    @AppStorage("settings.devModeUnlocked") private var devModeUnlocked = false
    @AppStorage("proUnlocked") private var proUnlocked = false
    @AppStorage("settings.dev.memoryMonitor") private var devMemoryMonitor = false
    @AppStorage("settings.dev.thermalLogging") private var devThermalLogging = false

    @AppStorage("settings.controller.autoImmersive") private var controllerAutoImmersive = true
    @AppStorage("settings.controller.hideTouchControls") private var controllerHideTouchControls = false
    @AppStorage("settings.controller.touchFallback") private var controllerTouchFallback = TouchFallbackMode.auto.rawValue
    @AppStorage("settings.controller.stickSensitivity") private var controllerStickSensitivity = StickSensitivity.medium.rawValue

    private let appStoreURL = URL(string: "https://apps.apple.com")

    private var performanceMode: PerformanceMode {
        get { PerformanceMode(rawValue: performanceModeRaw) ?? .auto }
        set { performanceModeRaw = newValue.rawValue }
    }

    private var isDeveloperModeVisible: Bool {
        devModeUnlocked || proUnlocked
    }

    private var appVersionText: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                visualEffectsSection
                performanceSection
                controlsSection
                accountSection
                infoSection
                if isDeveloperModeVisible { developerSection }
            }
            .settingsListStyle()
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset local stats?", isPresented: $showResetStatsConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive) {
                    resetLocalStats()
                }
            } message: {
                Text("This clears local developer/performance stat toggles only.")
            }
            #if os(iOS)
            .sheet(isPresented: $showingShareSheet) {
                ActivityViewController(activityItems: ["Check out Xemu!", appStoreURL as Any])
            }
            #endif
        }
    }

    private var appearanceSection: some View {
        Section(header: SettingsSectionHeader("Appearance")) {
            NavigationSettingsRow(
                title: "Theme",
                subtitle: "Light or dark",
                value: themeController.mode == .light ? "Light" : "Dark"
            ) {
                ThemeModeSelectorView()
                    .environmentObject(themeController)
            }

            NavigationSettingsRow(
                title: "Shell Skins",
                subtitle: "Global and per-emulator styles",
                value: shellThemeManager.activeTheme.displayName
            ) {
                ShellSkinsView()
                    .environmentObject(shellThemeManager)
            }
        }
    }

    private var performanceSection: some View {
        Section(header: SettingsSectionHeader("Performance")) {
            NavigationSettingsRow(
                title: "Audio Quality",
                subtitle: "Output strategy",
                value: audioQualityLabel(audioQuality)
            ) {
                AudioQualityView(audioQuality: $audioQuality)
            }

            NavigationSettingsRow(
                title: "Performance Mode",
                subtitle: "Balance quality and battery",
                value: performanceMode.title
            ) {
                PerformanceModeSelectorView(selection: $performanceModeRaw)
            }

            ToggleSettingsRow(
                title: "Respect Low Power Mode",
                subtitle: "Reduce heavy effects in battery saver",
                isOn: hapticBinding($respectLowPowerMode)
            )

            ToggleSettingsRow(
                title: "Retro Boot Experience",
                subtitle: "Cartridge insert + console startup before game launch",
                isOn: hapticBinding($showCartridgeLaunchIntro)
            )
        }
    }

    private var visualEffectsSection: some View {
        Section(header: SettingsSectionHeader("Visual Effects")) {
            ToggleSettingsRow(
                title: "Dynamic Console Lighting",
                subtitle: "Subtle shell tint reacts to game colors",
                isOn: hapticBinding($dynamicConsoleLightingEnabled)
            )
        }
    }

    private var controlsSection: some View {
        Section(header: SettingsSectionHeader("Controls")) {
            NavigationSettingsRow(
                title: "Controller",
                subtitle: "Connection, behavior and layout"
            ) {
                ControllerSettingsView(
                    autoImmersive: $controllerAutoImmersive,
                    hideTouchControls: $controllerHideTouchControls,
                    touchFallbackRaw: $controllerTouchFallback,
                    stickSensitivityRaw: $controllerStickSensitivity,
                    showDevAdvanced: isDeveloperModeVisible
                )
            }
        }
    }

    private var accountSection: some View {
        Section(header: SettingsSectionHeader("Account")) {
            NavigationSettingsRow(
                title: "Status",
                subtitle: "Subscription and entitlement state"
            ) {
                EntitlementStatusView()
            }

            NavigationSettingsRow(
                title: "Upgrade",
                subtitle: "Unlock Pro features"
            ) {
                UpgradeView()
            }

            Button {
                showingShareSheet = true
            } label: {
                SettingsTextStack(
                    title: "Share App",
                    subtitle: "Tell a friend"
                )
                .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button {
                if let url = appStoreURL {
                    #if canImport(UIKit)
                    UIApplication.shared.open(url)
                    #endif
                }
            } label: {
                SettingsTextStack(
                    title: "Support",
                    subtitle: "FAQ and help resources"
                )
                .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private var infoSection: some View {
        Section(header: SettingsSectionHeader("Info")) {
            InfoSettingsRow(title: "App", value: appVersionText)
                .contentShape(Rectangle())
                .onTapGesture {
                    versionTapCount += 1
                    if versionTapCount >= 5 {
                        devModeUnlocked = true
                    }
                }
        }
    }

    private var developerSection: some View {
        Section(header: SettingsSectionHeader("Developer")) {
            ToggleSettingsRow(title: "FPS Overlay", isOn: hapticBinding($showFPSMeter))
            ToggleSettingsRow(title: "Memory Monitor", isOn: hapticBinding($devMemoryMonitor))
            ToggleSettingsRow(title: "Thermal Logging", isOn: hapticBinding($devThermalLogging))

            NavigationSettingsRow(title: "Debug Controller Input") {
                ControllerMappingEditor(platform: .GBA)
            }

            DestructiveSettingsRow(title: "Reset Local Stats") {
                showResetStatsConfirm = true
            }
        }
    }

    private func audioQualityLabel(_ value: Int) -> String {
        switch value {
        case 0: return "Sound First"
        case 1: return "Balanced"
        case 2: return "Frame First"
        default: return "Balanced"
        }
    }

    private func hapticBinding(_ binding: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                binding.wrappedValue = newValue
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
        )
    }

    private func resetLocalStats() {
        showFPSMeter = false
        devMemoryMonitor = false
        devThermalLogging = false
    }
}

private enum SettingsTokens {
    static let rowHeight: CGFloat = 56
}

private struct SettingsSectionHeader: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.tertiary)
    }
}

private struct SettingsTextStack: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct NavigationSettingsRow<Destination: View>: View {
    let title: String
    let subtitle: String?
    let value: String?
    let destination: Destination

    init(
        title: String,
        subtitle: String? = nil,
        value: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) {
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: 12) {
                SettingsTextStack(title: title, subtitle: subtitle)
                Spacer(minLength: 8)
                if let value {
                    Text(value)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)
        }
    }
}

private struct ToggleSettingsRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
    }

    var body: some View {
        HStack(spacing: 12) {
            SettingsTextStack(title: title, subtitle: subtitle)
            Spacer(minLength: 8)
            SwiftUI.Toggle(isOn: $isOn) { EmptyView() }
                .labelsHidden()
        }
        .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)
    }
}

private struct InfoSettingsRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)
    }
}

private struct DestructiveSettingsRow: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: SettingsTokens.rowHeight, alignment: .leading)
        }
    }
}

private struct ThemeModeSelectorView: View {
    @EnvironmentObject private var themeController: ThemeController

    var body: some View {
        List {
            Section {
                themeModeButton(.light, title: "Light")
                themeModeButton(.dark, title: "Dark")
            }
        }
        .settingsListStyle()
        .navigationTitle("Theme")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func themeModeButton(_ mode: AppThemeMode, title: String) -> some View {
        Button {
            themeController.setMode(mode)
        } label: {
            HStack {
                Text(title)
                Spacer()
                if themeController.mode == mode {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct PerformanceModeSelectorView: View {
    @Binding var selection: String

    var body: some View {
        List {
            Section {
                performanceButton(.auto)
                performanceButton(.quality)
                performanceButton(.battery)
            }
        }
        .settingsListStyle()
        .navigationTitle("Performance Mode")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func performanceButton(_ mode: PerformanceMode) -> some View {
        Button {
            selection = mode.rawValue
        } label: {
            HStack {
                Text(mode.title)
                Spacer()
                if selection == mode.rawValue {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct ControllerSettingsView: View {
    @Binding var autoImmersive: Bool
    @Binding var hideTouchControls: Bool
    @Binding var touchFallbackRaw: String
    @Binding var stickSensitivityRaw: String
    let showDevAdvanced: Bool

    private var controllerStatus: String {
        InputBus.shared.isControllerConnected() ? "Connected" : "Not Connected"
    }

    private var controllerName: String {
        InputBus.shared.getActiveControllerName() ?? "—"
    }

    var body: some View {
        List {
            Section(header: SettingsSectionHeader("Connection")) {
                InfoSettingsRow(title: "Status", value: controllerStatus)
                InfoSettingsRow(title: "Name", value: controllerName)
            }

            Section(header: SettingsSectionHeader("Behavior")) {
                ToggleSettingsRow(title: "Auto Switch to Immersive", isOn: $autoImmersive)
                ToggleSettingsRow(title: "Hide Touch Controls", isOn: $hideTouchControls)

                NavigationSettingsRow(
                    title: "Touch Fallback",
                    value: TouchFallbackMode(rawValue: touchFallbackRaw)?.title ?? TouchFallbackMode.auto.title
                ) {
                    TouchFallbackSelectorView(selection: $touchFallbackRaw)
                }
            }

            Section(header: SettingsSectionHeader("Layout")) {
                NavigationSettingsRow(title: "Button Mapping") {
                    ControllerMappingEditor(platform: .GBA)
                }

                NavigationSettingsRow(
                    title: "Stick Sensitivity",
                    value: StickSensitivity(rawValue: stickSensitivityRaw)?.title ?? StickSensitivity.medium.title
                ) {
                    StickSensitivitySelectorView(selection: $stickSensitivityRaw)
                }
            }

            if showDevAdvanced {
                Section(header: SettingsSectionHeader("Advanced")) {
                    NavigationSettingsRow(title: "Input Debug") {
                        ControllerMappingEditor(platform: .GBA)
                    }
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("Controller")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private enum TouchFallbackMode: String, CaseIterable {
    case auto
    case alwaysOn
    case alwaysOff

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .alwaysOn: return "Always On"
        case .alwaysOff: return "Always Off"
        }
    }
}

private struct TouchFallbackSelectorView: View {
    @Binding var selection: String

    var body: some View {
        List {
            Section {
                touchFallbackButton(.auto)
                touchFallbackButton(.alwaysOn)
                touchFallbackButton(.alwaysOff)
            }
        }
        .settingsListStyle()
        .navigationTitle("Touch Fallback")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func touchFallbackButton(_ mode: TouchFallbackMode) -> some View {
        Button {
            selection = mode.rawValue
        } label: {
            HStack {
                Text(mode.title)
                Spacer()
                if selection == mode.rawValue {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private enum StickSensitivity: String, CaseIterable {
    case low
    case medium
    case high

    var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

private struct StickSensitivitySelectorView: View {
    @Binding var selection: String

    var body: some View {
        List {
            Section {
                stickSensitivityButton(.low)
                stickSensitivityButton(.medium)
                stickSensitivityButton(.high)
            }
        }
        .settingsListStyle()
        .navigationTitle("Stick Sensitivity")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func stickSensitivityButton(_ mode: StickSensitivity) -> some View {
        Button {
            selection = mode.rawValue
        } label: {
            HStack {
                Text(mode.title)
                Spacer()
                if selection == mode.rawValue {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}

private struct ShellSkinsView: View {
    @EnvironmentObject private var shellThemeManager: ShellThemeManager

    private let consoles: [ShellConsoleKind] = [.gb, .gbc, .gba, .nds]
    private let globalSentinel = "__global__"

    var body: some View {
        List {
            Section(header: SettingsSectionHeader("Global")) {
                shellThemePickerRow(title: "Global Theme", console: nil)
            }

            Section(header: SettingsSectionHeader("Per Emulator")) {
                ForEach(consoles, id: \.self) { console in
                    shellThemePickerRow(title: console.displayName, console: console)
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("Shell Skins")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func shellThemePickerRow(title: String, console: ShellConsoleKind?) -> some View {
        let available = availableThemes(for: console)
        let subtitle = currentThemeName(for: console)

        return HStack(spacing: 12) {
            SettingsTextStack(title: title, subtitle: subtitle)
            Spacer(minLength: 8)
            Picker("", selection: pickerBinding(for: console)) {
                if console != nil {
                    Text("Use Global").tag(globalSentinel)
                }
                ForEach(available) { theme in
                    Text(theme.displayName).tag(theme.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
        }
        .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)
    }

    private func availableThemes(for console: ShellConsoleKind?) -> [EmulatorShellTheme] {
        if let console {
            return shellThemeManager.availableThemes
                .filter { $0.supportedConsoles.contains(console) }
                .sorted { $0.displayName < $1.displayName }
        }
        return shellThemeManager.availableThemes.sorted { $0.displayName < $1.displayName }
    }

    private func currentThemeName(for console: ShellConsoleKind?) -> String {
        if let console {
            let theme = shellThemeManager.theme(for: console.platform)
            if shellThemeManager.perConsoleSelectedThemeIDs[console] == nil {
                return "\(theme.displayName) (Global)"
            }
            return theme.displayName
        }
        return shellThemeManager.activeTheme.displayName
    }

    private func pickerBinding(for console: ShellConsoleKind?) -> Binding<String> {
        Binding(
            get: {
                if let console {
                    return shellThemeManager.perConsoleSelectedThemeIDs[console] ?? globalSentinel
                }
                return shellThemeManager.selectedThemeID
            },
            set: { newValue in
                if let console {
                    if newValue == globalSentinel {
                        shellThemeManager.clearConsoleThemeOverride(console)
                    } else {
                        shellThemeManager.setTheme(id: newValue, for: console)
                    }
                } else {
                    shellThemeManager.setTheme(id: newValue)
                }
            }
        )
    }
}

private extension ShellConsoleKind {
    var displayName: String {
        switch self {
        case .gb: return "Game Boy"
        case .gbc: return "Game Boy Color"
        case .gba: return "Game Boy Advance"
        case .nds: return "Nintendo DS"
        }
    }

    var platform: Platform {
        switch self {
        case .gb: return .GB
        case .gbc: return .GBC
        case .gba: return .GBA
        case .nds: return .NDS
        }
    }
}

private extension View {
    @ViewBuilder
    func settingsListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self
        #endif
    }
}

#if os(iOS)
private struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section(header: SettingsSectionHeader("Upgrade")) {
                Text("Unlock cloud saves, advanced controls and premium features.")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)

                Button("Subscribe") {
                    dismiss()
                }
                .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)
            }
        }
        .settingsListStyle()
        .navigationTitle("Upgrade")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

#Preview {
    SettingsView()
}
