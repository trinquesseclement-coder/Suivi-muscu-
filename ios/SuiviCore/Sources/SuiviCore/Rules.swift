import Foundation

public extension RepScheme {
    /// Répétitions fixes du schéma. Seule la pyramide en a ; le classique n'en a pas.
    var reps: [Int] {
        switch self {
        case .pyramid: [12, 10, 8, 12]
        case .classic: []
        }
    }
}

/// Règles de séance (miroir de `appli/src/lib/sessions.ts` + pyramide 12/10/8/12).
public enum Rules {
    // MARK: Nouvel item

    public static func newItem(_ ex: Exercise, ownerId: String, sessions: [Session],
                               scheme: RepScheme) -> SessionItem {
        let id = UUID().uuidString.lowercased()
        let last = Stats.lastPerformance(sessions, ownerId: ownerId, exerciseId: ex.id)

        if ex.kind == .cardio {
            let c = last?.item.cardio
            return SessionItem(id: id, exerciseId: ex.id, sets: [],
                               cardio: CardioEntry(minutes: c?.minutes ?? 15, distanceKm: c?.distanceKm,
                                                   calories: nil, level: c?.level, done: false),
                               scheme: nil)
        }

        switch scheme {
        case .pyramid:
            let reps = RepScheme.pyramid.reps
            var kgs = [Double](repeating: 0, count: reps.count)
            if let l = last?.item, l.scheme == .pyramid {
                let done = Stats.doneSets(l)
                if done.count == reps.count { kgs = done.map(\.kg) }
            }
            let sets = zip(kgs, reps).map { SetEntry(kg: $0, reps: $1, done: false) }
            return SessionItem(id: id, exerciseId: ex.id, sets: sets, scheme: .pyramid)
        case .classic:
            let prev = last.map { Stats.doneSets($0.item) } ?? []
            let sets = prev.isEmpty
                ? (0..<3).map { _ in SetEntry(kg: 0, reps: 10, done: false) }
                : prev.map { SetEntry(kg: $0.kg, reps: $0.reps, done: false) }
            return SessionItem(id: id, exerciseId: ex.id, sets: sets, scheme: .classic)
        }
    }

    // MARK: Modifier une série

    public static func setKg(_ item: SessionItem, index: Int, kg: Double) -> SessionItem {
        guard item.sets.indices.contains(index) else { return item }
        let value = max(0, kg)
        var out = item
        if item.scheme == .pyramid {
            out.sets[index].kg = value
            // La série 1 est recopiée dans la série 4, si celle-ci n'est pas faite.
            if index == 0, out.sets.count == 4, !out.sets[3].done { out.sets[3].kg = value }
        } else {
            for j in out.sets.indices where j == index || (j > index && !out.sets[j].done) {
                out.sets[j].kg = value
            }
        }
        return out
    }

    public static func setReps(_ item: SessionItem, index: Int, reps: Int) -> SessionItem {
        guard item.sets.indices.contains(index) else { return item }
        let value = max(0, reps)
        var out = item
        if item.scheme == .pyramid {
            out.sets[index].reps = value
        } else {
            for j in out.sets.indices where j == index || (j > index && !out.sets[j].done) {
                out.sets[j].reps = value
            }
        }
        return out
    }

    // MARK: Changer de schéma

    public static func switchScheme(_ item: SessionItem, to scheme: RepScheme) -> SessionItem {
        guard item.cardio == nil || !item.sets.isEmpty, item.scheme != scheme else { return item }
        var out = item
        out.scheme = scheme
        switch scheme {
        case .pyramid:
            let reps = RepScheme.pyramid.reps
            // On tronque les séries non faites en fin de liste…
            while out.sets.count > reps.count, out.sets.last?.done == false { out.sets.removeLast() }
            // …ou on en ajoute pour arriver à 4.
            while out.sets.count < reps.count {
                out.sets.append(SetEntry(kg: out.sets.last?.kg ?? 0, reps: reps[out.sets.count], done: false))
            }
            for i in out.sets.indices where !out.sets[i].done && i < reps.count {
                out.sets[i].reps = reps[i]
            }
        case .classic:
            guard let ref = out.sets.last(where: \.done) ?? out.sets.first else { return out }
            for i in out.sets.indices where !out.sets[i].done {
                out.sets[i].kg = ref.kg
                out.sets[i].reps = ref.reps
            }
        }
        return out
    }

    /// Schéma par défaut d'un profil : réglage, sinon pyramide pour le profil 1 et classique pour le 2.
    public static func defaultScheme(for p: Profile) -> RepScheme {
        p.settings?.defaultScheme ?? (p.slot == 1 ? .pyramid : .classic)
    }

    // MARK: Séance

    /// Séance en cours : démarrée, pas terminée, dans les 4 dernières heures.
    public static func isLive(_ s: Session, now: Date = Date()) -> Bool {
        guard s.status == .done, s.endedAt == nil, let started = s.startedAt,
              let start = parseTimestamp(started) else { return false }
        return now.timeIntervalSince(start) < 4 * 3600
    }

    public static func hasProgress(_ s: Session) -> Bool {
        s.items.contains { $0.sets.contains(where: \.done) || $0.cardio?.done == true }
    }

    static func parseTimestamp(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fractional.date(from: string) { return d }
        return ISO8601DateFormatter().date(from: string)
    }

    // MARK: Profils et aide

    public static func partner(of id: String?, in profiles: [Profile]) -> Profile? {
        profiles.first { $0.id != id }
    }

    /// Réglage du profil ; tant qu'il n'est pas réglé : oui pour le profil n°1, non sinon.
    public static func profileNeedsHelp(_ p: Profile) -> Bool {
        p.needsHelp ?? (p.slot == 1)
    }

    public static func needsHelp(_ profiles: [Profile], id: String?) -> Bool {
        guard let p = profiles.first(where: { $0.id == id }) else { return false }
        return profileNeedsHelp(p)
    }

    /// Le nom de l'aidant, identique sur les deux téléphones.
    public static func helperName(_ profiles: [Profile]) -> String? {
        guard let helped = profiles.first(where: { profileNeedsHelp($0) }) else { return nil }
        return partner(of: helped.id, in: profiles)?.name
    }

    // MARK: Titre

    public static func titleSuggestion(_ items: [SessionItem], byId: [String: Exercise]) -> String {
        let groups = Set(items.compactMap { byId[$0.exerciseId]?.muscle })
        func has(_ m: Muscle...) -> Bool { m.contains { groups.contains($0) } }
        let upper = has(.pecs, .dos, .epaules, .biceps, .triceps)
        let lower = has(.quadris, .ischios, .fessiers, .mollets)
        let cardio = has(.cardio)
        if upper && lower { return cardio ? "Full body + cardio" : "Full body" }
        if upper {
            if has(.pecs, .epaules, .triceps) && !has(.dos, .biceps) { return cardio ? "Push + cardio" : "Push" }
            if has(.dos, .biceps) && !has(.pecs, .epaules, .triceps) { return cardio ? "Pull + cardio" : "Pull" }
            return cardio ? "Haut du corps + cardio" : "Haut du corps"
        }
        if lower { return cardio ? "Jambes + cardio" : "Jambes" }
        if cardio { return "Cardio" }
        return "Séance"
    }
}
