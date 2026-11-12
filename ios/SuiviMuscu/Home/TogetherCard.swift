import SwiftUI
import SuiviCore

/// Bloc « Ensemble » : jours où les deux ont une séance qui compte, et leur temps cumulé.
struct TogetherCard: View {
    let days: Int
    let minutes: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                AppIcon.together.image
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.profile1)
                Text("Ensemble")
                    .font(Theme.font(.caption, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(Theme.ink2)
            }
            message
                .font(Theme.font(.body))
                .contentTransition(.numericText(value: Double(days)))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
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
