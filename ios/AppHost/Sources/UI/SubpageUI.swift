import SwiftUI

enum SubpageUI {
    enum Font {
        static let title = SwiftUI.Font.system(size: 22, weight: .bold)
        static let heroTitle = SwiftUI.Font.system(size: 30, weight: .bold)
        static let subtitle = SwiftUI.Font.system(size: 13, weight: .medium)
        static let sectionTitle = SwiftUI.Font.system(size: 15, weight: .semibold)
        static let body = SwiftUI.Font.system(size: 13, weight: .medium)
    }

    enum Radius {
        static let searchField: CGFloat = 22
        static let sectionCard: CGFloat = 16
        static let gameCard: CGFloat = 14
        static let listRow: CGFloat = 16
        static let popup: CGFloat = 22
    }

    enum Spacing {
        static let headerHorizontal: CGFloat = 16
        static let sectionVertical: CGFloat = 12
    }

    static let sectionBorderOpacity: Double = 0.55
    static let cardShadowOpacity: Double = 0.08
}

struct SubpageSectionHeader: View {
    let title: String
    let trailing: String?

    init(_ title: String, trailing: String? = nil) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Text(title)
                .font(SubpageUI.Font.sectionTitle)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.primary)
            }
        }
    }
}

private struct SubpageSearchFieldModifier: ViewModifier {
    let cornerRadius: CGFloat
    let height: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .frame(height: height)
            .background(AppColors.surfaceLight.opacity(0.45))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.surfaceLight.opacity(0.7), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

private struct SubpageCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(AppColors.surface)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.surfaceLight.opacity(SubpageUI.sectionBorderOpacity), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(shadowOpacity), radius: 10, x: 0, y: 6)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

private struct SubpagePopupModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColors.surface.opacity(0.95))
                    .overlay(.ultraThinMaterial.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.surfaceLight.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: AppColors.primary.opacity(0.10), radius: 20, x: 0, y: 10)
    }
}

extension View {
    func subpageSearchField(cornerRadius: CGFloat = SubpageUI.Radius.searchField, height: CGFloat = 44) -> some View {
        modifier(SubpageSearchFieldModifier(cornerRadius: cornerRadius, height: height))
    }

    func subpageCard(cornerRadius: CGFloat = SubpageUI.Radius.sectionCard, shadowOpacity: Double = SubpageUI.cardShadowOpacity) -> some View {
        modifier(SubpageCardModifier(cornerRadius: cornerRadius, shadowOpacity: shadowOpacity))
    }

    func subpagePopup(cornerRadius: CGFloat = SubpageUI.Radius.popup) -> some View {
        modifier(SubpagePopupModifier(cornerRadius: cornerRadius))
    }
}
