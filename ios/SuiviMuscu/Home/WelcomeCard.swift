import SwiftUI

/// Première ouverture, aucune séance : dit quoi faire et pourquoi, avec le bouton pour commencer.
/// Sous la carte du cycle (`withCycle`), le bouton devient un lien discret vers une séance libre.
struct WelcomeCard: View {
    var zoom: Namespace.ID? = nil
    var withCycle = false
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                AppIcon.sessions.image
                    .font(Theme.icon(20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.ink))
                    .accessibilityHidden(true)
                Text("Ta première séance")
                    .font(Theme.font(.title3, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 10) {
                if withCycle {
                    tip("Fais les séances du cycle dans l’ordre : la suivante t’attend juste au-dessus.")
                } else {
                    tip("Ajoute tes machines au fur et à mesure, avec le filtre « Depuis le fauteuil ».")
                }
                tip("Valide chaque série d’un appui : le repos démarre tout seul.")
                tip("La prochaine fois, tes charges seront déjà remplies.")
            }
            if withCycle {
                Button(action: onStart) {
                    Text("Ou lancer une séance libre")
                        .font(Theme.font(.subheadline, weight: .semibold))
                        .underline()
                        .foregroundStyle(Theme.ink2)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                        .contentShape(Rectangle())
                        .zoomSource("free", in: zoom)
                }
                .buttonStyle(PressableStyle())
                .padding(.bottom, -8)
            } else {
                Button(action: onStart) {
                    HStack(spacing: 8) {
                        AppIcon.play.image.font(Theme.icon(13, weight: .bold))
                        Text("Commencer une séance")
                    }
                    .font(Theme.font(.headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(Theme.orange))
                    .zoomSource("free", in: zoom)
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .glassCard()
    }

    private func tip(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            AppIcon.check.image
                .font(Theme.icon(12, weight: .bold))
                .foregroundStyle(Theme.profile1)
                .accessibilityHidden(true)
            Text(text)
                .font(Theme.font(.subheadline))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
