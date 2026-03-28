import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeController: ThemeController
    @EnvironmentObject private var shellThemeManager: ShellThemeManager
    @EnvironmentObject private var languageManager: LanguageManager

    @State private var showingUpgrade = false
    @State private var showingShareSheet = false
    @State private var versionTapCount = 0
    @State private var showResetStatsConfirm = false

    @AppStorage("audioQuality") private var audioQuality = 1
    @AppStorage("respectLowPowerMode") private var respectLowPowerMode = true
    @AppStorage("performanceMode") private var performanceModeRaw = PerformanceMode.auto.rawValue
    @AppStorage("showFPSMeter") private var showFPSMeter = false
    @AppStorage("showCartridgeLaunchIntro") private var showCartridgeLaunchIntro = false

    @AppStorage("settings.devModeUnlocked") private var devModeUnlocked = false
    @AppStorage("proUnlocked") private var proUnlocked = false
    @AppStorage("settings.dev.memoryMonitor") private var devMemoryMonitor = false
    @AppStorage("settings.dev.thermalLogging") private var devThermalLogging = false
    @AppStorage("settings.dev.hpDeathDetection") private var devHPDeathDetection = false

    @AppStorage("settings.controller.autoImmersive") private var controllerAutoImmersive = true
    @AppStorage("settings.controller.hideTouchControls") private var controllerHideTouchControls = false
    @AppStorage("settings.controller.touchFallback") private var controllerTouchFallback = TouchFallbackMode.auto.rawValue
    @AppStorage("settings.controller.stickSensitivity") private var controllerStickSensitivity = StickSensitivity.medium.rawValue
    @AppStorage("settings.controller.hapticFeedback") private var controllerHapticFeedback = true
    @AppStorage("settings.dev.gameplayEventOverlay") private var devGameplayEventOverlay = false
    @AppStorage("settings.dev.gameplayEventLogging") private var devGameplayEventLogging = false

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
        return L10n.format("settings.version.format", short, languageManager: languageManager)
    }

    var body: some View {
        NavigationStack {
            List {
                appearanceSection
                performanceSection
                controlsSection
                accountSection
                infoSection
                if isDeveloperModeVisible { developerSection }
            }
            .settingsListStyle()
            .navigationTitle(L10n.string("settings.title", languageManager: languageManager))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.done", languageManager: languageManager)) { dismiss() }
                }
            }
            .alert(L10n.string("settings.dev.reset_local_stats.title", languageManager: languageManager), isPresented: $showResetStatsConfirm) {
                Button(L10n.string("common.cancel", languageManager: languageManager), role: .cancel) {}
                Button(L10n.string("settings.dev.reset_local_stats", languageManager: languageManager), role: .destructive) {
                    resetLocalStats()
                }
            } message: {
                Text(L10n.string("settings.dev.reset_local_stats.message", languageManager: languageManager))
            }
            #if os(iOS)
            .sheet(isPresented: $showingShareSheet) {
                ActivityViewController(activityItems: [L10n.string("settings.share.text", languageManager: languageManager), appStoreURL as Any])
            }
            #endif
        }
    }

    private var appearanceSection: some View {
        Section(header: SettingsSectionHeader(L10n.string("settings.appearance.section", languageManager: languageManager))) {
            NavigationSettingsRow(
                title: L10n.string("settings.theme.title", languageManager: languageManager),
                subtitle: L10n.string("settings.theme.subtitle", languageManager: languageManager),
                value: themeController.mode == .light
                    ? L10n.string("settings.theme.light", languageManager: languageManager)
                    : L10n.string("settings.theme.dark", languageManager: languageManager)
            ) {
                ThemeModeSelectorView()
                    .environmentObject(themeController)
            }

            NavigationSettingsRow(
                title: L10n.string("settings.language.title", languageManager: languageManager),
                subtitle: L10n.string("settings.language.subtitle", languageManager: languageManager),
                value: languageSelectionLabel
            ) {
                LanguageSelectionView()
                    .environmentObject(languageManager)
            }
        }
    }

    private var performanceSection: some View {
        Section(header: SettingsSectionHeader(L10n.string("settings.performance.section", languageManager: languageManager))) {
            NavigationSettingsRow(
                title: L10n.string("settings.audio_quality.title", languageManager: languageManager),
                subtitle: L10n.string("settings.audio_quality.subtitle", languageManager: languageManager),
                value: audioQualityLabel(audioQuality)
            ) {
                AudioQualityView(audioQuality: $audioQuality)
                    .environmentObject(languageManager)
            }

            NavigationSettingsRow(
                title: L10n.string("settings.performance_mode.title", languageManager: languageManager),
                subtitle: L10n.string("settings.performance_mode.subtitle", languageManager: languageManager),
                value: performanceMode.title
            ) {
                PerformanceModeSelectorView(selection: $performanceModeRaw)
            }

            ToggleSettingsRow(
                title: L10n.string("settings.low_power.title", languageManager: languageManager),
                subtitle: L10n.string("settings.low_power.subtitle", languageManager: languageManager),
                isOn: hapticBinding($respectLowPowerMode)
            )

            ToggleSettingsRow(
                title: L10n.string("settings.boot_intro.title", languageManager: languageManager),
                subtitle: L10n.string("settings.boot_intro.subtitle", languageManager: languageManager),
                isOn: hapticBinding($showCartridgeLaunchIntro)
            )

            ToggleSettingsRow(
                title: L10n.string("settings.game_events_detection.title", languageManager: languageManager),
                subtitle: L10n.string("settings.game_events_detection.subtitle", languageManager: languageManager),
                isOn: hapticBinding($devHPDeathDetection)
            )
        }
    }

    private var controlsSection: some View {
        Section(header: SettingsSectionHeader(L10n.string("settings.controls.section", languageManager: languageManager))) {
            NavigationSettingsRow(
                title: L10n.string("settings.controller.title", languageManager: languageManager),
                subtitle: L10n.string("settings.controller.subtitle", languageManager: languageManager)
            ) {
                ControllerSettingsView(
                    autoImmersive: $controllerAutoImmersive,
                    hideTouchControls: $controllerHideTouchControls,
                    touchFallbackRaw: $controllerTouchFallback,
                    stickSensitivityRaw: $controllerStickSensitivity,
                    hapticFeedback: $controllerHapticFeedback,
                    showDevAdvanced: isDeveloperModeVisible
                )
            }
        }
    }

    private var accountSection: some View {
        Section(header: SettingsSectionHeader(L10n.string("settings.account.section", languageManager: languageManager))) {
            NavigationSettingsRow(
                title: L10n.string("settings.upgrade.title", languageManager: languageManager),
                subtitle: L10n.string("settings.upgrade.subtitle", languageManager: languageManager)
            ) {
                UpgradeView()
            }

            Button {
                showingShareSheet = true
            } label: {
                SettingsTextStack(
                    title: L10n.string("settings.share.title", languageManager: languageManager),
                    subtitle: L10n.string("settings.share.subtitle", languageManager: languageManager)
                )
                .frame(maxWidth: .infinity, minHeight: SettingsTokens.rowHeight, alignment: .leading)
                .contentShape(Rectangle())
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
                    title: L10n.string("settings.support.title", languageManager: languageManager),
                    subtitle: L10n.string("settings.support.subtitle", languageManager: languageManager)
                )
                .frame(maxWidth: .infinity, minHeight: SettingsTokens.rowHeight, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var infoSection: some View {
        Section(header: SettingsSectionHeader(L10n.string("settings.info.section", languageManager: languageManager))) {
            NavigationSettingsRow(
                title: L10n.string("settings.privacy_policy.title", languageManager: languageManager),
                subtitle: L10n.string("settings.privacy_policy.subtitle", languageManager: languageManager)
            ) {
                PrivacyPolicyView()
                    .environmentObject(languageManager)
            }

            NavigationSettingsRow(
                title: L10n.string("settings.user_agreement.title", languageManager: languageManager),
                subtitle: L10n.string("settings.user_agreement.subtitle", languageManager: languageManager)
            ) {
                UserAgreementView()
                    .environmentObject(languageManager)
            }

            InfoSettingsRow(title: L10n.string("app.brand.title", languageManager: languageManager), value: appVersionText)
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
        Section(header: SettingsSectionHeader(L10n.string("settings.developer.section", languageManager: languageManager))) {
            ToggleSettingsRow(title: L10n.string("settings.dev.fps_overlay", languageManager: languageManager), isOn: hapticBinding($showFPSMeter))
            ToggleSettingsRow(title: L10n.string("settings.dev.memory_monitor", languageManager: languageManager), isOn: hapticBinding($devMemoryMonitor))
            ToggleSettingsRow(title: L10n.string("settings.dev.thermal_logging", languageManager: languageManager), isOn: hapticBinding($devThermalLogging))
            ToggleSettingsRow(
                title: L10n.string("settings.dev.gameplay_event_overlay", languageManager: languageManager),
                subtitle: L10n.string("settings.dev.gameplay_event_overlay.subtitle", languageManager: languageManager),
                isOn: hapticBinding($devGameplayEventOverlay)
            )
            ToggleSettingsRow(
                title: L10n.string("settings.dev.gameplay_event_logging", languageManager: languageManager),
                subtitle: L10n.string("settings.dev.gameplay_event_logging.subtitle", languageManager: languageManager),
                isOn: hapticBinding($devGameplayEventLogging)
            )

            NavigationSettingsRow(title: L10n.string("settings.dev.debug_controller_input", languageManager: languageManager)) {
                ControllerInputDebugView()
            }

            DestructiveSettingsRow(title: L10n.string("settings.dev.reset_local_stats", languageManager: languageManager)) {
                showResetStatsConfirm = true
            }
        }
    }

    private func audioQualityLabel(_ value: Int) -> String {
        switch value {
        case 0: return L10n.string("settings.audio_quality.sound_first", languageManager: languageManager)
        case 1: return L10n.string("settings.audio_quality.balanced", languageManager: languageManager)
        case 2: return L10n.string("settings.audio_quality.frame_first", languageManager: languageManager)
        default: return L10n.string("settings.audio_quality.balanced", languageManager: languageManager)
        }
    }

    private var languageSelectionLabel: String {
        switch languageManager.currentLanguage {
        case .system:
            return L10n.string("settings.follow_system", languageManager: languageManager)
        default:
            return languageManager.currentLanguage.nativeDisplayName
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
        devGameplayEventOverlay = false
        devGameplayEventLogging = false
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
        Text(text)
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
            .frame(maxWidth: .infinity, minHeight: SettingsTokens.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
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
        .frame(maxWidth: .infinity, minHeight: SettingsTokens.rowHeight, alignment: .leading)
        .contentShape(Rectangle())
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
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        List {
            Section {
                themeModeButton(.light, title: L10n.string("settings.theme.light", languageManager: languageManager))
                themeModeButton(.dark, title: L10n.string("settings.theme.dark", languageManager: languageManager))
            }
        }
        .settingsListStyle()
        .navigationTitle(L10n.string("settings.theme.nav", languageManager: languageManager))
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
            .frame(maxWidth: .infinity, minHeight: SettingsTokens.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PerformanceModeSelectorView: View {
    @EnvironmentObject private var languageManager: LanguageManager
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
        .navigationTitle(L10n.string("settings.performance_mode.nav", languageManager: languageManager))
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
            .frame(maxWidth: .infinity, minHeight: SettingsTokens.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ControllerSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @Binding var autoImmersive: Bool
    @Binding var hideTouchControls: Bool
    @Binding var touchFallbackRaw: String
    @Binding var stickSensitivityRaw: String
    @Binding var hapticFeedback: Bool
    let showDevAdvanced: Bool

    private var controllerStatus: String {
        InputBus.shared.isControllerConnected()
            ? L10n.string("settings.connected", languageManager: languageManager)
            : L10n.string("settings.not_connected", languageManager: languageManager)
    }

    private var controllerName: String {
        InputBus.shared.getActiveControllerName() ?? "—"
    }

    var body: some View {
        List {
            Section(header: SettingsSectionHeader(L10n.string("settings.connection.section", languageManager: languageManager))) {
                InfoSettingsRow(title: L10n.string("settings.controller.status", languageManager: languageManager), value: controllerStatus)
                InfoSettingsRow(title: L10n.string("settings.controller.name", languageManager: languageManager), value: controllerName)
            }

            Section(header: SettingsSectionHeader(L10n.string("settings.behavior.section", fallback: "Behavior", languageManager: languageManager))) {
                ToggleSettingsRow(title: L10n.string("settings.controller.auto_immersive", languageManager: languageManager), isOn: $autoImmersive)
                ToggleSettingsRow(title: L10n.string("settings.controller.hide_touch_controls", languageManager: languageManager), isOn: $hideTouchControls)
                ToggleSettingsRow(title: L10n.string("settings.controller.haptic_feedback", languageManager: languageManager), isOn: $hapticFeedback)

                NavigationSettingsRow(
                    title: L10n.string("settings.controller.touch_fallback", languageManager: languageManager),
                    value: TouchFallbackMode(rawValue: touchFallbackRaw)?.title ?? TouchFallbackMode.auto.title
                ) {
                    TouchFallbackSelectorView(selection: $touchFallbackRaw)
                }
            }

            Section(header: SettingsSectionHeader(L10n.string("settings.layout.section", languageManager: languageManager))) {
                NavigationSettingsRow(title: L10n.string("settings.controller.button_mapping", languageManager: languageManager)) {
                    ControllerMappingEditor(platform: .GBA)
                }

                NavigationSettingsRow(
                    title: L10n.string("settings.controller.stick_sensitivity", languageManager: languageManager),
                    value: StickSensitivity(rawValue: stickSensitivityRaw)?.title ?? StickSensitivity.medium.title
                ) {
                    StickSensitivitySelectorView(selection: $stickSensitivityRaw)
                }
            }

            if showDevAdvanced {
                Section(header: SettingsSectionHeader(L10n.string("settings.advanced.section", fallback: "Advanced", languageManager: languageManager))) {
                    NavigationSettingsRow(title: L10n.string("settings.controller.input_debug", languageManager: languageManager)) {
                        ControllerInputDebugView()
                    }
                }
            }
        }
        .settingsListStyle()
        .navigationTitle(L10n.string("settings.controller.nav", languageManager: languageManager))
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
        case .auto: return L10n.string("settings.touch_fallback.auto")
        case .alwaysOn: return L10n.string("settings.touch_fallback.always_on")
        case .alwaysOff: return L10n.string("settings.touch_fallback.always_off")
        }
    }
}

private struct TouchFallbackSelectorView: View {
    @EnvironmentObject private var languageManager: LanguageManager
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
        .navigationTitle(L10n.string("settings.controller.touch_fallback", languageManager: languageManager))
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
            .frame(maxWidth: .infinity, minHeight: SettingsTokens.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
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
        case .low: return L10n.string("settings.stick_sensitivity.low")
        case .medium: return L10n.string("settings.stick_sensitivity.medium")
        case .high: return L10n.string("settings.stick_sensitivity.high")
        }
    }
}

private struct StickSensitivitySelectorView: View {
    @EnvironmentObject private var languageManager: LanguageManager
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
        .navigationTitle(L10n.string("settings.controller.stick_sensitivity", languageManager: languageManager))
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
            .frame(maxWidth: .infinity, minHeight: SettingsTokens.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
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
        case .gb: return L10n.string("console.gb")
        case .gbc: return L10n.string("console.gbc")
        case .gba: return L10n.string("console.gba")
        case .nds: return L10n.string("console.nds")
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
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        List {
            Section(header: SettingsSectionHeader(L10n.string("settings.upgrade.title", languageManager: languageManager))) {
                Text(L10n.string("settings.upgrade.description", languageManager: languageManager))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)

                Button(L10n.string("settings.upgrade.subscribe", languageManager: languageManager)) {
                    dismiss()
                }
                .frame(minHeight: SettingsTokens.rowHeight, alignment: .leading)
            }
        }
        .settingsListStyle()
        .navigationTitle(L10n.string("settings.upgrade.nav", languageManager: languageManager))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

private struct LanguageSelectionView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    var body: some View {
        List {
            Section {
                ForEach(SupportedLanguage.allCases) { language in
                    languageButton(language)
                }
            } footer: {
                Text(L10n.string("settings.language.restart_note", languageManager: languageManager))
            }
        }
        .settingsListStyle()
        .navigationTitle(L10n.string("settings.language.nav", languageManager: languageManager))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func languageButton(_ language: SupportedLanguage) -> some View {
        Button {
            languageManager.setLanguage(language)
        } label: {
            HStack {
                Text(title(for: language))
                Spacer()
                if languageManager.currentLanguage == language {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: SettingsTokens.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func title(for language: SupportedLanguage) -> String {
        switch language {
        case .system:
            return L10n.string("settings.follow_system", languageManager: languageManager)
        default:
            return language.nativeDisplayName
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeController.shared)
        .environmentObject(ShellThemeManager.shared)
        .environmentObject(LanguageManager.shared)
}
