import SwiftUI
import Charts
import SuiviCore

/// Mesure affichée pour une machine de muscu.
enum LoadMeasure: String, CaseIterable, Hashable {
    case top, e1rm, tonnage

    var label: String {
        switch self {
        case .top: "Charge max"
        case .e1rm: "1RM estimé"
        case .tonnage: "Tonnage"
        }
    }
}

struct ProgressPoint: Equatable {
    let date: String
    let value: Double
}

/// Courbe d'une machine pour une personne, avec ses points et la dernière valeur écrite.
/// Elle se dessine de gauche à droite à l'apparition et au changement de personne ; changer de mesure
/// ou de machine fait glisser la courbe vers les nouvelles valeurs.
struct ProgressChart: View {
    let points: [ProgressPoint]
    let color: Color
    let format: (Double) -> String
    /// En changer redessine la courbe depuis la gauche (la personne affichée).
    let revealKey: String
    let accessibilityTitle: String

    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 180
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var reveal: CGFloat = 0

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value)
        let lo = values.min() ?? 0, hi = values.max() ?? 1
        let pad = hi > lo ? (hi - lo) * 0.2 : max(1, hi * 0.15)
        return max(0, lo - pad)...(hi + pad)
    }

    /// Séances écrites sous l'axe : la première, celle du milieu et la dernière.
    private var labelled: Set<Int> {
        points.count > 2 ? [0, points.count / 2, points.count - 1] : Set(points.indices)
    }

    /// Une séance par cran, à intervalles réguliers (deux séances le même jour restent distinctes).
    @ChartContentBuilder private func mark(_ i: Int, _ p: ProgressPoint) -> some ChartContent {
        LineMark(x: .value("Séance", "\(i)"), y: .value("Valeur", p.value))
            .foregroundStyle(color)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        PointMark(x: .value("Séance", "\(i)"), y: .value("Valeur", p.value))
            .symbol {
                Circle().fill(color)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                    .frame(width: 9, height: 9)
            }
    }

    var body: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { i, p in
                mark(i, p)
            }
            if let last = points.last {
                PointMark(x: .value("Séance", "\(points.count - 1)"), y: .value("Valeur", last.value))
                    .opacity(0)
                    .annotation(position: .top, spacing: 6,
                                overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        Text(format(last.value))
                            .font(Theme.font(.caption, weight: .bold))
                            .foregroundStyle(Theme.ink)
                            .fixedSize()
                    }
            }
        }
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel(centered: true, collisionResolution: .disabled) {
                    if let key = value.as(String.self), let i = Int(key), labelled.contains(i), i < points.count {
                        Text(Format.dayMonth(points[i].date)).font(Theme.font(.caption2)).foregroundStyle(Theme.ink2)
                            .fixedSize()
                    }
                }
            }
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(Theme.ink.opacity(0.1))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(format(v)).font(Theme.font(.caption2)).foregroundStyle(Theme.ink2)
                            .frame(minWidth: 40, alignment: .trailing)
                    }
                }
            }
        }
        .frame(height: height)
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .motion(Motion.spring, value: points)
        // Dessin de gauche à droite : un masque qui s'ouvre (fondu avec « Réduire les animations »).
        .mask(alignment: .leading) {
            GeometryReader { geo in
                Rectangle().frame(width: reduceMotion ? geo.size.width : geo.size.width * reveal)
            }
        }
        .opacity(reduceMotion ? reveal : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityTitle)
        .accessibilityValue(summary)
        .task(id: revealKey) {
            reveal = 0
            withAnimation(reduceMotion ? Motion.reduced : .easeOut(duration: 0.35)) { reveal = 1 }
        }
    }

    private var summary: String {
        guard let first = points.first, let last = points.last else { return "" }
        let n = points.count
        return "\(n) séance\(n > 1 ? "s" : ""), de \(format(first.value)) le \(Format.dayMonth(first.date)) "
            + "à \(format(last.value)) le \(Format.dayMonth(last.date))"
    }
}

