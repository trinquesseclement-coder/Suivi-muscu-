import Foundation

/// Règles du cycle : quelle séance type vient ensuite, quand la proposer, et sa construction.
/// Chacun avance à son rythme, d'après ses propres séances.
public enum CyclePlanner {
    // MARK: Séance suivante

    /// Séance type de la dernière séance du cycle qui compte (au moins une série validée) de
    /// `ownerId`, non supprimée, dont la séance type existe encore. La plus récente par date, puis,
    /// le même jour, par heure de début (à défaut, dernière modification) : corriger une charge de
    /// la séance du matin ne fait pas reculer le cycle. L'ordre de `sessions` n'importe pas.
    public static func last(_ cycle: Cycle, sessions: [Session], ownerId: String) -> CycleTemplate? {
        let candidates = sessions.filter { s in
            s.ownerId == ownerId && s.deleted != true && Stats.counts(s)
                && cycle.templates.contains { $0.id == s.cycleId }
        }
        let latest = candidates.max { a, b in
            a.date != b.date ? a.date < b.date : (a.startedAt ?? a.updatedAt) < (b.startedAt ?? b.updatedAt)
        }
        return latest.flatMap { s in cycle.templates.first { $0.id == s.cycleId } }
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

    /// Séances prévues datées `date` pour la séance type. Chaque exercice est refait pour chaque
    /// personne depuis sa propre dernière fois, série par série, avec la façon de faire de cette
    /// dernière fois (`Rules.scheme`) : même résultat seul ou à deux. Les minutes de cardio de la
    /// séance type s'imposent. Les exercices absents de `byId` (masqués ou supprimés) sont
    /// ignorés ; s'il n'en reste aucun, rien n'est créé.
    public static func sessions(for template: CycleTemplate, target: PlanTarget, me: Profile, partner: Profile,
                                date: String, sessions: [Session], byId: [String: Exercise],
                                now: Date) -> [Session] {
        let owners: [Profile]
        switch target {
        case .me: owners = [me]
        case .partner: owners = [partner]
        case .both: owners = [me, partner]
        }
        let built = owners.map { owner in
            (owner, template.items.compactMap { item -> SessionItem? in
                guard let ex = byId[item.exerciseId] else { return nil }
                var it = Rules.newItem(ex, ownerId: owner.id, sessions: sessions,
                                       scheme: Rules.scheme(for: ex, owner: owner, sessions: sessions))
                if ex.kind == .cardio, let minutes = item.minutes { it.cardio?.minutes = minutes }
                return it
            })
        }
        guard built.contains(where: { !$0.1.isEmpty }) else { return [] }
        return PlanBuilder.assemble(built, me: me, date: date, title: template.title, notes: nil,
                                    byId: byId, now: now)
            .map { s in
                var s = s
                s.cycleId = template.id
                return s
            }
    }

    // MARK: Ménage

    /// Séances du cycle de ces personnes, datées d'avant `today`, jamais commencées (prévues, ni
    /// démarrées ni aucune série validée) et non supprimées : on les retire avant d'en créer de
    /// nouvelles, pour qu'elles ne s'entassent pas dans le Planning.
    public static func staleSessions(_ sessions: [Session], ownerIds: [String], today: String) -> [Session] {
        sessions.filter { s in
            s.cycleId != nil && ownerIds.contains(s.ownerId) && s.deleted != true && s.date < today
                && s.status == .planned && s.startedAt == nil && !Rules.hasProgress(s)
        }
    }
}
