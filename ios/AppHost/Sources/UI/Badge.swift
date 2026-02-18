import SwiftUI

enum BadgeVariant {
    case `default`
    case secondary
    case destructive
    case outline
}

struct Badge: View {
    let text: String
    let variant: BadgeVariant
    
    init(_ text: String, variant: BadgeVariant = .default) {
        self.text = text
        self.variant = variant
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(6)
    }
    
    private var backgroundColor: Color {
        switch variant {
        case .default:
            return AppColors.primary
        case .secondary:
            return AppColors.surfaceLight
        case .destructive:
            return AppColors.error
        case .outline:
            return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .default:
            return .white
        case .secondary:
            return AppColors.textSecondary
        case .destructive:
            return .white
        case .outline:
            return AppColors.textPrimary
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        Badge("Default")
        Badge("Secondary", variant: .secondary)
        Badge("Destructive", variant: .destructive)
        Badge("Outline", variant: .outline)
    }
    .padding()
}