/// Carte « Progression par machine » : le menu des machines faites, la mesure (muscu) et la courbe.
struct MachineProgressCard: View {
    let person: Profile
    let sessions: [Session]
    let byId: [String: Exercise]
    @Binding var machine: String?
    @Binding var measure: LoadMeasure
    var startsWithTable = false

    var body: some View {
        let ids = LoadStats.doneExerciseIds(sessions, ownerId: person.id)
        let selected = machine.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first
        if let selected, let exercise = byId[selected] {
            let data = series(for: exercise)
            ChartCard(title: "Progression par machine", startsWithTable: startsWithTable) {
                VStack(alignment: .leading, spacing: 8) {
                    menu(ids: ids, selected: exercise)
                    if exercise.kind == .muscu {
                        WhoPicker(options: LoadMeasure.allCases.map { ($0, $0.label) }, selection: $measure,
                                  font: Theme.font(.subheadline, weight: .semibold))
                    }
                }
            } content: {
                ProgressChart(points: data.points, color: Theme.color(for: person), format: data.format,
                              revealKey: person.id,
                              accessibilityTitle: "\(exercise.name), \(data.title)")
            } table: {
                DataTable(head: ["Date", data.title], rows: data.rows)
            }
        } else {
            ChartCard(title: "Progression par machine", empty: (.machines, "Pas encore fait")) {
                EmptyView()
            } table: {
                EmptyView()
            }
        }
    }

    private func menu(ids: [String], selected: Exercise) -> some View {
        Menu {
            Picker("Machine", selection: Binding(get: { selected.id }, set: { machine = $0 })) {
                ForEach(ids, id: \.self) { id in
                    Text(byId[id]?.name ?? id).tag(id)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text(selected.name)
                    .font(Theme.font(.body, weight: .semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                AppIcon.expand.image
                    .font(Theme.icon(14, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: Theme.minTouch, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: Theme.smallRadius, style: .continuous).fill(Theme.softFill))
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Machine")
        .accessibilityValue(selected.name)
    }

    /// Points (20 dernières séances, comme le web), format et lignes du tableau de la mesure choisie.
    private func series(for exercise: Exercise)
        -> (points: [ProgressPoint], format: (Double) -> String, title: String, rows: [[String]]) {
        if exercise.kind == .cardio {
            let h = LoadStats.cardioHistory(sessions, ownerId: person.id, exerciseId: exercise.id).suffix(20)
            let rows = h.map { pt -> [String] in
                var detail = "\(pt.minutes) min"
                if let km = pt.distanceKm, km > 0 { detail += " · \(Format.number(km)) km" }
                if let lvl = pt.level { detail += " · niv. \(lvl)" }
                return [Format.dayMonth(pt.date), detail]
            }
            return (h.map { ProgressPoint(date: $0.date, value: Double($0.minutes)) },
                    { "\(Format.number($0)) min" }, "Minutes", rows)
        }
        let h = LoadStats.history(sessions, ownerId: person.id, exerciseId: exercise.id).suffix(20)
        switch measure {
        case .top:
            return (h.map { ProgressPoint(date: $0.date, value: $0.topKg) }, { "\(Format.load($0)) kg" },
                    "Charge max",
                    h.map { [Format.dayMonth($0.date), "\(Format.load($0.topKg)) kg × \($0.topReps)"] })
        case .e1rm:
            return (h.map { ProgressPoint(date: $0.date, value: ($0.e1rm * 10).rounded() / 10) },
                    { "\(Format.number($0)) kg" }, "1RM estimé",
                    h.map { [Format.dayMonth($0.date), "\(Format.number($0.e1rm)) kg"] })
        case .tonnage:
            return (h.map { ProgressPoint(date: $0.date, value: $0.tonnage) }, { Format.tonnage($0) }, "Tonnage",
                    h.map { [Format.dayMonth($0.date), Format.tonnage($0.tonnage)] })
        }
    }
}
