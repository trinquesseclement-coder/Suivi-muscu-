import Foundation

/// Statistiques (miroir de `appli/src/lib/stats.ts`). La tâche 4 complète ce fichier.
public enum Stats {
    /// Séries faites d'un item (au moins une répétition, comme le web).
    public static func doneSets(_ item: SessionItem) -> [SetEntry] {
        item.sets.filter { $0.done && $0.reps > 0 }
    }

    /// Dernière fois où la personne a fait l'exercice (séance terminée).
    /// `sessions` est supposé trié du plus récent au plus ancien.
    public static func lastPerformance(_ sessions: [Session], ownerId: String, exerciseId: String,
                                       excluding: String? = nil) -> (session: Session, item: SessionItem)? {
        for s in sessions {
            if s.ownerId != ownerId || s.status != .done || s.id == excluding { continue }
            if let it = s.items.first(where: {
                $0.exerciseId == exerciseId && (!doneSets($0).isEmpty || $0.cardio?.done == true)
            }) {
                return (s, it)
            }
        }
        return nil
    }

    // MARK: Charges

    /// 1RM estimé (Epley). Au-delà de 12 répétitions l'estimation devient peu fiable.
    public static func e1rm(kg: Double, reps: Int) -> Double {
        if reps <= 0 || kg <= 0 { return 0 }
        if reps == 1 { return kg }
        return kg * (1 + Double(min(reps, 12)) / 30)
    }

    public static func itemTonnage(_ item: SessionItem) -> Double {
        doneSets(item).reduce(0) { $0 + $1.kg * Double($1.reps) }
    }

    public static func sessionTonnage(_ s: Session) -> Double {
        s.items.reduce(0) { $0 + itemTonnage($1) }
    }

    /// Nombre de séries faites dans la séance.
    public static func sessionSetCount(_ s: Session) -> Int {
        s.items.reduce(0) { $0 + doneSets($1).count }
    }

    /// Minutes de cardio validées dans la séance.
    public static func sessionCardioMinutes(_ s: Session, byId: [String: Exercise]) -> Int {
        s.items.reduce(0) { total, it in
            guard byId[it.exerciseId]?.kind == .cardio, let c = it.cardio, c.done else { return total }
            return total + c.minutes
        }
    }

    /// Exercices commencés (au moins une série ou le cardio validé), pour « 2/3 exercices ».
    public static func startedItemCount(_ s: Session) -> Int {
        s.items.filter { $0.sets.contains(where: \.done) || $0.cardio?.done == true }.count
    }

    /// Exercices dont le record (1RM estimé) est battu pendant cette séance.
    public static func sessionPRs(_ all: [Session], _ s: Session) -> [String] {
        let previous = previousBests(all, s)
        var out: [String] = []
        for it in s.items {
            let best = doneSets(it).map { e1rm(kg: $0.kg, reps: $0.reps) }.max() ?? 0
            if best > 0, let p = previous[it.exerciseId], best > p + 0.01 { out.append(it.exerciseId) }
        }
        return out
    }

    /// Meilleur 1RM estimé par exercice avant cette séance (mêmes séances que `sessionPRs`).
    public static func previousBests(_ all: [Session], _ s: Session) -> [String: Double] {
        var previous: [String: Double] = [:]
        for o in all where o.ownerId == s.ownerId && o.id != s.id && o.status == .done && o.date <= s.date {
            for it in o.items {
                for st in doneSets(it) {
                    previous[it.exerciseId] = max(previous[it.exerciseId] ?? 0, e1rm(kg: st.kg, reps: st.reps))
                }
            }
        }
        return previous
    }

    /// Cette série bat-elle le record d'avant la séance (`best`, 0 si aucun) ?
    public static func isRecord(_ set: SetEntry, best: Double) -> Bool {
        set.done && set.reps > 0 && best > 0 && e1rm(kg: set.kg, reps: set.reps) > best + 0.01
    }

    // MARK: Semaine

    public struct WeekSummary: Sendable, Equatable {
        public var sessions: Int
        public var minutes: Int
        public var goal: Int
    }

    /// Une séance compte quand au moins une série ou un cardio est validé.
    public static func counts(_ s: Session) -> Bool {
        s.items.contains { !doneSets($0).isEmpty || $0.cardio?.done == true }
    }

    /// Durée en minutes entières. Saisie (plafonnée à 240), sinon début → fin (plafonnée à 150).
    public static func durationMinutes(_ s: Session, now: Date) -> Int {
        guard counts(s) else { return 0 }
        if let typed = s.durationMin { return max(0, min(typed, 240)) }
        guard let started = s.startedAt, let start = Rules.parseTimestamp(started) else { return 0 }
        let end = s.endedAt.flatMap(Rules.parseTimestamp) ?? Rules.parseTimestamp(s.updatedAt) ?? now
        let minutes = Int((end.timeIntervalSince(start) / 60).rounded(.down))
        return max(0, min(minutes, 150))
    }

    /// Durée proposée à l'écran « Terminer » : saisie si elle existe, sinon début → fin (ou → maintenant
    /// si la séance n'est pas terminée), plafonnée à 240 et arrondie à 5 minutes (minimum 5).
    public static func finishPrefillMinutes(_ s: Session, now: Date) -> Int {
        if let typed = s.durationMin { return max(5, min(typed, 240)) }
        guard let started = s.startedAt, let start = Rules.parseTimestamp(started) else { return 5 }
        let end = s.endedAt.flatMap(Rules.parseTimestamp) ?? now
        let minutes = max(0, end.timeIntervalSince(start) / 60)
        return max(5, min(240, Int((minutes / 5).rounded()) * 5))
    }

    private static func countingSessions(_ sessions: [Session], ownerId: String, containing iso: String) -> [Session] {
        let monday = Dates.weekStart(iso)
        return sessions.filter {
            $0.ownerId == ownerId && $0.deleted != true && Dates.weekStart($0.date) == monday && counts($0)
        }
    }

    public static func week(_ sessions: [Session], owner: Profile, containing iso: String, now: Date) -> WeekSummary {
        let mine = countingSessions(sessions, ownerId: owner.id, containing: iso)
        return WeekSummary(sessions: mine.count,
                           minutes: mine.reduce(0) { $0 + durationMinutes($1, now: now) },
                           goal: owner.settings?.weeklyGoal ?? 3)
    }

    /// Jours de la semaine où les deux ont une séance, et le temps passé ces jours-là.
    public static func together(_ sessions: [Session], a: String, b: String, containing iso: String,
                                now: Date) -> (days: Int, minutes: Int) {
        let mineA = countingSessions(sessions, ownerId: a, containing: iso)
        let mineB = countingSessions(sessions, ownerId: b, containing: iso)
        let shared = Set(mineA.map(\.date)).intersection(mineB.map(\.date))
        let minutes = (mineA + mineB).filter { shared.contains($0.date) }
            .reduce(0) { $0 + durationMinutes($1, now: now) }
        return (shared.count, minutes)
    }

    /// 165 → "2h45", 60 → "1h", 45 → "45 min".
    public static func formatHours(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h)h" : "\(h)h" + (m < 10 ? "0\(m)" : "\(m)")
    }

    /// Comme `formatHours`, en plus court pour un libellé au-dessus d'une barre : 45 → "45m".
    public static func formatHoursCompact(_ minutes: Int) -> String {
        minutes < 60 ? "\(minutes)m" : formatHours(minutes)
    }
}
