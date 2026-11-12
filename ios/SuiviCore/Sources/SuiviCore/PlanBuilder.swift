import Foundation

/// Un exercice dans l'éditeur de séance (miroir de `Spec` dans `PlanEditor.tsx`).
public struct PlanSpec: Identifiable, Hashable, Sendable {
    public var id: String
    public var exerciseId: String
    /// `nil` quand on planifie pour les deux : le schéma est alors réglé pour chacun.
    public var scheme: RepScheme?
    public var sets: Int
    public var reps: Int
    public var kg: Double
    public var minutes: Int

    public init(id: String, exerciseId: String, scheme: RepScheme?, sets: Int, reps: Int,
                kg: Double, minutes: Int) {
        self.id = id; self.exerciseId = exerciseId; self.scheme = scheme
        self.sets = sets; self.reps = reps; self.kg = kg; self.minutes = minutes
    }
}

/// Pour qui on planifie.
public enum PlanTarget: Sendable, Hashable { case me, partner, both }

/// Construction des séances planifiées (miroir de la logique de `PlanEditor.tsx`).
public enum PlanBuilder {
    // MARK: Spec

    public static func spec(for ex: Exercise, owner: Profile?, sessions: [Session]) -> PlanSpec {
        let id = UUID().uuidString.lowercased()
        guard let owner else {
            return PlanSpec(id: id, exerciseId: ex.id, scheme: nil, sets: 3, reps: 10, kg: 0,
                            minutes: ex.kind == .cardio ? 15 : 0)
        }
        let last = Stats.lastPerformance(sessions, ownerId: owner.id, exerciseId: ex.id)
        let done = last.map { Stats.doneSets($0.item) } ?? []
        let top = done.reduce(nil as SetEntry?) { best, s in
            guard let b = best else { return s }
            return s.kg > b.kg ? s : b
        }
        return PlanSpec(id: id, exerciseId: ex.id, scheme: Rules.defaultScheme(for: owner),
                        sets: done.count > 0 ? done.count : 3, reps: top?.reps ?? 10, kg: top?.kg ?? 0,
                        minutes: last?.item.cardio?.minutes ?? (ex.kind == .cardio ? 15 : 0))
    }

    /// Spec à partir d'une séance existante : « Reprendre une séance » et modification.
    public static func specs(from s: Session) -> [PlanSpec] {
        s.items.map { it in
            PlanSpec(id: UUID().uuidString.lowercased(), exerciseId: it.exerciseId, scheme: it.scheme,
                     sets: max(1, it.sets.count), reps: it.sets.first?.reps ?? 10,
                     kg: max(0, it.sets.map(\.kg).max() ?? 0), minutes: it.cardio?.minutes ?? 15)
        }
    }

    /// « Reprendre une séance » : les valeurs prévues de la séance si elle appartient déjà à
    /// `owner`, sinon des specs tirées de l'historique de `owner` (`nil` = les deux), pour ne
    /// jamais reprendre les charges de l'autre. Les exercices absents de `byId` sont ignorés.
    public static func specs(copying s: Session, owner: Profile?, sessions: [Session],
                             byId: [String: Exercise]) -> [PlanSpec] {
        if let owner, owner.id == s.ownerId {
            return specs(from: s).filter { byId[$0.exerciseId] != nil }
        }
        return s.items.compactMap { it in
            byId[it.exerciseId].map { spec(for: $0, owner: owner, sessions: sessions) }
        }
    }

    /// « Pour qui » a changé : chaque spec est refaite pour le nouveau propriétaire (son schéma,
    /// ses charges), en gardant son identifiant et l'ordre.
    public static func retarget(_ specs: [PlanSpec], owner: Profile?, sessions: [Session],
                                byId: [String: Exercise]) -> [PlanSpec] {
        specs.map { sp in
            guard let ex = byId[sp.exerciseId] else { return sp }
            var out = spec(for: ex, owner: owner, sessions: sessions)
            out.id = sp.id
            return out
        }
    }

    /// Titre proposé tant que le champ « Nom » est vide.
    public static func titleSuggestion(_ specs: [PlanSpec], byId: [String: Exercise]) -> String {
        Rules.titleSuggestion(specs.map { SessionItem(id: $0.id, exerciseId: $0.exerciseId) }, byId: byId)
    }

