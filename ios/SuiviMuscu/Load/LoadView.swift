import SwiftUI
import SuiviCore

/// Onglet « Charge » : le tableau de charge d'une seule personne à la fois (« Moi » ou l'autre).
/// Aucun graphique ne met les kilos des deux côte à côte ; seules les séances et les heures
/// peuvent montrer les deux, avec l'interrupteur « Avec … » (reprend `appli/src/pages/Stats.tsx`).
struct LoadView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let weekCount = 8

    /// `false` : moi ; `true` : l'autre.
    @State private var showPartner = Launch.partner
    @State private var together = Launch.together

    var body: some View {
        let now = Date()
        let today = Dates.isoDate(now)
        let person = showPartner ? store.partner : store.me
        let other = showPartner ? store.me : store.partner
        let sessions = store.sessions
        let byId = store.exerciseAnyById
        let weeks = LoadStats.weeks(sessions, ownerId: person.id, byId: byId, count: Self.weekCount,
                                    today: today, now: now)
        let otherWeeks = LoadStats.weeks(sessions, ownerId: other.id, byId: byId, count: Self.weekCount,
                                         today: today, now: now)
        let personEmpty = weeks.allSatisfy { $0.sessions == 0 }
        let otherEmpty = otherWeeks.allSatisfy { $0.sessions == 0 }

        ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    WhoPicker(options: [(false, "Moi"), (true, store.partner.name)], selection: $showPartner)

                    if personEmpty && otherEmpty {
                        ChartCard(title: "Séances et heures par semaine",
                                  empty: (.sessions, Self.noSessionText)) {
                            EmptyView()
                        } table: { EmptyView() }
                    } else {
                        // Rien pour cette personne mais des séances pour l'autre : la carte des séances
                        // reste là, vide, avec son interrupteur « Avec … » ; les cartes de kilos sautent.
                        sessionsCard(person: person, weeks: weeks, other: other,
                                     otherWeeks: together ? otherWeeks : nil, personEmpty: personEmpty)
                        if !personEmpty {
                            tonnageCard(person: person, weeks: weeks).id("tonnage")
                            cardioCard(person: person, weeks: weeks)
                            muscleCard(person: person, week: weeks.last).id("muscles")
                        }
                    }

                    MachineProgressCard(person: person, sessions: sessions, byId: byId,
                                        initialMachine: Launch.machine, initialMeasure: Launch.measure,
                                        startsWithTable: Launch.table == "progress")
                        // Ancre de défilement seulement : la carte garde son état (machine par personne,
                        // mesure) quand on change de personne.
                        .id("progress")
                    RecordsTable(person: person, sessions: sessions, byId: byId).id("records")
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            // Mise au point : `-load-scroll` ouvre la page sur une carte.
            .task { if let anchor = Launch.scroll { reader.scrollTo(anchor, anchor: .top) } }
            // Mise au point : `-load-switch <secondes>` change de personne 4 fois à ce rythme (le
            // sélecteur est hors de l'écran quand on regarde les graphiques de kilos).
            .task {
                guard let seconds = Launch.switchEvery else { return }
                for _ in 0..<4 {
                    try? await Task.sleep(for: .seconds(seconds))
                    showPartner.toggle()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tableau de charge")
                .font(Theme.font(.title, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text("Les 8 dernières semaines")
                .font(Theme.font(.subheadline))
                .opacity(0.8)
        }
        .foregroundStyle(Theme.onBackground)
        .padding(.horizontal, 2)
        .padding(.bottom, 4)
    }

    private static let noSessionText = "Pas encore de séance ces 8 dernières semaines"

    // MARK: Cartes

    /// Séances (barres) et heures (libellés). Seul graphique qui peut montrer les deux personnes.
    private func sessionsCard(person: Profile, weeks: [WeekLoad], other: Profile, otherWeeks: [WeekLoad]?,
                              personEmpty: Bool) -> some View {
        let both = otherWeeks != nil
        var series = [BarSeries(id: person.id, name: person.name, color: Theme.color(for: person),
                                values: weeks.map { Double($0.sessions) },
                                // À deux, les barres sont trop étroites pour un libellé chacune.
                                labels: both ? nil : weeks.map { $0.minutes > 0 ? Stats.formatHoursCompact($0.minutes) : nil })]
        if let otherWeeks {
            series.append(BarSeries(id: other.id, name: other.name, color: Theme.color(for: other),
                                    values: otherWeeks.map { Double($0.sessions) }))
        }
        let maxSessions = Int(series.flatMap(\.values).max() ?? 0)
        let step = maxSessions > 4 ? 2 : 1
        let cell = { (w: WeekLoad) in "\(w.sessions) · \(Stats.formatHours(w.minutes))" }
        let spoken = { (p: Profile, w: WeekLoad?) -> String in
            let n = w?.sessions ?? 0
            return "\(p.name) \(n) séance\(n > 1 ? "s" : ""), \(Stats.formatHours(w?.minutes ?? 0))"
        }
        let summary = both ? "Cette semaine : \(spoken(person, weeks.last)) ; \(spoken(other, otherWeeks?.last))"
                           : "Cette semaine : \(spoken(person, weeks.last))"
        return ChartCard(title: "Séances et heures par semaine",
                         subtitle: both ? "Séances de chacun ; les heures sont dans le tableau"
                                        : "Les barres comptent les séances, le chiffre au-dessus le temps passé",
                         empty: personEmpty && !both ? (.sessions, Self.noSessionText) : nil,
                         startsWithTable: Launch.table == "sessions") {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $together.animation(reduceMotion ? Motion.reduced : Motion.spring)) {
                    Text("Avec \(other.name)").font(Theme.font(.subheadline, weight: .semibold))
                }
                .tint(Theme.ink)
                .frame(minHeight: Theme.minTouch)
                if both {
                    HStack(spacing: 16) {
                        LegendDot(name: person.name, color: Theme.color(for: person))
                        LegendDot(name: other.name, color: Theme.color(for: other))
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } content: {
            WeekBarsChart(weeks: weeks.map(\.week), series: series, axisLabel: { "\(Int($0))" },
                          ticks: stride(from: 0, through: maxSessions, by: step).map(Double.init),
                          accessibilityTitle: "Séances et heures par semaine",
                          accessibilitySummary: summary)
        } table: {
            if let otherWeeks {
                DataTable(head: ["Semaine", person.name, other.name],
                          rows: zip(weeks, otherWeeks).map { [Format.dayMonth($0.week), cell($0), cell($1)] })
            } else {
                DataTable(head: ["Semaine", "Séances", "Heures"],
                          rows: weeks.map { [Format.dayMonth($0.week), "\($0.sessions)", Stats.formatHours($0.minutes)] })
            }
        }
    }

    private func tonnageCard(person: Profile, weeks: [WeekLoad]) -> some View {
        let empty = weeks.allSatisfy { $0.tonnage == 0 }
        return ChartCard(title: "Tonnage par semaine", subtitle: "Kilos × répétitions des séries validées",
                         empty: empty ? (.load, "Pas encore de série validée ces 8 dernières semaines") : nil,
                         startsWithTable: Launch.table == "tonnage") {
            WeekBarsChart(weeks: weeks.map(\.week),
                          series: [BarSeries(id: person.id, name: person.name, color: Theme.color(for: person),
                                             values: weeks.map(\.tonnage),
                                             labels: BarSeries.lastLabel(weeks.map(\.tonnage), Format.tonnage))],
                          axisLabel: { $0 == 0 ? "0" : Format.tonnage($0) },
                          accessibilityTitle: "Tonnage par semaine",
                          accessibilitySummary: summary(weeks.map(\.tonnage), Format.tonnage))
                .personChart(person)
        } table: {
            DataTable(head: ["Semaine", "Tonnage"], rows: weeks.map { [Format.dayMonth($0.week), Format.tonnage($0.tonnage)] })
        }
    }

    private func cardioCard(person: Profile, weeks: [WeekLoad]) -> some View {
        let empty = weeks.allSatisfy { $0.cardioMinutes == 0 }
        return ChartCard(title: "Cardio par semaine", subtitle: "Minutes validées",
                         empty: empty ? (.cardio, "Pas encore de cardio ces 8 dernières semaines") : nil,
                         startsWithTable: Launch.table == "cardio") {
            WeekBarsChart(weeks: weeks.map(\.week),
                          series: [BarSeries(id: person.id, name: person.name, color: Theme.color(for: person),
                                             values: weeks.map { Double($0.cardioMinutes) },
                                             labels: BarSeries.lastLabel(weeks.map { Double($0.cardioMinutes) }) {
                                                 "\(Int($0)) min"
                                             })],
                          axisLabel: { "\(Int($0))" },
                          accessibilityTitle: "Cardio par semaine, en minutes",
                          accessibilitySummary: summary(weeks.map { Double($0.cardioMinutes) }) { "\(Int($0)) min" })
                .personChart(person)
        } table: {
            DataTable(head: ["Semaine", "Minutes"], rows: weeks.map { [Format.dayMonth($0.week), "\($0.cardioMinutes) min"] })
        }
    }

    private func muscleCard(person: Profile, week: WeekLoad?) -> some View {
        let rows = Muscle.allCases
            .filter { $0 != .cardio && (week?.setsByMuscle[$0] ?? 0) > 0 }
            .map { (muscle: Catalogue.muscleLabel($0), sets: week?.setsByMuscle[$0] ?? 0) }
        return ChartCard(title: "Séries par muscle",
                         subtitle: "Cette semaine — repère : 10 à 20 séries par muscle et par semaine",
                         // Une séance de cardio seul cette semaine : il y a eu séance, mais pas de série.
                         empty: rows.isEmpty ? (.sessions, (week?.sessions ?? 0) == 0
                                                ? "Pas encore de séance cette semaine"
                                                : "Pas de série de muscu cette semaine") : nil,
                         startsWithTable: Launch.table == "muscles") {
            MuscleSetsChart(rows: rows, color: Theme.color(for: person), personId: person.id)
                .personChart(person)
        } table: {
            DataTable(head: ["Muscle", "Séries"], rows: rows.map { [$0.muscle, "\($0.sets)"] })
        }
    }

    /// « Cette semaine : 8,6 t. Meilleure semaine : 9 t. »
    private func summary(_ values: [Double], _ format: (Double) -> String) -> String {
        "Cette semaine : \(format(values.last ?? 0)). Meilleure semaine : \(format(values.max() ?? 0))."
    }
}

private extension View {
    /// Un graphique neuf par personne pour les cartes de kilos (tonnage, cardio, muscles) : au changement
    /// de personne, l'ancien disparaît d'un coup et le nouveau fait son entrée depuis zéro (ou apparaît
    /// en fondu avec « Réduire les animations ») — jamais les valeurs de l'un mêlées à celles de l'autre.
    /// Les séances et heures, qui peuvent montrer les deux, gardent leur graphique.
    func personChart(_ person: Profile) -> some View {
        id(person.id).transition(.identity)
    }
}

/// Mise au point (DEBUG) : `-load-person partner`, `-load-together`, `-load-table <sessions|tonnage|
/// cardio|muscles|progress>`, `-load-machine <id>`, `-load-measure <top|e1rm|tonnage>`,
/// `-load-scroll <tonnage|muscles|progress|records>`, `-load-switch <secondes>`.
private enum Launch {
    private static func value(_ flag: String) -> String? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1]
        #else
        return nil
        #endif
    }

    private static func has(_ flag: String) -> Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains(flag)
        #else
        false
        #endif
    }

    static var partner: Bool { value("-load-person") == "partner" }
    static var together: Bool { has("-load-together") }
    static var table: String? { value("-load-table") }
    static var machine: String? { value("-load-machine") }
    static var scroll: String? { value("-load-scroll") }
    static var switchEvery: Double? { value("-load-switch").flatMap(Double.init) }
    static var measure: LoadMeasure { value("-load-measure").flatMap(LoadMeasure.init(rawValue:)) ?? .top }
}
