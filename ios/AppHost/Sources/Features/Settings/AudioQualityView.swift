import SwiftUI

struct AudioQualityView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager
    @Binding var audioQuality: Int
    
    var body: some View {
        List {
            Section {
                AudioQualityRow(
                    title: L10n.string("settings.audio_quality.sound_first", languageManager: languageManager),
                    description: L10n.string("settings.audio_quality.sound_first_description", languageManager: languageManager),
                    icon: "speaker.wave.3.fill",
                    isSelected: audioQuality == 0
                ) {
                    audioQuality = 0
                }
                
                AudioQualityRow(
                    title: L10n.string("settings.audio_quality.balanced", languageManager: languageManager),
                    description: L10n.string("settings.audio_quality.balanced_description", languageManager: languageManager),
                    icon: "speaker.wave.2.fill",
                    isSelected: audioQuality == 1
                ) {
                    audioQuality = 1
                }
                
                AudioQualityRow(
                    title: L10n.string("settings.audio_quality.frame_first", languageManager: languageManager),
                    description: L10n.string("settings.audio_quality.frame_first_description", languageManager: languageManager),
                    icon: "speaker.fill",
                    isSelected: audioQuality == 2
                ) {
                    audioQuality = 2
                }
            } header: {
                Text(L10n.string("settings.audio_quality.title", languageManager: languageManager))
            } footer: {
                Text(L10n.string("settings.audio_quality.footer", languageManager: languageManager))
            }
        }
        .navigationTitle(L10n.string("settings.audio_quality.nav", languageManager: languageManager))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.string("common.done", languageManager: languageManager)) {
                    dismiss()
                }
            }
        }
    }
}

struct AudioQualityRow: View {
    let title: String
    let description: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct AudioQualityView_Previews: PreviewProvider {
    static var previews: some View {
        AudioQualityView(audioQuality: .constant(1))
            .environmentObject(LanguageManager.shared)
    }
}
