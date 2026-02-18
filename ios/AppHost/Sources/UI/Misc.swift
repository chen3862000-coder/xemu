import SwiftUI

struct Separator: View {
    var orientation: Orientation = .horizontal
    
    enum Orientation {
        case horizontal
        case vertical
    }
    
    var body: some View {
        Group {
            if orientation == .horizontal {
                Divider()
                    .background(AppColors.surfaceLight)
            } else {
                Rectangle()
                    .fill(AppColors.surfaceLight)
                    .frame(width: 1)
            }
        }
    }
}

struct Avatar: View {
    let name: String
    var size: CGFloat = 40
    var imageURL: String? = nil
    
    var body: some View {
        ZStack {
            Circle()
                .fill(AppColors.primary.opacity(0.2))
            
            if let url = imageURL, let image = URL(string: url) {
                AsyncImage(url: image) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    
    private var initialsView: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundColor(AppColors.primary)
    }
    
    private var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return "\(components[0].prefix(1))\(components[1].prefix(1))".uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}

struct BadgeView: View {
    let text: String
    var variant: BadgeVariant = .default
    
    enum BadgeVariant {
        case `default`
        case secondary
        case destructive
        case outline
        
        var backgroundColor: Color {
            switch self {
            case .default: return AppColors.primary
            case .secondary: return AppColors.surfaceLight
            case .destructive: return AppColors.error
            case .outline: return AppColors.clear
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .default: return .white
            case .secondary: return AppColors.textSecondary
            case .destructive: return .white
            case .outline: return AppColors.textPrimary
            }
        }
        
        var borderColor: Color? {
            switch self {
            case .outline: return AppColors.surfaceLight
            default: return nil
            }
        }
    }
    
    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(variant.foregroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(variant.backgroundColor)
            .cornerRadius(999)
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(variant.borderColor ?? AppColors.clear, lineWidth: 1)
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        Separator()
            .frame(width: 200)
        
        HStack(spacing: 16) {
            Avatar(name: "John Doe")
            Avatar(name: "Jane Smith", size: 60)
            Avatar(name: "JD", size: 30)
        }
        
        HStack(spacing: 8) {
            BadgeView(text: "Default")
            BadgeView(text: "Secondary", variant: .secondary)
            BadgeView(text: "Destructive", variant: .destructive)
            BadgeView(text: "Outline", variant: .outline)
        }
    }
    .padding()
    .background(AppColors.background)
}
