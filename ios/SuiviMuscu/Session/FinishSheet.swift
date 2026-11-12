import SwiftUI
import SuiviCore

/// Bilan de fin de séance : durée (de 5 en 5), ressenti facultatif et notes.
struct FinishSheet: View {
    let session: Session
    let onSave: (_ durationMin: Int, _ rpe: Int?, _ notes: String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var duration: Double
    @State private var rpe: Int?
    @State private var notes: String

    init(session: Session, onSave: @escaping (_ durationMin: Int, _ rpe: Int?, _ notes: String?) -> Void) {
        self.session = session
        self.onSave = onSave
        // Durée saisie gardée telle quelle ; sinon début → maintenant, arrondi aux 5 minutes.
        _duration = State(initialValue: Double(Stats.finishPrefillMinutes(session, now: Date())))
        _rpe = State(initialValue: session.rpe)
        _notes = State(initialValue: session.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Bilan de la séance")
                    .font(Theme.font(.title3, weight: .semibold))
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { dismiss() } label: {
                    AppIcon.close.image
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: Theme.minTouch, height: Theme.minTouch)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel("Fermer")
            }
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        label("Durée")
                        Stepper(label: "Durée", unit: "min", step: 5, value: $duration, range: 5...240)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        label("Ressenti global (1 = facile, 10 = à fond), facultatif")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5),
                                  spacing: 8) {
                            ForEach(1...10, id: \.self) { n in rpeButton(n) }
                        }
                        .sensoryFeedback(.selection, trigger: rpe)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        label("Notes (douleurs, machine prise, réglages du siège…)")
                        TextField("", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                            .font(Theme.font(.body))
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.75)))
                            .accessibilityLabel("Notes")
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)

            Button {
                let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                onSave(Int(duration), rpe, trimmed.isEmpty ? nil : trimmed)
            } label: {
                Text(session.endedAt == nil ? "Terminer" : "Enregistrer")
                    .font(Theme.font(.headline, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(Capsule().fill(Theme.ink))
            }
            .buttonStyle(PressableStyle())
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 16)
        .foregroundStyle(Theme.ink)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(hex: 0xE9EEEC))
        .presentationCornerRadius(Theme.cardRadius)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(.subheadline, weight: .medium))
            .foregroundStyle(Theme.ink2)
    }

    private func rpeButton(_ n: Int) -> some View {
        let active = rpe == n
        return Button {
            // Toucher la valeur choisie la retire : le ressenti reste facultatif.
            rpe = active ? nil : n
        } label: {
            Text("\(n)")
                .font(Theme.font(.headline, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(active ? Color.white : Theme.ink)
                .frame(maxWidth: .infinity, minHeight: Theme.minTouch)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(active ? Theme.ink : Color.white.opacity(0.75)))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Ressenti \(n) sur 10")
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}
