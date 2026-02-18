import SwiftUI

struct Card<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(AppColors.surface)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(AppColors.surfaceLight.opacity(0.5), lineWidth: 1)
        )
    }
}

struct CardHeader<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.horizontal, 24)
            .padding(.top, 24)
    }
}

struct CardTitle: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(AppColors.textPrimary)
    }
}

struct CardDescription: View {
    let text: String
    
    init(_ text: String) {
        self.text = text
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(AppColors.textMuted)
    }
}

struct CardContent<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
    }
}

struct CardFooter<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        HStack {
            content
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

#Preview {
    Card {
        CardHeader {
            VStack(alignment: .leading, spacing: 4) {
                CardTitle("Card Title")
                CardDescription("This is a description of the card.")
            }
        }
        
        CardContent {
            Text("This is the main content of the card.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.textPrimary)
        }
        
        CardFooter {
            Text("Footer content")
                .font(.system(size: 12))
                .foregroundColor(AppColors.textMuted)
        }
    }
    .padding()
    .background(AppColors.background)
}
