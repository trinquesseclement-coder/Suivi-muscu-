import SwiftUI
import SuiviCore

/// Bloc « Ensemble » : jours où les deux ont une séance qui compte, et leur temps cumulé.
struct TogetherCard: View {
    let days: Int
    let minutes: Int

    var body: some View {
        HStack(spacing: 12) {
            AppIcon.together.image
                .font(Theme.icon(16, weight: .semibold))
                .foregroundStyle(Theme.profile1)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.profile1.opacity(0.14)))
            VStack(alignment: .leading, spacing: 1) {
                Text("Ensemble")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
                message
                    .font(Theme.font(.subheadline, weight: days == 0 ? .regular : .medium))
                    .contentTransition(.numericText(value: Double(days)))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassCard()
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var message: some View {
        if days == 0 {
            Text("Pas encore de séance à deux cette semaine")
        } else {
            let count = Text(days > 1 ? "\(days) séances" : "1 séance").fontWeight(.bold)
            let done = days > 1 ? "faites" : "faite"
            Text("\(count) \(done) à deux · \(Stats.formatHours(minutes)) au total")
        }
    }
}
