import SwiftUI

struct Dialog<Content: View>: View {
    let title: String
    let content: Content
    var isPresented: Binding<Bool>
    
    init(title: String, isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.isPresented = isPresented
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented.wrappedValue = false
                }
            
            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: {
                        isPresented.wrappedValue = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
                
                content
            }
            .frame(width: 400)
            .background(AppColors.surface)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 20)
        }
    }
}

struct Sheet<Content: View>: View {
    let content: Content
    var isPresented: Binding<Bool>
    var detents: SheetDetent = .medium
    
    enum SheetDetent {
        case small
        case medium
        case large
    }
    
    init(isPresented: Binding<Bool>, detents: SheetDetent = .medium, @ViewBuilder content: () -> Content) {
        self.isPresented = isPresented
        self.detents = detents
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented.wrappedValue = false
                }
            
            VStack {
                Spacer()
                
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.surfaceLight)
                        .frame(width: 36, height: 4)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    
                    content
                }
                .frame(maxHeight: maxHeight)
                .background(AppColors.surface)
                .cornerRadius(16)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }
    
    private var maxHeight: CGFloat {
        switch detents {
        case .small: return 200
        case .medium: return 400
        case .large: return .infinity
        }
    }
}

#Preview {
    VStack {
        Text("Preview Content")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppColors.background)
}
