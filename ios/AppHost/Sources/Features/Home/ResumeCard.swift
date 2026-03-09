import SwiftUI

struct ResumeCard: View {
    let entry: ROMLibraryEntry
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Background - screenshot or placeholder
                coverImage
                    .aspectRatio(16/9, contentMode: .fill)
                    .clipped()
                
                // Dark overlay gradient
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(GameCardTitleFormatter.format(entry.title, maxWords: 7))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .frame(height: 40, alignment: .topLeading)
                    
                    HStack(spacing: 6) {
                        Text(lastPlayedText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        if entry.playtimeTotal > 0 {
                            Text("•")
                                .foregroundColor(.white.opacity(0.6))
                            Text("\(entry.playtimeTotal / 3600)h played")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    
                    // Progress bar (optional)
                    if entry.playtimeTotal > 0 {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(height: 4)
                                
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white)
                                    .frame(width: geometry.size.width * 0.3, height: 4)
                            }
                        }
                        .frame(height: 4)
                    }
                }
                .padding(14)
                
                // Console badge
                consoleBadge
                    .padding(12)
            }
            .aspectRatio(16/9, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            .scaleEffect(isPressed ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = true } }
                .onEnded { _ in withAnimation(.easeInOut(duration: 0.1)) { isPressed = false } }
        )
    }
    
    @ViewBuilder
    private var coverImage: some View {
        #if os(iOS)
        if let screenshotData = SaveStateStorage.shared.latestScreenshot(for: entry.checksum ?? ""),
           let uiImage = UIImage(data: screenshotData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: 0.5)
        } else if let resolved = CoverArtService.shared.resolve(for: entry),
                  let uiImage = UIImage(data: resolved.data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            placeholderBackground
        }
        #else
        placeholderBackground
        #endif
    }
    
    private var placeholderBackground: some View {
        ZStack {
            consoleColor
            Text(String(entry.title?.prefix(1) ?? "?").uppercased())
                .font(.system(size: 64, weight: .heavy))
                .foregroundColor(.white.opacity(0.25))
        }
    }
    
    private var consoleColor: Color {
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
    
    private var consoleBadge: some View {
        VStack {
            HStack {
                Spacer()
                Text(entry.system?.uppercased() ?? "")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(consoleBadgeColor.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Spacer()
        }
    }
    
    private var consoleBadgeColor: Color {
        switch entry.system?.uppercased() {
        case "GBA": return Color(red: 0.55, green: 0.30, blue: 0.75)
        case "GB", "GBC": return Color(red: 0.20, green: 0.65, blue: 0.60)
        case "NDS": return Color(red: 0.25, green: 0.45, blue: 0.70)
        default: return Color.gray
        }
    }
    
    private var lastPlayedText: String {
        guard let lastPlayed = entry.lastPlayedAt else { return "Unknown" }
        let calendar = Calendar.current
        if calendar.isDateInToday(lastPlayed) { return "Today" }
        if calendar.isDateInYesterday(lastPlayed) { return "Yesterday" }
        return lastPlayed.formatted(.dateTime.month(.abbreviated).day())
    }
}
