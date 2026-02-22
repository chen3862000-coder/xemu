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
    @State private var showingUpgrade = false
    @AppStorage("frameSkipEnabled") private var frameSkipEnabled = false
    
    var body: some View {
        ZStack {
            backgroundGradients

            VStack(spacing: 0) {
                SettingsHeader {
                    dismiss()
                }

                ScrollView {
                    VStack(spacing: 18) {
                        appInfoCard
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
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.primary, AppColors.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: AppColors.primary.opacity(0.35), radius: 14, x: 0, y: 8)

                SettingsBrandIconGlyph()
                    .frame(width: 54, height: 54)
            }

            VStack(spacing: 4) {
                Text("XEmu Pro")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)

                Text(appVersionText)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textMuted)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(AppColors.success)
                    .frame(width: 8, height: 8)
                Text("Free Plan")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppColors.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppColors.background.opacity(0.45))
            .overlay(
                Capsule()
                    .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
            )
            .clipShape(Capsule())
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "Version \(version) (\(build))"
    }
    
    private var settingsItems: some View {
        VStack(spacing: 12) {
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
                description: "Unlock all features and remove ads"
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
    
    private var footerSection: some View {
        VStack(spacing: 12) {
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
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.textMuted)
            }
            
            Spacer()
            
            SwiftUI.Toggle(isOn: $isOn) {
                EmptyView()
            }
                .labelsHidden()
                .tint(AppColors.primary)
        }
        .padding(16)
        .background(AppColors.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
