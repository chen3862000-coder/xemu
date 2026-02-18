import SwiftUI

struct Toggle: View {
    @Binding var isOn: Bool
    var isDisabled: Bool = false
    var onColor: Color = AppColors.primary
    
    var body: some View {
        Button(action: {
            if !isDisabled {
                isOn.toggle()
            }
        }) {
            ZStack {
                Capsule()
                    .fill(isOn ? onColor : AppColors.surfaceLight)
                    .frame(width: 51, height: 31)
                
                Circle()
                    .fill(Color.white)
                    .frame(width: 27, height: 27)
                    .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
                    .offset(x: isOn ? 10 : -10)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

#Preview {
    VStack(spacing: 16) {
        Toggle(isOn: .constant(true), onColor: AppColors.primary)
        Toggle(isOn: .constant(false), onColor: AppColors.primary)
        Toggle(isOn: .constant(true), onColor: AppColors.success)
        Toggle(isOn: .constant(true), isDisabled: true)
    }
    .padding()
    .background(AppColors.background)
}
