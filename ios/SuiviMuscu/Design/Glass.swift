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

/// Fondu vers le fond de l'écran, placé derrière les barres flottantes du bas :
/// le contenu qui défile s'efface au lieu de transparaître derrière les boutons.
struct BottomFade: View {
    var body: some View {
        LinearGradient(stops: [
            .init(color: Theme.backgroundBottom.opacity(0), location: 0),
            .init(color: Theme.backgroundBottom.opacity(0.9), location: 0.45),
            .init(color: Theme.backgroundBottom, location: 1),
        ], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }
}
