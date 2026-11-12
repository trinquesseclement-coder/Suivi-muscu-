import SwiftUI
import Charts
import SuiviCore

/// Séries par muscle de la semaine en cours, en barres horizontales, avec la bande de repère
/// 10–20 séries. Les barres poussent l'une après l'autre (voir `grow`).
struct MuscleSetsChart: View {
    /// Muscles travaillés cette semaine (libellé, séries), dans l'ordre du catalogue.
    let rows: [(muscle: String, sets: Int)]
    let color: Color
    /// La personne affichée : en changer refait pousser les barres.
    let personId: String

    @ScaledMetric(relativeTo: .body) private var rowHeight: CGFloat = 30
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: [String: Double] = [:]
    @State private var visible = false

    static let band = 10.0...20.0

    private var top: Double { max(Self.band.upperBound + 4, Double(rows.map(\.sets).max() ?? 0) * 1.15) }

    var body: some View {
        Chart {
            RectangleMark(xStart: .value("Repère", Self.band.lowerBound), xEnd: .value("Repère", Self.band.upperBound))
                .foregroundStyle(Theme.ink.opacity(0.07))
            ForEach(rows, id: \.muscle) { row in
                let value = shown[row.muscle] ?? 0
                BarMark(x: .value("Séries", value), y: .value("Muscle", row.muscle), height: .ratio(0.6))
                    .foregroundStyle(color)
                    .cornerRadius(4)
                    .annotation(position: .trailing, spacing: 4) {
                        if value > 0 {
                            Text("\(row.sets)")
                                .font(Theme.font(.caption, weight: .bold))
                                .foregroundStyle(Theme.ink)
                                .monospacedDigit()
                        }
                    }
            }
        }
        .chartXScale(domain: 0...top)
        .chartXAxis {
            AxisMarks(values: [0, Self.band.lowerBound, Self.band.upperBound]) { value in
                AxisGridLine().foregroundStyle(Theme.ink.opacity(0.1))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))").font(Theme.font(.caption2)).foregroundStyle(Theme.ink2)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(preset: .extended, position: .leading) { value in
                AxisValueLabel {
                    if let m = value.as(String.self) {
                        Text(m).font(Theme.font(.caption, weight: .medium)).foregroundStyle(Theme.ink)
                    }
                }
            }
        }
        .frame(height: rowHeight * CGFloat(rows.count) + 28)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .opacity(visible ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Séries par muscle cette semaine")
        .accessibilityValue(rows.map { "\($0.muscle) \($0.sets)" }.joined(separator: ", "))
        .task(id: [personId] + rows.map { "\($0.muscle)\($0.sets)" }) {
            await grow(groups: rows.map { [($0.muscle, Double($0.sets))] }, into: $shown, visible: $visible,
                       reduceMotion: reduceMotion)
        }
    }
}
