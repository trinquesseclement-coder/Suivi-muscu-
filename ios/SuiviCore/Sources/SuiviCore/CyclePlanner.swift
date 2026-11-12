import Foundation

/// Règles du cycle : quelle séance type vient ensuite, quand la proposer, et sa construction.
/// Chacun avance à son rythme, d'après ses propres séances.
public enum CyclePlanner {
    // MARK: Séance suivante

    /// Séance type de la dernière séance du cycle qui compte (au moins une série validée) de
    /// `ownerId`, non supprimée, dont la séance type existe encore. `sessions` est trié du plus
    /// récent au plus ancien, comme `AppStore.sessions`.
    public static func last(_ cycle: Cycle, sessions: [Session], ownerId: String) -> CycleTemplate? {
        for s in sessions where s.ownerId == ownerId && s.deleted != true && Stats.counts(s) {
            guard let cycleId = s.cycleId,
                  let template = cycle.templates.first(where: { $0.id == cycleId }) else { continue }
            return template
        }
        return nil
    }

    /// La séance type qui suit `last` dans l'ordre du cycle, en bouclant ; la première sans
    /// historique ; `nil` si le cycle est vide.
    public static func next(_ cycle: Cycle, sessions: [Session], ownerId: String) -> CycleTemplate? {
        let templates = cycle.templates
        guard let first = templates.first else { return nil }
        guard let last = last(cycle, sessions: sessions, ownerId: ownerId),
              let index = templates.firstIndex(where: { $0.id == last.id }) else { return first }
        return templates[(index + 1) % templates.count]
    }

    // MARK: Proposer

    /// Vrai quand la personne n'a ni séance en cours ni séance prévue aujourd'hui.
    public static func offersCycle(sessions: [Session], ownerId: String, today: String, now: Date) -> Bool {
        !sessions.contains { s in
            s.ownerId == ownerId && s.deleted != true
                && (Rules.isLive(s, now: now) || (s.status == .planned && s.date == today))
        }
    }

    /// Même règle pour l'autre : on ne propose « Commencer avec … » que s'il est libre.
    public static func partnerIsFree(sessions: [Session], partnerId: String, today: String, now: Date) -> Bool {
        offersCycle(sessions: sessions, ownerId: partnerId, today: today, now: now)
    }

    // MARK: Construction

    /// Séances prévues datées `date` pour la séance type, chacune avec les charges et le schéma
    /// de son propriétaire (règles de `PlanBuilder`). Les exercices absents de `byId` (masqués ou
    /// supprimés) sont ignorés ; s'il n'en reste aucun, rien n'est créé.
    public static func sessions(for template: CycleTemplate, target: PlanTarget, me: Profile, partner: Profile,
                                date: String, sessions: [Session], byId: [String: Exercise],
                                now: Date) -> [Session] {
        let owner: Profile?
        switch target {
        case .me: owner = me
        case .partner: owner = partner
        case .both: owner = nil
        }
        let specs = template.items.compactMap { item -> PlanSpec? in
            guard let ex = byId[item.exerciseId] else { return nil }
            var spec = PlanBuilder.spec(for: ex, owner: owner, sessions: sessions)
            if ex.kind == .cardio, let minutes = item.minutes { spec.minutes = minutes }
            return spec
        }
        guard !specs.isEmpty else { return [] }
        return PlanBuilder.sessions(specs: specs, target: target, me: me, partner: partner, date: date,
                                    title: template.title, notes: nil, sessions: sessions, byId: byId,
                                    now: now)
            .map { s in
                var s = s
                s.cycleId = template.id
                return s
            }
    }
}
