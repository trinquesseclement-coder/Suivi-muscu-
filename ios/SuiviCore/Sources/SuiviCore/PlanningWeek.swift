import Foundation

/// La semaine du planning (miroir de `appli/src/pages/Planning.tsx`).
public enum PlanningWeek {
    /// Les 7 dates (YYYY-MM-DD) du lundi au dimanche de la semaine qui contient `iso`.
    public static func days(containing iso: String) -> [String] {
        let monday = Dates.weekStart(iso)
        return (0..<7).map { Dates.addDays(monday, $0) }
    }

    /// Séances du jour, triées selon le `slot` de leur propriétaire (Clément avant Jules).
    public static func sessions(on day: String, in sessions: [Session], profiles: [Profile]) -> [Session] {
        func slot(_ s: Session) -> Int { profiles.first { $0.id == s.ownerId }?.slot ?? Int.max }
        return sessions
            .filter { $0.date == day && $0.deleted != true }
            .enumerated()
            .sorted { a, b in
                let (sa, sb) = (slot(a.element), slot(b.element))
                return sa != sb ? sa < sb : a.offset < b.offset
            }
            .map(\.element)
    }

    /// Nombre d'exercices qui demandent de l'aide ; 0 si le propriétaire n'en a pas besoin.
    public static func helpCount(_ s: Session, profiles: [Profile], byId: [String: Exercise]) -> Int {
        guard Rules.needsHelp(profiles, id: s.ownerId) else { return 0 }
        return s.items.filter { byId[$0.exerciseId]?.help == true }.count
    }
}
