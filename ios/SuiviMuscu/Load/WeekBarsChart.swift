import SwiftUI
import Charts
import SuiviCore

/// Une série de barres : une personne, une valeur par semaine, dans sa couleur.
struct BarSeries: Identifiable, Hashable {
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
/// Les barres poussent depuis 0, semaine après semaine, quand le graphique arrive à l'écran et à chaque
/// changement de données (personne, « Avec … ») ; un fondu enchaîné avec « Réduire les animations ».
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
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var shown: [String: Double] = [:]
    @State private var visible = false
    @State private var width: CGFloat = 0

    /// Plafond du texte dans le graphique (le tableau prend le relais au-delà).
    private static let maxType = DynamicTypeSize.xLarge
    /// Place prise par l'axe vertical (libellés de 30 pt et leur marge).
    private static let yAxisWidth: CGFloat = 38

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

    /// Comment écrire les libellés au-dessus des barres sans qu'ils se touchent : en gras s'ils
    /// tiennent dans la largeur d'une semaine, sinon en maigre, sinon une semaine sur deux.
    private var labelStyle: (weight: Font.Weight, everyOther: Bool) {
        let texts = series.flatMap { $0.labels ?? [] }.compactMap { $0 }
        guard !texts.isEmpty, width > 0, !weeks.isEmpty else { return (.bold, false) }
        let slot = (width - Self.yAxisWidth) / CGFloat(weeks.count) - 4
        let size = min(typeSize, Self.maxType)
        func widest(_ bold: Bool) -> CGFloat { texts.map { Self.textWidth($0, bold: bold, size: size) }.max() ?? 0 }
        if widest(true) <= slot { return (.bold, false) }
        if widest(false) <= slot { return (.regular, false) }
        return (.regular, true)
    }

    /// Largeur d'un libellé en `caption2` arrondi, à la taille de texte donnée.
    private static func textWidth(_ text: String, bold: Bool, size: DynamicTypeSize) -> CGFloat {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        var font = UIFont.preferredFont(forTextStyle: .caption2, compatibleWith: traits)
        if let d = font.fontDescriptor.withDesign(.rounded) { font = UIFont(descriptor: d, size: font.pointSize) }
        if bold, let d = font.fontDescriptor.withSymbolicTraits(.traitBold) {
            font = UIFont(descriptor: d, size: font.pointSize)
        }
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
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

    @ChartContentBuilder private func bar(_ s: BarSeries, _ i: Int, _ week: String,
                                          style: (weight: Font.Weight, everyOther: Bool)) -> some ChartContent {
        // Avec « Réduire les animations », pas de pousse : les vraies valeurs, en fondu.
        let value = reduceMotion ? s.values[i] : (shown[key(s, week)] ?? 0)
        let skipped = style.everyOther && (weeks.count - 1 - i) % 2 != 0
        BarMark(x: .value("Semaine", week), y: .value("Valeur", value), width: .ratio(0.62))
            .foregroundStyle(s.color)
            .cornerRadius(4)
            .position(by: .value("Personne", s.id))
            .annotation(position: .top, spacing: 3) {
                if let text = s.labels?[i], value > 0, !skipped {
                    Text(text)
                        .font(Theme.font(.caption2, weight: style.weight))
                        .foregroundStyle(Theme.ink)
                        .fixedSize()
                }
            }
    }

    private var chart: some View {
        let style = labelStyle
        return Chart {
            ForEach(series) { s in
                ForEach(Array(weeks.enumerated()), id: \.offset) { i, week in
                    bar(s, i, week, style: style)
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
    }

    var body: some View {
        ZStack {
            // En mode réduit, changer de données remplace le graphique par un fondu enchaîné.
            chart.id(reduceMotion ? series : [])
                .transition(.opacity)
        }
        .animation(reduceMotion ? Motion.reduced : nil, value: series)
        .frame(height: height)
        .onGeometryChange(for: CGFloat.self, of: { $0.size.width }) { width = $0 }
        .dynamicTypeSize(...Self.maxType)
        .opacity(visible ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(accessibilitySummary)
        .chartEntrance(key: series, reset: { shown = [:]; visible = false }) { reduce in
            await grow(groups: weeks.enumerated().map { i, w in series.map { (key($0, w), $0.values[i]) } },
                       into: $shown, visible: $visible, reduceMotion: reduce)
        }
    }
}

/// Fait pousser des valeurs depuis 0, groupe après groupe, au rythme de `Motion.stagger`
/// (chaque groupe avec `Motion.spring`, 350 ms). Avec « Réduire les animations », le graphique
/// (qui montre alors directement ses vraies valeurs) apparaît en fondu. Rien n'est bloqué.
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
