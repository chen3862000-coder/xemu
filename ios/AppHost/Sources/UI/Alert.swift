import SwiftUI

struct AppAlert: View {
    let title: String
    let message: String
    var variant: AlertVariant = .info
    
    enum AlertVariant {
        case info
        case success
        case warning
        case error
        
        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .info: return AppColors.info
            case .success: return AppColors.success
            case .warning: return AppColors.warning
            case .error: return AppColors.error
            }
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: variant.icon)
                .font(.system(size: 20))
                .foregroundColor(variant.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(16)
        .background(AppColors.surface)
        .cornerRadius(8)
    }
}

#Preview {
    VStack(spacing: 16) {
        AppAlert(title: "Info", message: "This is an informational message.", variant: .info)
        AppAlert(title: "Success", message: "Operation completed successfully.", variant: .success)
        AppAlert(title: "Warning", message: "Please review your settings.", variant: .warning)
        AppAlert(title: "Error", message: "An error occurred while processing.", variant: .error)
    }
    .padding()
    .background(AppColors.background)
}
