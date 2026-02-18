import SwiftUI

struct Checkbox: View {
    @Binding var isChecked: Bool
    let label: String
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: {
            if !isDisabled {
                isChecked.toggle()
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isChecked ? AppColors.primary : AppColors.surfaceLight, lineWidth: 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(isChecked ? AppColors.primary : AppColors.clear)
                        )
                        .frame(width: 20, height: 20)
                    
                    if isChecked {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(isDisabled ? AppColors.textMuted : AppColors.textPrimary)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        Checkbox(isChecked: .constant(true), label: "Checked option")
        Checkbox(isChecked: .constant(false), label: "Unchecked option")
        Checkbox(isChecked: .constant(true), label: "Disabled checked", isDisabled: true)
        Checkbox(isChecked: .constant(false), label: "Disabled unchecked", isDisabled: true)
    }
    .padding()
    .background(AppColors.background)
}
