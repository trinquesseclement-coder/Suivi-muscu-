import SwiftUI
import Charts
import SuiviCore

/// Une série de barres : une personne, une valeur par semaine, dans sa couleur.
struct BarSeries: Identifiable, Equatable {
    let id: String
    let name: String
    let color: Color
    let values: [Double]
    /// Libellé au-dessus de chaque barre (les heures), `nil` pour ne rien écrire.
    var labels: [String?]? = nil
}

extension BarSeries {
    /// Libellé seulement sur la dernière semaine non nulle (« 8,6 t »), comme le web.
    static func lastLabel(_ values: [Double], _ format: (Double) -> String) -> [String?] {
        let last = values.lastIndex { $0 > 0 }
        return values.indices.map { $0 == last ? format(values[$0]) : nil }
    }
}

/// Barres par semaine (séances et heures, tonnage, cardio) : un seul graphique pour les trois.
/// Les barres poussent depuis 0, semaine après semaine, à l'apparition et à chaque changement
/// de données (changement de personne) ; un simple fondu avec « Réduire les animations ».
struct WeekBarsChart: View {
    /// Lundis des semaines (YYYY-MM-DD), de la plus ancienne à la plus récente.
    let weeks: [String]
    let series: [BarSeries]
    /// Graduation de l'axe vertical : « 5 t », « 15 ».
    let axisLabel: (Double) -> String
    /// Graduations imposées (nombres entiers de séances) ; automatiques sinon.
    var ticks: [Double]? = nil
    /// Résumé lu par VoiceOver (« Cette semaine : 2 séances »).
    let accessibilityTitle: String
    let accessibilitySummary: String

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 170
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: [String: Double] = [:]
    @State private var visible = false

    private func key(_ s: BarSeries, _ week: String) -> String { "\(s.id)|\(week)" }

    /// Échelle fixée sur les vraies valeurs (pas sur les barres en train de pousser),
    /// avec de la place au-dessus pour les libellés.
    private var top: Double {
        let m = series.flatMap(\.values).max() ?? 0
        return m > 0 ? m * 1.22 : 1
    }

    /// Une semaine sur deux, en finissant par la plus récente : les dates ne se touchent pas.
    private var labelledWeeks: [String] {
        weeks.enumerated().filter { (weeks.count - 1 - $0.offset) % 2 == 0 }.map(\.element)
    }

    @AxisMarkBuilder private func yAxisMark(_ value: AxisValue) -> some AxisMark {
        AxisGridLine().foregroundStyle(Theme.ink.opacity(0.1))
        AxisValueLabel {
            if let v = value.as(Double.self) {
                // Largeur fixe : les graphiques de semaines restent alignés d'une carte à l'autre.
                Text(axisLabel(v)).font(Theme.font(.caption2)).foregroundStyle(Theme.ink2)
                    .frame(minWidth: 30, alignment: .trailing)
            }
        }
    }

    @ChartContentBuilder private func bar(_ s: BarSeries, _ i: Int, _ week: String) -> some ChartContent {
        let value = shown[key(s, week)] ?? 0
        BarMark(x: .value("Semaine", week), y: .value("Valeur", value), width: .ratio(0.62))
            .foregroundStyle(s.color)
            .cornerRadius(4)
            .position(by: .value("Personne", s.id))
            .annotation(position: .top, spacing: 3) {
                if let text = s.labels?[i], value > 0 {
                    Text(text)
                        .font(Theme.font(.caption2, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize()
                }
            }
    }

    var body: some View {
        Chart {
            ForEach(series) { s in
                ForEach(Array(weeks.enumerated()), id: \.offset) { i, week in
                    bar(s, i, week)
                }
            }
        }
        .chartYScale(domain: 0...top)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel(centered: true, collisionResolution: .disabled) {
                    if let w = value.as(String.self), labelledWeeks.contains(w) {
                        Text(Format.dayMonth(w)).font(Theme.font(.caption2)).foregroundStyle(Theme.ink2)
                            .fixedSize()
                    }
                }
            }
        }
        .chartYAxis {
            if let ticks {
                AxisMarks(position: .leading, values: ticks) { value in yAxisMark(value) }
            } else {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in yAxisMark(value) }
            }
        }
        .chartLegend(.hidden)
        .frame(height: height)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .opacity(visible ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(accessibilitySummary)
        .task(id: series) {
            await grow(groups: weeks.enumerated().map { i, w in series.map { (key($0, w), $0.values[i]) } },
                       into: $shown, visible: $visible, reduceMotion: reduceMotion)
        }
    }
}

/// Fait pousser des valeurs depuis 0, groupe après groupe, au rythme de `Motion.stagger`
/// (chaque groupe avec `Motion.spring`, 350 ms). Avec « Réduire les animations », les valeurs
/// arrivent d'un coup et le graphique apparaît en fondu. Rien n'est bloqué pendant ce temps.
@MainActor
func grow(groups: [[(String, Double)]], into shown: Binding<[String: Double]>, visible: Binding<Bool>,
          reduceMotion: Bool) async {
    let all = Dictionary(groups.flatMap { $0 }, uniquingKeysWith: { _, b in b })
    if reduceMotion {
        shown.wrappedValue = all
        withAnimation(Motion.reduced) { visible.wrappedValue = true }
        return
    }
    var noAnimation = Transaction()
    noAnimation.disablesAnimations = true
    withTransaction(noAnimation) {
        shown.wrappedValue = all.mapValues { _ in 0 }
        visible.wrappedValue = true
    }
    for group in groups {
        if Task.isCancelled { return }
        withAnimation(Motion.spring) {
            for (k, v) in group { shown.wrappedValue[k] = v }
        }
        try? await Task.sleep(for: .milliseconds(60))
    }
}
