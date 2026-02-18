import SwiftUI

struct Tabs: View {
    let tabs: [String]
    @Binding var selectedIndex: Int
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedIndex = index
                    }
                }) {
                    VStack(spacing: 8) {
                        Text(tabs[index])
                            .font(.system(size: 14, weight: selectedIndex == index ? .semibold : .regular))
                            .foregroundColor(selectedIndex == index ? AppColors.primary : AppColors.textMuted)
                        
                        Rectangle()
                            .fill(selectedIndex == index ? AppColors.primary : AppColors.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct TabContent<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
    }
}

#Preview {
    VStack {
        Tabs(tabs: ["Games", "Emulators", "Settings"], selectedIndex: .constant(0))
        
        Spacer()
    }
    .background(AppColors.background)
}
