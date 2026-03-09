import SwiftUI

struct StandardGameRow: View {
    let entry: ROMLibraryEntry
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail (16:9)
                thumbnailView
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(GameCardTitleFormatter.format(entry.title, maxWords: 7))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(height: 38, alignment: .topLeading)
                    
                    HStack(spacing: 6) {
                        // Last played
                        Text(lastPlayedText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(AppColors.textSecondary)
                        
                        if entry.playtimeTotal > 0 {
                            Text("•")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.textMuted)
                            
                            Text("\(entry.playtimeTotal / 3600)h played")
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textMuted)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.textMuted)
            }
            .padding(12)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
            .scaleEffect(isPressed ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
    }
    
    private var thumbnailView: some View {
        ZStack {
            #if os(iOS)
            if let screenshotData = SaveStateStorage.shared.latestScreenshot(for: entry.checksum ?? ""),
               let uiImage = UIImage(data: screenshotData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if let resolved = CoverArtService.shared.resolve(for: entry),
                      let uiImage = UIImage(data: resolved.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
            #else
            placeholderView
            #endif
        }
    }
    
    private var placeholderView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(placeholderColor)
            
            Text(String(entry.title?.prefix(1) ?? "?").uppercased())
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(.white.opacity(0.25))
            
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        }
    }
    
    private var placeholderColor: Color {
        switch entry.system?.uppercased() {
        case "GB", "GBC":
            return Color(hue: 0.42, saturation: 0.25, brightness: 0.90)
        case "GBA":
            return Color(hue: 0.75, saturation: 0.30, brightness: 0.78)
        case "NDS":
            return Color(hue: 0.58, saturation: 0.18, brightness: 0.85)
        default:
            return Color(hue: 0.70, saturation: 0.22, brightness: 0.82)
        }
    }
    
    private var lastPlayedText: String {
        guard let lastPlayed = entry.lastPlayedAt else { return "Never played" }
        
        let calendar = Calendar.current
        if calendar.isDateInToday(lastPlayed) {
            return "Today"
        } else if calendar.isDateInYesterday(lastPlayed) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: lastPlayed, to: Date()).day ?? 0
            if days < 7 {
                return "\(days)d ago"
            } else {
                return lastPlayed.formatted(.dateTime.month(.abbreviated).day())
            }
        }
    }
}
