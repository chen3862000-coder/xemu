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
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradients
                
                ScrollView {
                    VStack(spacing: 24) {
                        appInfoCard
                        settingsItems
                        footerSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingUpgrade) {
                UpgradeView()
            }
        }
    }
    
    private var backgroundGradients: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            Circle()
                .fill(LinearGradient(
                    colors: [Color.pink.opacity(0.3), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .blur(radius: 100)
                .frame(width: 400, height: 400)
                .offset(x: -100, y: -200)
        }
    }
    
    private var appInfoCard: some View {
        VStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(LinearGradient(
                        colors: [Color.pink, Color.purple, Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            .rotation3DEffect(.degrees(10), axis: (x: 0, y: 1, z: 0))
            
            VStack(spacing: 4) {
                Text("XEmu")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Version 1.0.0 (Build 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Free Plan")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.pink.opacity(0.2))
                .foregroundColor(.pink)
                .cornerRadius(20)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(20)
    }
    
    private var settingsItems: some View {
        VStack(spacing: 12) {
            SettingsItemRow(
                icon: "star.fill",
                iconColor: .yellow,
                iconBg: Color.yellow.opacity(0.2),
                title: "Upgrade to Pro",
                description: "Unlock all features and remove ads"
            ) {
                showingUpgrade = true
            }
            
            SettingsItemRow(
                icon: "square.and.arrow.up",
                iconColor: .blue,
                iconBg: Color.blue.opacity(0.2),
                title: "Share XEmu",
                description: "Tell your friends about the app"
            ) {
                shareApp()
            }
            
            SettingsItemRow(
                icon: "envelope",
                iconColor: .green,
                iconBg: Color.green.opacity(0.2),
                title: "Send Feedback",
                description: "Help us improve the app"
            ) {
                sendFeedback()
            }
            
            SettingsItemRow(
                icon: "questionmark.circle",
                iconColor: .purple,
                iconBg: Color.purple.opacity(0.2),
                title: "Support",
                description: "FAQ and help resources"
            ) {
                openSupport()
            }
        }
    }
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            Text("Made with ❤️ for retro gaming")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 24) {
                Button("Privacy Policy") {
                    openURL("https://xemu.app/privacy")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                Button("Terms of Service") {
                    openURL("https://xemu.app/terms")
                }
                .font(.caption)
                .foregroundColor(.secondary)
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

struct SettingsItemRow: View {
    let icon: String
    let iconColor: Color
    let iconBg: Color
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(iconBg)
                    .frame(width: 44, height: 44)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
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
