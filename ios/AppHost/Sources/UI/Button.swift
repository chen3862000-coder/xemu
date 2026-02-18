import SwiftUI

struct ActionButton: View {
    enum Style {
        case primary
        case secondary
        case ghost
        case outline
    }
    
    let title: String
    let icon: String?
    let style: Style
    let action: () -> Void
    
    init(_ title: String, icon: String? = nil, style: Style = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(background)
            .foregroundColor(foreground)
            .cornerRadius(12)
        }
    }
    
    private var background: Color {
        switch style {
        case .primary:
            return AppColors.primary
        case .secondary:
            return AppColors.surfaceLight
        case .ghost:
            return Color.clear
        case .outline:
            return Color.clear
        }
    }
    
    private var foreground: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return AppColors.textPrimary
        case .ghost:
            return AppColors.primary
        case .outline:
            return AppColors.primary
        }
    }
}

struct IconButton: View {
    let icon: String
    let action: () -> Void
    
    init(_ icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(AppColors.textPrimary)
                .frame(width: 44, height: 44)
                .background(AppColors.surfaceLight)
                .cornerRadius(12)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ActionButton("Primary Button", icon: "play.fill", style: .primary) {}
        ActionButton("Secondary Button", icon: "gear", style: .secondary) {}
        ActionButton("Ghost Button", icon: "heart", style: .ghost) {}
        ActionButton("Outline Button", icon: "star", style: .outline) {}
        IconButton("gear") {}
    }
    .padding()
    .background(AppColors.background)
}