    // MARK: Items

    public static func items(from specs: [PlanSpec], owner: Profile, single: Bool,
                             sessions: [Session], byId: [String: Exercise]) -> [SessionItem] {
        specs.compactMap { sp in
            guard let ex = byId[sp.exerciseId] else { return nil }
            if ex.kind == .cardio {
                var item = Rules.newItem(ex, ownerId: owner.id, sessions: sessions, scheme: .classic)
                item.cardio?.minutes = sp.minutes
                return item
            }
            if single {
                if (sp.scheme ?? .classic) == .pyramid {
                    return Rules.newItem(ex, ownerId: owner.id, sessions: sessions, scheme: .pyramid)
                }
                let sets = (0..<max(0, sp.sets)).map { _ in SetEntry(kg: sp.kg, reps: sp.reps, done: false) }
                return SessionItem(id: UUID().uuidString.lowercased(), exerciseId: ex.id, sets: sets, scheme: .classic)
            }
            return Rules.newItem(ex, ownerId: owner.id, sessions: sessions, scheme: Rules.defaultScheme(for: owner))
        }
    }

    // MARK: Séances

    public static func sessions(specs: [PlanSpec], target: PlanTarget, me: Profile, partner: Profile,
                                date: String, title: String, notes: String?, sessions: [Session],
                                byId: [String: Exercise], now: Date) -> [Session] {
        let owners: [Profile]
        switch target {
        case .me: owners = [me]
        case .partner: owners = [partner]
        case .both: owners = [me, partner]
        }
        let single = owners.count == 1
        let groupId = single ? nil : UUID().uuidString.lowercased()
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let stamp = AppStore.timestamp(now)
        let built = owners.map { owner in
            (owner, items(from: specs, owner: owner, single: single, sessions: sessions, byId: byId))
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = trimmedTitle.isEmpty
            ? Rules.titleSuggestion(built.first?.1 ?? [], byId: byId) : trimmedTitle
        return built.map { owner, its in
            Session(id: UUID().uuidString.lowercased(), ownerId: owner.id, createdBy: me.id, date: date,
                    title: finalTitle, status: .planned, items: its,
                    notes: (trimmedNotes?.isEmpty ?? true) ? nil : trimmedNotes,
                    groupId: groupId, updatedAt: stamp)
        }
    }

    /// Séance prévue modifiée : mêmes `id`, `groupId`, `createdBy`, toujours prévue ; les éléments
    /// sont reconstruits pour `owner` seul. La séance sœur de l'autre n'est jamais touchée.
    public static func edited(_ s: Session, specs: [PlanSpec], owner: Profile, date: String, title: String,
                              notes: String?, sessions: [Session], byId: [String: Exercise],
                              now: Date) -> Session {
        let its = items(from: specs, owner: owner, single: true, sessions: sessions, byId: byId)
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        var out = s
        out.ownerId = owner.id
        out.date = date
        out.title = trimmedTitle.isEmpty ? Rules.titleSuggestion(its, byId: byId) : trimmedTitle
        out.notes = (trimmedNotes?.isEmpty ?? true) ? nil : trimmedNotes
        out.items = its
        out.status = .planned
        out.updatedAt = AppStore.timestamp(now)
        return out
    }

    // MARK: Aide

    /// Au moins deux exercices avec aide, séparés par d'autres : la bannière propose de les regrouper.
    public static func helpIsScattered(_ specs: [PlanSpec], byId: [String: Exercise]) -> Bool {
        groupingHelp(specs, byId: byId).map(\.id) != specs.map(\.id)
    }

    /// Regroupe les exercices avec aide là où apparaît le premier.
    public static func groupingHelp(_ specs: [PlanSpec], byId: [String: Exercise]) -> [PlanSpec] {
        func helps(_ s: PlanSpec) -> Bool { byId[s.exerciseId]?.help == true }
        guard let firstHelp = specs.firstIndex(where: helps) else { return specs }
        let help = specs.filter(helps)
        let rest = specs.filter { !helps($0) }
        return Array(rest.prefix(firstHelp)) + help + Array(rest.dropFirst(firstHelp))
    }
}
