import Foundation

/// Une semaine du tableau de charge, pour une seule personne.
public struct WeekLoad: Sendable, Equatable {
    /// Lundi de la semaine (YYYY-MM-DD).
    public var week: String
    public var sessions: Int
    public var minutes: Int
    public var tonnage: Double
    public var sets: Int
    public var cardioMinutes: Int
    public var setsByMuscle: [Muscle: Int]

    public init(week: String, sessions: Int = 0, minutes: Int = 0, tonnage: Double = 0, sets: Int = 0,
                cardioMinutes: Int = 0, setsByMuscle: [Muscle: Int] = [:]) {
        self.week = week; self.sessions = sessions; self.minutes = minutes; self.tonnage = tonnage
        self.sets = sets; self.cardioMinutes = cardioMinutes; self.setsByMuscle = setsByMuscle
    }
}

/// Meilleure série d'une machine pendant une séance.
public struct ExercisePoint: Sendable, Equatable {
    public var date: String
    public var sessionId: String
    public var topKg: Double
    public var topReps: Int
    public var e1rm: Double
    public var tonnage: Double

    public init(date: String, sessionId: String, topKg: Double, topReps: Int, e1rm: Double, tonnage: Double) {
        self.date = date; self.sessionId = sessionId; self.topKg = topKg; self.topReps = topReps
        self.e1rm = e1rm; self.tonnage = tonnage
    }
}

/// Un cardio validé pendant une séance.
public struct CardioPoint: Sendable, Equatable {
    public var date: String
    public var sessionId: String
    public var minutes: Int
    public var distanceKm: Double?
    public var level: Int?

    public init(date: String, sessionId: String, minutes: Int, distanceKm: Double? = nil, level: Int? = nil) {
        self.date = date; self.sessionId = sessionId; self.minutes = minutes
        self.distanceKm = distanceKm; self.level = level
    }
}

/// Record personnel : la série au meilleur 1RM estimé, et le jour où elle a été faite.
public struct PR: Sendable, Equatable {
    public var exerciseId: String
    public var kg: Double
    public var reps: Int
    public var e1rm: Double
    public var date: String

    public init(exerciseId: String, kg: Double, reps: Int, e1rm: Double, date: String) {
        self.exerciseId = exerciseId; self.kg = kg; self.reps = reps; self.e1rm = e1rm; self.date = date
    }
}

/// Statistiques du tableau de charge (port de `weeklyStats`, `exerciseHistory`, `cardioHistory` et
/// `personalRecords` de `appli/src/lib/stats.ts`). Chaque fonction ne regarde qu'une personne :
/// les charges de deux personnes ne sont jamais mélangées.
public enum LoadStats {
    /// Séances terminées, non supprimées, de cette personne.
    private static func finished(_ sessions: [Session], ownerId: String) -> [Session] {
        sessions.filter { $0.ownerId == ownerId && $0.status == .done && $0.deleted != true }
    }

    /// `count` semaines, de la plus ancienne à celle d'aujourd'hui. Les séances et les minutes suivent
    /// `Stats.counts` et `Stats.durationMinutes` (comme l'accueil), pas les règles du web.
    public static func weeks(_ sessions: [Session], ownerId: String, byId: [String: Exercise],
                             count: Int, today: String, now: Date) -> [WeekLoad] {
        guard count > 0 else { return [] }
        let first = Dates.addDays(Dates.weekStart(today), -7 * (count - 1))
        var out = (0..<count).map { WeekLoad(week: Dates.addDays(first, 7 * $0)) }
        let index = Dictionary(uniqueKeysWithValues: out.enumerated().map { ($1.week, $0) })
        for s in sessions where s.ownerId == ownerId && s.deleted != true && Stats.counts(s) {
            guard let i = index[Dates.weekStart(s.date)] else { continue }
            out[i].sessions += 1
            out[i].minutes += Stats.durationMinutes(s, now: now)
            out[i].tonnage += Stats.sessionTonnage(s)
            out[i].cardioMinutes += Stats.sessionCardioMinutes(s, byId: byId)
            for it in s.items {
                guard let ex = byId[it.exerciseId], ex.kind == .muscu else { continue }
                let n = Stats.doneSets(it).count
                out[i].sets += n
                out[i].setsByMuscle[ex.muscle, default: 0] += n
            }
        }
        return out
    }

    /// Historique d'une machine, du plus ancien au plus récent.
    public static func history(_ sessions: [Session], ownerId: String, exerciseId: String) -> [ExercisePoint] {
        var points: [ExercisePoint] = []
        for s in finished(sessions, ownerId: ownerId) {
            for it in s.items where it.exerciseId == exerciseId {
                let sets = Stats.doneSets(it)
                guard var top = sets.first else { continue }
                var best = 0.0
                for st in sets {
                    if st.kg > top.kg || (st.kg == top.kg && st.reps > top.reps) { top = st }
                    best = max(best, Stats.e1rm(kg: st.kg, reps: st.reps))
                }
                points.append(ExercisePoint(date: s.date, sessionId: s.id, topKg: top.kg, topReps: top.reps,
                                            e1rm: best, tonnage: Stats.itemTonnage(it)))
            }
        }
        return sortedByDate(points, \.date)
    }

    /// Historique d'un cardio (entrées validées), du plus ancien au plus récent.
    public static func cardioHistory(_ sessions: [Session], ownerId: String, exerciseId: String) -> [CardioPoint] {
        var points: [CardioPoint] = []
        for s in finished(sessions, ownerId: ownerId) {
            for it in s.items where it.exerciseId == exerciseId {
                guard let c = it.cardio, c.done else { continue }
                points.append(CardioPoint(date: s.date, sessionId: s.id, minutes: c.minutes,
                                          distanceKm: c.distanceKm, level: c.level))
            }
        }
        return sortedByDate(points, \.date)
    }

    /// Meilleure performance (1RM estimé) par machine. À égalité, la date la plus ancienne gagne.
    public static func records(_ sessions: [Session], ownerId: String) -> [String: PR] {
        var prs: [String: PR] = [:]
        for s in finished(sessions, ownerId: ownerId) {
            for it in s.items {
                for st in Stats.doneSets(it) {
                    let v = Stats.e1rm(kg: st.kg, reps: st.reps)
                    if let cur = prs[it.exerciseId], !(v > cur.e1rm || (v == cur.e1rm && s.date < cur.date)) {
                        continue
                    }
                    prs[it.exerciseId] = PR(exerciseId: it.exerciseId, kg: st.kg, reps: st.reps, e1rm: v, date: s.date)
                }
            }
        }
        return prs
    }

    /// Machines déjà faites (série ou cardio validé), la plus récente d'abord.
    public static func doneExerciseIds(_ sessions: [Session], ownerId: String) -> [String] {
        var last: [String: String] = [:]
        for s in finished(sessions, ownerId: ownerId) {
            for it in s.items where !Stats.doneSets(it).isEmpty || it.cardio?.done == true {
                if let d = last[it.exerciseId], d >= s.date { continue }
                last[it.exerciseId] = s.date
            }
        }
        return last.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }.map(\.key)
    }

    /// Tri par date croissante, stable (l'ordre d'origine départage les égalités).
    private static func sortedByDate<T>(_ points: [T], _ date: KeyPath<T, String>) -> [T] {
        points.enumerated()
            .sorted { $0.element[keyPath: date] != $1.element[keyPath: date]
                ? $0.element[keyPath: date] < $1.element[keyPath: date] : $0.offset < $1.offset }
            .map(\.element)
    }
}
