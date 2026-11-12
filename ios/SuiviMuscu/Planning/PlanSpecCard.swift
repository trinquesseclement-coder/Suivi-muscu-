import SwiftUI
import SuiviCore

/// Un exercice de l'éditeur de séance planifiée (reprend la carte `ex-card` de `PlanEditor.tsx`).
/// Pour une seule personne : son schéma et ses valeurs ; pour les deux : aucune charge affichée,
/// chacun aura les siennes.
struct PlanSpecCard: View {
    @Binding var spec: PlanSpec
    let exercise: Exercise
    /// La séance n'a qu'un propriétaire (sinon : « Les deux »).
    let single: Bool
    /// « Aide Jules » quand l'exercice demande de l'aide à l'une des personnes, sinon `nil`.
    let helpLabel: String?
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMove: (_ offset: Int) -> Void
    let onRemove: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            head
            if typeSize.isAccessibilitySize {
                // En très grand texte, les boutons passent sous le nom pour lui laisser la largeur.
                HStack(spacing: 0) { Spacer(minLength: 0); buttons }
                    .padding(.top, -8)
            }
            Divider().overlay(Theme.ink.opacity(0.08))
            settings
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay {
            if helpLabel != nil {
                // Liseré orange à gauche, comme la carte de séance, pour les exercices avec aide.
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(.clear)
                    .overlay(alignment: .leading) { Rectangle().fill(Theme.orange).frame(width: 5) }
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                    .allowsHitTesting(false)
            }
        }
        .glassCard()
    }

    // MARK: En-tête

    private var head: some View {
        HStack(alignment: .top, spacing: 12) {
            ExerciseThumb(exercise: exercise, size: 48)
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(Theme.font(.headline, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                FlowLayout(spacing: 6) { badges }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !typeSize.isAccessibilitySize {
                buttons.padding(.top, -6).padding(.trailing, -8)
            }
        }
    }

    @ViewBuilder private var badges: some View {
        switch exercise.posture {
        case .fauteuil: Pill(text: "Fauteuil", icon: .wheelchair, fill: Theme.profile1.opacity(0.18))
        case .transfert: Pill(text: "Transfert")
        case .debout: Pill(text: "Debout")
        }
        if let helpLabel {
            Pill(text: helpLabel, icon: .help, fill: Theme.profile2.opacity(0.16))
        }
    }

    private var buttons: some View {
        HStack(spacing: 0) {
            iconButton(.up, label: "Monter", enabled: canMoveUp) { onMove(-1) }
            iconButton(.down, label: "Descendre", enabled: canMoveDown) { onMove(1) }
            iconButton(.close, label: "Retirer", enabled: true, action: onRemove)
        }
    }

    private func iconButton(_ icon: AppIcon, label: String, enabled: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            icon.image
                .font(Theme.icon(16, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: Theme.minTouch, height: Theme.minTouch)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel("\(label) \(exercise.name)")
    }

    // MARK: Réglages

    @ViewBuilder private var settings: some View {
        if exercise.kind == .cardio {
            labeled("Durée") {
                Stepper(label: "Minutes", unit: "min", step: 5, value: minutes, range: 5...240)
            }
        } else if !single {
            line("Charges de la dernière fois de chacun", icon: .together)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                SchemeToggle(scheme: spec.scheme ?? .classic) { spec.scheme = $0 }
                    .padding(.vertical, -6)
                    // Taille fixe : plafonnée pour tenir dans la carte en très grand texte.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                if (spec.scheme ?? .classic) == .pyramid {
                    line("12 · 10 · 8 · 12, charges de la dernière fois", icon: .pyramid)
                } else {
                    classic
                }
            }
        }
    }

    /// Trois steppers côte à côte s'il y a la place, sinon « Séries » et « Reps » puis « Charge ».
    private var classic: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 8) {
                setsStepper.frame(minWidth: 132)
                repsStepper.frame(minWidth: 132)
                loadStepper.frame(minWidth: 132)
            }
            VStack(spacing: 10) {
                HStack(alignment: .top, spacing: 8) { setsStepper; repsStepper }
                loadStepper
            }
        }
    }

    private var setsStepper: some View {
        labeled("Séries") { Stepper(label: "Séries", unit: "", step: 1, value: intBinding(\.sets), range: 1...20) }
    }

    private var repsStepper: some View {
        labeled("Reps") { Stepper(label: "Répétitions", unit: "", step: 1, value: intBinding(\.reps), range: 1...50) }
    }

    private var loadStepper: some View {
        labeled("Charge") {
            Stepper(label: "Charge", unit: "kg", step: exercise.step ?? 2.5, value: $spec.kg)
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(Theme.font(.footnote, weight: .medium))
                .foregroundStyle(Theme.ink2)
                .padding(.leading, 4)
                .accessibilityHidden(true)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(_ text: String, icon: AppIcon) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            icon.image.font(Theme.icon(13, weight: .semibold))
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(Theme.font(.subheadline))
        .foregroundStyle(Theme.ink2)
    }

    private var minutes: Binding<Double> { intBinding(\.minutes) }

    private func intBinding(_ key: WritableKeyPath<PlanSpec, Int>) -> Binding<Double> {
        Binding(get: { Double(spec[keyPath: key]) },
                set: { spec[keyPath: key] = Int($0.rounded()) })
    }
}
