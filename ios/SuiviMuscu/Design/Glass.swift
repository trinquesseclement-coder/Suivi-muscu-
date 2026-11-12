import SwiftUI

private struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.glass)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.glassBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
            .foregroundStyle(Theme.ink)
    }
}

extension View {
    /// Fond de carte en verre dépoli (coins de 26 pt).
    func glassCard() -> some View { modifier(GlassCard()) }
}
