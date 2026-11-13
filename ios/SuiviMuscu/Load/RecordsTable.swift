import SwiftUI
import SuiviCore

/// Carte « Records » d'une seule personne : Machine / Meilleure série / 1RM estimé / Date,
/// les 8 plus récents (comme le web). Quand les quatre colonnes ne tiennent plus (grand texte),
/// chaque record s'empile sur deux lignes.
struct RecordsTable: View {
    let person: Profile
    let sessions: [Session]
    let byId: [String: Exercise]

    private struct Row: Identifiable {
        let id: String
        let name: String
        let best: String
        /// « 50 kilos, 10 répétitions », pour VoiceOver.
        let bestSpoken: String
        let e1rm: String
        let date: String
    }

    private var rows: [Row] {
        LoadStats.records(sessions, ownerId: person.id).values
            .filter { byId[$0.exerciseId] != nil }
            .sorted { $0.date != $1.date ? $0.date > $1.date : $0.e1rm > $1.e1rm }
            .prefix(8)
            .map { pr in
                Row(id: pr.exerciseId, name: byId[pr.exerciseId]?.name ?? pr.exerciseId,
                    best: "\(Format.load(pr.kg)) × \(pr.reps)",
                    bestSpoken: "\(Format.load(pr.kg)) kilos, \(pr.reps) répétition\(pr.reps > 1 ? "s" : "")",
                    e1rm: Format.number(pr.e1rm),
                    date: Format.dayMonth(pr.date))
            }
    }

    var body: some View {
        let rows = rows
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Records")
                    .font(Theme.font(.headline, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                Text("Meilleur 1RM estimé par machine")
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.ink2)
            }
            if rows.isEmpty {
                ChartEmpty(icon: .trophy, text: "Pas encore de record")
            } else {
                ViewThatFits(in: .horizontal) {
                    grid(rows)
                    stacked(rows)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func grid(_ rows: [Row]) -> some View {
        Grid(alignment: .trailing, horizontalSpacing: 10, verticalSpacing: 0) {
            GridRow(alignment: .bottom) {
                header("Machine").gridColumnAlignment(.leading)
                    // Colonne souple : elle prend la place qui reste, mais au moins 110 pt.
                    .frame(minWidth: 110, idealWidth: 110, maxWidth: .infinity, alignment: .leading)
                header("Meilleure\nsérie")
                header("1RM\nestimé")
                header("Date")
            }
            .padding(.bottom, 6)
            ForEach(rows) { r in
                Divider().gridCellUnsizedAxes(.horizontal)
                GridRow(alignment: .firstTextBaseline) {
                    Text(r.name)
                        .font(Theme.font(.subheadline))
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(idealWidth: 110, maxWidth: .infinity, alignment: .leading)
                    Text(r.best).font(Theme.font(.subheadline, weight: .semibold)).fixedSize()
                    Text(r.e1rm).font(Theme.font(.subheadline, weight: .semibold)).fixedSize()
                    Text(r.date).font(Theme.font(.subheadline)).foregroundStyle(Theme.ink2).fixedSize()
                }
                .monospacedDigit()
                .padding(.vertical, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken(r))
            }
        }
    }

    private func stacked(_ rows: [Row]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { n, r in
                if n > 0 { Divider() }
                VStack(alignment: .leading, spacing: 2) {
                    Text(r.name).font(Theme.font(.subheadline, weight: .semibold))
                    Text("\(r.best) · 1RM \(r.e1rm) kg · \(r.date)")
                        .font(Theme.font(.subheadline))
                        .foregroundStyle(Theme.ink2)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(spoken(r))
            }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(.footnote, weight: .semibold))
            .foregroundStyle(Theme.ink2)
            .multilineTextAlignment(.trailing)
            .fixedSize()
    }

    private func spoken(_ r: Row) -> String {
        "\(r.name) : meilleure série \(r.bestSpoken), 1RM estimé \(r.e1rm) kilos, le \(r.date)"
    }
}
