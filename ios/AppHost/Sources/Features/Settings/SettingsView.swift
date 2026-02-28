import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeController: ThemeController
    @EnvironmentObject private var shellThemeManager: ShellThemeManager
    @State private var showingUpgrade = false
    @State private var showingShellSkins = false
    @AppStorage("frameSkipEnabled") private var frameSkipEnabled = false
    
    var body: some View {
        ZStack {
            backgroundGradients

            VStack(spacing: 0) {
                SettingsHeader {
                    dismiss()
                }

                ScrollView {
                    VStack(spacing: 16) {
                        appInfoCard
                        appearanceCard
                        settingsItems
                        footerSection
                    }
                    .padding(.top, 14)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
        }
        .sheet(isPresented: $showingUpgrade) {
            UpgradeView()
        }
        .sheet(isPresented: $showingShellSkins) {
            ShellSkinsView()
                .environmentObject(shellThemeManager)
        }
    }
    
    private var backgroundGradients: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.primary.opacity(0.18), AppColors.accent.opacity(0.14)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 120)
                .frame(width: 380, height: 380)
                .offset(x: 140, y: -230)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.accent.opacity(0.12), AppColors.primary.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 140)
                .frame(width: 420, height: 420)
                .offset(x: -170, y: 320)
        }
    }
    
    private var appInfoCard: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primary.opacity(0.95), AppColors.accent.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 92, height: 92)
                    .shadow(color: AppColors.primary.opacity(0.35), radius: 14, x: 0, y: 8)

                SettingsBrandIconGlyph()
                    .frame(width: 54, height: 54)
            }

            VStack(spacing: 4) {
                Text("RetroMind")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .tracking(0.2)
                    .foregroundColor(AppColors.textPrimary)

                Text(appVersionText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.textMuted)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(AppColors.success)
                    .frame(width: 8, height: 8)
                Text("Free Plan")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(AppColors.background.opacity(0.45))
            .overlay(
                Capsule()
                    .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [AppColors.primary.opacity(0.12), AppColors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: AppColors.primary.opacity(0.12), radius: 16, x: 0, y: 8)
    }

    private var appVersionText: String {
        return "Version 1.0"
    }
    
    private var settingsItems: some View {
        VStack(spacing: 12) {
            SettingsItem(
                icon: "paintpalette",
                title: "Shell Skins",
                description: "Themes and shell styles",
                iconColor: AppColors.primary,
                iconBackground: AppColors.primary.opacity(0.18)
            ) {
                showingShellSkins = true
            }

            SettingsItem(
                icon: "gamecontroller",
                title: "Controls",
                description: "Layout, opacity, haptics and gestures",
                iconColor: AppColors.accent,
                iconBackground: AppColors.accent.opacity(0.18)
            ) {
                // Reserved for controls settings
            }

            FigmaSettingsToggleRow(
                icon: "gauge.with.dots.needle.67percent",
                iconColor: AppColors.warning,
                iconBg: AppColors.warning.opacity(0.2),
                title: "Frame Skip",
                description: "Skip frames on weaker devices",
                isOn: $frameSkipEnabled
            )
            
            SettingsItem(
                icon: "star.fill",
                title: "Upgrade",
                description: "Cloud saves, themes and advanced controls"
                ,
                iconColor: AppColors.warning,
                iconBackground: AppColors.warning.opacity(0.2)
            ) {
                showingUpgrade = true
            }
            
            SettingsItem(
                icon: "square.and.arrow.up",
                title: "Share",
                description: "Tell your friends about the app"
                ,
                iconColor: AppColors.info,
                iconBackground: AppColors.info.opacity(0.2)
            ) {
                shareApp()
            }
            
            SettingsItem(
                icon: "envelope",
                title: "Feedback",
                description: "Help us improve the app"
                ,
                iconColor: AppColors.success,
                iconBackground: AppColors.success.opacity(0.2)
            ) {
                sendFeedback()
            }
            
            SettingsItem(
                icon: "questionmark.circle",
                title: "Support",
                description: "FAQ and help resources"
                ,
                iconColor: AppColors.primary,
                iconBackground: AppColors.primary.opacity(0.2)
            ) {
                openSupport()
            }
        }
    }

    private var appearanceCard: some View {
        let isLight = themeController.isLightMode

        return HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill((isLight ? AppColors.warning : AppColors.primary).opacity(0.18))
                    .frame(width: 48, height: 48)

                Image(systemName: isLight ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isLight ? AppColors.warning : AppColors.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Appearance")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Text(isLight ? "Light Mode" : "Dark Mode")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.primary)
            }

            Spacer()

            ThemePillToggle(isLight: isLight) {
                themeController.toggleMode()
            }
        }
        .padding(18)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.primary.opacity(0.05), radius: 8, x: 0, y: 4)
    }
    
    private var footerSection: some View {
        VStack(spacing: 14) {
            Text("Made with ❤️ for retro gaming")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textMuted)
            
            HStack(spacing: 24) {
                Button("Privacy Policy") {
                    openURL("https://xemu.app/privacy")
                }
                .font(.system(size: 12))
                .foregroundColor(AppColors.textMuted)
                
                Button("Terms of Service") {
                    openURL("https://xemu.app/terms")
                }
                .font(.system(size: 12))
                .foregroundColor(AppColors.textMuted)
            }
        }
        .padding(.top, 16)
    }
    
    private func shareApp() {
        // Share functionality
    }
    
    private func sendFeedback() {
        // Feedback functionality
    }
    
    private func openSupport() {
        // Support functionality
    }
    
    private func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #elseif canImport(AppKit)
        NSWorkspace.shared.open(url)
        #endif
    }
}

