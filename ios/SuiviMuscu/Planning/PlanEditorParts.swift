import SwiftUI
import SuiviCore

// Morceaux de l'éditeur de séance planifiée (`PlanEditorView`), sans logique propre.

/// « Pour qui » : contrôle segmenté de 48 pt, même style que le choix du schéma.
/// En très grand texte, les choix s'empilent pour que « Les deux » reste entier.
struct WhoPicker: View {
    let options: [(PlanTarget, String)]
    @Binding var selection: PlanTarget

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let stacked = typeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
        let radius: CGFloat = stacked ? Theme.cardRadius : 100
        return layout {
            ForEach(options, id: \.0) { value, title in
                let active = selection == value
                Button {
                    selection = value
                } label: {
                    Text(title)
                        .font(Theme.font(.body, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        // Le texte réduit ne touche jamais le bord de la pastille.
                        .padding(.horizontal, 10)
                        .foregroundStyle(active ? Color.white : Theme.ink2)
                        .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                        .background(Capsule().fill(active ? Theme.ink : Color.clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(active ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.glass))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(Theme.glassBorder, lineWidth: 1))
        .motion(Motion.spring, value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Bannière quand les exercices avec aide sont dispersés : propose de les regrouper.
struct HelpGroupingBanner: View {
    let count: Int
    /// Le prénom de l'aidant (« Jules »), s'il est connu.
    let helper: String?
    let onGroup: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                AppIcon.help.image.font(Theme.icon(16, weight: .semibold))
                (Text("\(count) exercices avec aide").bold()
                    + Text(helper.map { " (\($0) charge les disques) : les enchaîner évite de l’attendre." }
                        ?? " : les enchaîner évite d’attendre."))
                    .font(Theme.font(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: onGroup) {
                Text(helper.map { "Regrouper les exercices avec \($0)" } ?? "Regrouper les exercices avec aide")
                    .font(Theme.font(.subheadline, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                    .background(Capsule().fill(Theme.ink))
            }
            .buttonStyle(PressableStyle())
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
            .fill(Theme.helpTint))
        .foregroundStyle(Theme.ink)
    }
}

/// Barre du bas : « Supprimer » (séance existante, avec confirmation) et le bouton principal.
struct PlanEditorBottomBar: View {
    let label: String
    let enabled: Bool
    let showsDelete: Bool
    @Binding var confirmDelete: Bool
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if showsDelete {
                Button { confirmDelete = true } label: {
                    Text("Supprimer")
                        .font(Theme.font(.headline, weight: .semibold))
                        .foregroundStyle(Theme.destructive)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 22)
                        .frame(minHeight: 52)
                        .background(Capsule().fill(Theme.raisedFill))
                        .overlay(Capsule().strokeBorder(Theme.ink.opacity(0.1), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
                // Accrochée au bouton : la bulle de confirmation pointe vers lui.
                .confirmationDialog("Supprimer cette séance prévue ?", isPresented: $confirmDelete,
                                    titleVisibility: .visible) {
                    Button("Supprimer la séance", role: .destructive, action: onDelete)
                    Button("Annuler", role: .cancel) {}
                }
            }
            Button(action: onSave) {
                Text(label)
                    .font(Theme.font(.headline, weight: .semibold))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(Theme.ink.opacity(enabled ? 1 : 0.35)))
            }
            .buttonStyle(PressableStyle())
            .disabled(!enabled)
            .accessibilityHint(enabled ? "" : "Ajoute au moins un exercice")
        }
        .padding(5)
        .background(Capsule().fill(Theme.barFill))
        .overlay(Capsule().strokeBorder(Theme.glassBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 14, y: 6)
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 6)
        .background { BottomFade() }
    }
}
