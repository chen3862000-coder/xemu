import SwiftUI

struct Progress: View {
    var value: Double
    var maxValue: Double = 100
    var color: Color = AppColors.primary
    var trackColor: Color = AppColors.primary.opacity(0.2)
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 999)
                    .fill(trackColor)
                
                RoundedRectangle(cornerRadius: 999)
                    .fill(color)
                    .frame(width: progressWidth(geometry: geometry))
            }
        }
        .frame(height: 8)
    }
    
    private func progressWidth(geometry: GeometryProxy) -> CGFloat {
        let percentage = min(max(value / maxValue, 0), 1)
        return geometry.size.width * percentage
    }
}

#Preview {
    VStack(spacing: 16) {
        Progress(value: 75)
        Progress(value: 50, color: AppColors.success)
        Progress(value: 25, color: AppColors.warning)
        Progress(value: 100, color: AppColors.error)
    }
    .padding()
    .background(AppColors.background)
}
