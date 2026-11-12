import SwiftUI
import SuiviCore

/// « − valeur + » à gros boutons, utilisable d'une main. Ne descend jamais sous 0.
/// Pour VoiceOver, c'est un seul élément réglable (« Série 1 charge, 40 kg »).
struct Stepper: View {
    let label: String
    let unit: String
    let step: Double
    @Binding var value: Double
    /// Bornes facultatives (la durée du bilan va de 5 à 240 min). Le minimum n'est jamais sous 0.
    var range: ClosedRange<Double>? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            button(.minus, delta: -step)
            VStack(spacing: 0) {
                Text(Format.load(value))
                    .font(Theme.font(.title3, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: value))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if !unit.isEmpty {
                    Text(unit)
                        .font(Theme.font(.caption2))
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity)
            button(.add, delta: step)
        }
        .frame(minHeight: 56)
        .foregroundStyle(Theme.ink)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.62))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(unit.isEmpty ? Format.load(value) : "\(Format.load(value)) \(unit)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(by: step)
            case .decrement: change(by: -step)
            @unknown default: break
            }
        }
    }

    private func button(_ icon: AppIcon, delta: Double) -> some View {
        Button { change(by: delta) } label: {
            icon.image
                .font(.system(size: 17, weight: .bold))
                // Zone tactile fixe de 48 pt : c'est le chiffre au milieu qui rétrécit si la place manque.
                .frame(width: Theme.minTouch)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(StepperButtonStyle())
        .disabled(delta < 0 && value <= lower)
        .accessibilityLabel("\(label) \(delta < 0 ? "moins" : "plus") \(Format.load(step))")
    }

    private var lower: Double { max(0, range?.lowerBound ?? 0) }

    private func change(by delta: Double) {
        var next = ((value + delta) * 100).rounded() / 100
        next = max(lower, next)
        if let upper = range?.upperBound { next = min(upper, next) }
        guard next != value else { return }
        withAnimation(reduceMotion ? Motion.reduced : Motion.spring) { value = next }
    }
}

/// Assombrit légèrement le bouton au toucher, sans délai.
private struct StepperButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? (configuration.isPressed ? 0.45 : 1) : 0.25)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.ink.opacity(configuration.isPressed ? 0.08 : 0))
            )
    }
}
