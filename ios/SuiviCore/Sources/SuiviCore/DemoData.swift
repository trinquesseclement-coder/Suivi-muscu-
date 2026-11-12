import Foundation

/// Données de démonstration (reprend celles de la maquette) : 4 semaines de séances,
/// une séance à deux demain, « Bras + cardio » dans 3 jours, et Jules en cours.
public enum DemoData {
    public static func cache(today: String, now: Date)
        -> (profiles: [Profile], sessions: [Session], exercises: [Exercise]) {
        let c = AppStore.clementId, j = AppStore.julesId
        var n = 0
        func id() -> String { n += 1; return "demo-\(n)" }
        func day(_ off: Int) -> String { Dates.addDays(today, off) }
        func sets(_ kg: Double, _ reps: Int, _ k: Int = 3, _ done: Bool = true) -> [SetEntry] {
            (0..<k).map { _ in SetEntry(kg: kg, reps: reps, done: done) }
        }
        func item(_ ex: String, _ kg: Double, _ reps: Int, _ k: Int = 3, _ done: Bool = true) -> SessionItem {
            SessionItem(id: id(), exerciseId: ex, sets: sets(kg, reps, k, done))
        }
        func cardio(_ ex: String, _ min: Int, _ km: Double?, _ lvl: Int, _ done: Bool = true) -> SessionItem {
            SessionItem(id: id(), exerciseId: ex,
                        cardio: CardioEntry(minutes: min, distanceKm: km, level: lvl, done: done))
        }
        var sessions: [Session] = []
        func add(_ owner: String, _ off: Int, _ title: String, _ items: [SessionItem], rpe: Int = 7) {
            let d = day(off)
            sessions.append(Session(id: id(), ownerId: owner, createdBy: owner, date: d, title: title,
                                    status: .done, items: items, rpe: rpe, durationMin: 55,
                                    startedAt: d + "T17:30:00.000Z", endedAt: d + "T18:25:00.000Z",
                                    updatedAt: d + "T18:25:00.000Z"))
        }

        for (w, o) in [-27, -20, -13, -6].enumerated() {
            let f = Double(w)
            add(c, o, "Haut du corps — tirage", [
                item("poulie-tirage-vertical", 30 + f * 2.5, 10),
                item("poulie-tirage-horizontal", 27.5 + f * 2.5, 10),
                item("poulie-face-pull", 12.5 + f * 1.25, 12),
                item("poulie-curl", 15 + f * 1.25, 10),
                cardio("c-ergo-bras", 12, nil, 5 + w)])
            add(c, o + 2, "Haut du corps — poussée", [
                item("m-chest-press", 35 + f * 5, 10),
                item("m-shoulder-press", 20 + f * 2.5, 10),
                item("poulie-triceps", 17.5 + f * 1.25, 12),
                item("d-chest-press", 30 + f * 5, 8),
                item("poulie-crunch", 25, 15)], rpe: 8)
            add(j, o - 1, "Jambes", [
                item("d-presse-45", 120 + f * 10, 10),
                item("d-hack-squat", 60 + f * 5, 8),
                item("m-leg-curl-assis", 45 + f * 2.5, 12),
                item("d-mollets", 60, 15),
                cardio("c-velo", 15, 7.5, 8)])
            add(j, o + 1, "Haut du corps", [
                item("s-developpe-couche", 60 + f * 2.5, 8),
                item("d-row-isolateral", 50 + f * 5, 10),
                item("m-shoulder-press", 35 + f * 2.5, 10),
                item("h-curl", 14, 10)])
        }

        // Séance à deux, demain.
        let planned = "2026-11-11T20:00:00.000Z"
        for (owner, items) in [
            (c, [item("poulie-tirage-vertical", 40, 10, 3, false), item("m-chest-press", 55, 10, 3, false),
                 item("d-chest-press", 50, 8, 3, false)]),
            (j, [item("d-presse-45", 160, 10, 3, false), item("d-hack-squat", 80, 8, 3, false),
                 item("s-developpe-couche", 70, 8, 3, false)])
        ] {
            sessions.append(Session(id: id(), ownerId: owner, createdBy: c, date: day(1),
                                    title: "Séance à deux", status: .planned, items: items,
                                    groupId: "demo-groupe", updatedAt: planned))
        }
        sessions.append(Session(id: id(), ownerId: c, createdBy: c, date: day(3), title: "Bras + cardio",
                                status: .planned,
                                items: [item("poulie-curl", 20, 10, 3, false),
                                        item("poulie-triceps", 22.5, 12, 3, false),
                                        cardio("c-ergo-bras", 15, nil, 9, false)],
                                updatedAt: planned))

        // Jules en cours depuis 25 minutes.
        var live = [item("d-presse-45", 160, 10), item("d-hack-squat", 80, 8, 3, false),
                    item("m-leg-extension", 60, 12, 3, false)]
        live[1].sets[0].done = true
        sessions.append(Session(id: id(), ownerId: j, createdBy: j, date: day(0), title: "Jambes",
                                status: .done, items: live,
                                startedAt: AppStore.timestamp(now.addingTimeInterval(-25 * 60)),
                                updatedAt: AppStore.timestamp(now)))

        var exercises: [Exercise] = []
        if var e = Catalogue.base.first(where: { $0.id == "m-chest-press" }) {
            e.note = "Siège cran 4, dossier cran 2"; exercises.append(e)
        }
        if var e = Catalogue.base.first(where: { $0.id == "poulie-tirage-vertical" }) {
            e.note = "Barre large, approcher le fauteuil au max"; exercises.append(e)
        }
        let profiles = [Profile(id: c, name: "Clément", slot: 1, needsHelp: true),
                        Profile(id: j, name: "Jules", slot: 2)]
        return (profiles, sessions, exercises)
    }
}
