import SwiftUI

struct Input: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var isDisabled: Bool = false
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.surfaceLight, lineWidth: 1)
        )
        .foregroundColor(AppColors.textPrimary)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

struct TextArea: View {
    let placeholder: String
    @Binding var text: String
    var isDisabled: Bool = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(AppColors.textMuted)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
            
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .background(AppColors.clear)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
        .frame(minHeight: 100)
        .background(AppColors.surface)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppColors.surfaceLight, lineWidth: 1)
        )
        .foregroundColor(AppColors.textPrimary)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
}

#Preview {
    VStack(spacing: 16) {
        Input(placeholder: "Enter your name", text: .constant(""))
        Input(placeholder: "Enter your email", text: .constant("john@example.com"))
        Input(placeholder: "Password", text: .constant(""), isSecure: true)
        Input(placeholder: "Disabled input", text: .constant("Cannot edit"), isDisabled: true)
        TextArea(placeholder: "Enter description", text: .constant(""))
    }
    .padding()
    .background(AppColors.background)
}
