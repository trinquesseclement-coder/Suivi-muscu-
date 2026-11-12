import SwiftUI
import SuiviCore

/// Une série : numéro, charge, répétitions, et le gros bouton rond de validation.
struct SetRow: View {
    let index: Int
    let entry: SetEntry
    /// Pas de charge de l'exercice (2,5 kg par défaut).
    let step: Double
    let editable: Bool
    /// La série validée bat le record d'avant la séance.
    let isRecord: Bool
    let onKg: (Double) -> Void
    let onReps: (Int) -> Void
    let onToggle: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var number: Int { index + 1 }

    var body: some View {
        // Largeur à 375 pt : 375 − 2×12 (page) − 2×8 (ligne) = 335 ; − 14 (n°) − 56 (coche) − 3×4 = 253,
        // soit 126,5 pt par stepper : 2 boutons de 48 pt et 30,5 pt pour le chiffre.
        HStack(spacing: 4) {
            Text("\(number)")
                .font(Theme.font(.headline, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .frame(width: 14)
                .accessibilityHidden(true)
            if editable {
                Stepper(label: "Série \(number) charge", unit: "kg", step: step,
                        value: Binding(get: { entry.kg }, set: { onKg($0) }))
                Stepper(label: "Série \(number) répétitions", unit: "reps", step: 1,
                        value: Binding(get: { Double(entry.reps) }, set: { onReps(Int($0.rounded())) }))
                checkButton
            } else {
                readOnly
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(entry.done ? Theme.success.opacity(0.16) : Color.clear)
        .motion(Motion.spring, value: entry.done)
    }

    private var checkButton: some View {
        Button(action: onToggle) {
            (isRecord ? AppIcon.trophy : AppIcon.check).image
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(entry.done ? Color.white : Theme.ink.opacity(0.55))
                .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : entry.done)
                .frame(width: 56, height: 56)
                .background(Circle().fill(entry.done ? Theme.ink : Color.white.opacity(0.75)))
                .overlay(Circle().strokeBorder(Theme.ink.opacity(entry.done ? 0 : 0.28), lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(PressableStyle())
        .sensoryFeedback(.success, trigger: entry.done) { _, done in done }
        .accessibilityLabel(entry.done ? "Série \(number) faite" : "Valider la série \(number)")
        .accessibilityValue(isRecord ? "Record" : "")
        .accessibilityAddTraits(entry.done ? .isSelected : [])
    }

    private var readOnly: some View {
        HStack {
            Text("\(Format.load(entry.kg)) kg × \(entry.reps)")
                .font(Theme.font(.headline, weight: .semibold))
                .monospacedDigit()
            Spacer(minLength: 8)
            if isRecord {
                Pill(text: "Record", icon: .trophy, fill: Color(hex: 0xFAB219, opacity: 0.3))
            } else {
                Text(entry.done ? "fait" : "prévu")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
            }
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Série \(number) : \(Format.load(entry.kg)) kilos, \(entry.reps) répétitions, "
                            + (isRecord ? "record" : entry.done ? "faite" : "prévue"))
    }
}
