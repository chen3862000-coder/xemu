import SwiftUI

struct AudioQualityView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var audioQuality: Int
    
    var body: some View {
        List {
            Section {
                AudioQualityRow(
                    title: "Sound First",
                    description: "Best audio quality, may affect frame rate",
                    icon: "speaker.wave.3.fill",
                    isSelected: audioQuality == 0
                ) {
                    audioQuality = 0
                }
                
                AudioQualityRow(
                    title: "Balanced",
                    description: "Good audio quality with moderate frame rate",
                    icon: "speaker.wave.2.fill",
                    isSelected: audioQuality == 1
                ) {
                    audioQuality = 1
                }
                
                AudioQualityRow(
                    title: "Frame First",
                    description: "Prioritize smooth gameplay, basic audio",
                    icon: "speaker.fill",
                    isSelected: audioQuality == 2
                ) {
                    audioQuality = 2
                }
            } header: {
                Text("Audio Quality")
            } footer: {
                Text("Sound First provides the cleanest audio but may impact performance on older devices.")
            }
        }
        .navigationTitle("Audio Quality")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
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
    }
}