private struct ShellSkinsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var shellThemeManager: ShellThemeManager

    private let consoles: [ShellConsoleKind] = [.gb, .gbc, .gba, .nds]
    private let globalSentinel = "__global__"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard

                    settingSectionCard(title: "Global Shell Theme", subtitle: "Default skin for all supported consoles") {
                        shellThemePickerRow(
                            title: "Global",
                            subtitle: shellThemeManager.activeTheme.displayName,
                            console: nil
                        )
                    }

                    settingSectionCard(title: "Per Emulator", subtitle: "Override shell skins for UAT and comparison") {
                        VStack(spacing: 10) {
                            ForEach(consoles, id: \.self) { console in
                                shellThemePickerRow(
                                    title: console.displayName,
                                    subtitle: currentThemeName(for: console),
                                    console: console
                                )
                                if console != consoles.last {
                                    Divider()
                                        .overlay(AppColors.surfaceLight.opacity(0.35))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationTitle("Appearance & Skins")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shell Theme Picker")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.textPrimary)

            Text("Compare classic and minimal shells per emulator without changing gameplay behavior.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            LinearGradient(
                colors: [AppColors.primary.opacity(0.10), AppColors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.primary.opacity(0.08), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    private func settingSectionCard<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.primary)
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.primary.opacity(0.05), radius: 8, x: 0, y: 4)
    }

    private func shellThemePickerRow(title: String, subtitle: String, console: ShellConsoleKind?) -> some View {
        let available = availableThemes(for: console)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            Picker("", selection: pickerBinding(for: console)) {
                if console != nil {
                    Text("Use Global").tag(globalSentinel)
                }
                ForEach(available) { theme in
                    Text(theme.displayName).tag(theme.id)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColors.primary)
        }
        .padding(.vertical, 4)
    }

    private func availableThemes(for console: ShellConsoleKind?) -> [EmulatorShellTheme] {
        if let console {
            return shellThemeManager.availableThemes
                .filter { $0.supportedConsoles.contains(console) }
                .sorted { $0.displayName < $1.displayName }
        }
        return shellThemeManager.availableThemes.sorted { $0.displayName < $1.displayName }
    }

    private func currentThemeName(for console: ShellConsoleKind) -> String {
        let theme = shellThemeManager.theme(for: console.platform)
        if shellThemeManager.perConsoleSelectedThemeIDs[console] == nil {
            return "\(theme.displayName) (Global)"
        }
        return theme.displayName
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

private struct ThemePillToggle: View {
    let isLight: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill((isLight ? AppColors.warning : AppColors.primary).opacity(0.9))
                    .frame(width: 52, height: 30)

                Circle()
                    .fill(Color.white)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: isLight ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(isLight ? AppColors.warning : AppColors.primary)
                    )
                    .offset(x: isLight ? 26 : 2)
                    .animation(.spring(response: 0.25, dampingFraction: 0.9), value: isLight)
            }
        }
        .buttonStyle(.plain)
    }
}

struct FigmaSettingsToggleRow: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let description: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconBg)
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(description)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.primary)
            }
            
            Spacer()
            
            SwiftUI.Toggle(isOn: $isOn) {
                EmptyView()
            }
                .labelsHidden()
                .tint(AppColors.primary)
        }
        .padding(18)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: AppColors.primary.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

private struct SettingsBrandIconGlyph: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.16))

            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.95))
                .frame(width: 8, height: 20)
                .offset(x: -14, y: 2)
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white.opacity(0.95))
                .frame(width: 20, height: 8)
                .offset(x: -14, y: 2)

            Circle().fill(Color.white.opacity(0.95)).frame(width: 6, height: 6).offset(x: 10, y: -8)
            Circle().fill(Color.white.opacity(0.95)).frame(width: 6, height: 6).offset(x: 22, y: -8)
            Circle().fill(Color.white.opacity(0.95)).frame(width: 6, height: 6).offset(x: 10, y: 4)
            Circle().fill(Color.white.opacity(0.95)).frame(width: 6, height: 6).offset(x: 22, y: 4)

            Path { path in
                path.move(to: CGPoint(x: 30, y: 8))
                path.addLine(to: CGPoint(x: 24, y: 22))
                path.addLine(to: CGPoint(x: 29, y: 22))
                path.addLine(to: CGPoint(x: 25, y: 36))
                path.addLine(to: CGPoint(x: 35, y: 20))
                path.addLine(to: CGPoint(x: 29, y: 20))
                path.closeSubpath()
            }
            .fill(
                LinearGradient(
                    colors: [Color(hex: "FBBF24"), Color(hex: "F59E0B")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 54, height: 54)
        }
    }
}

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Upgrade to Pro")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Unlock all features!")
                    .foregroundColor(.secondary)
                
                Button("Subscribe") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
