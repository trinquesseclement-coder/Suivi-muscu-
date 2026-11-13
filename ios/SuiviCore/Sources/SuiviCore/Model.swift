import Foundation

// Miroir de `appli/src/lib/types.ts` : mêmes noms de champs dans le JSON.

public enum Kind: String, Codable, Hashable, Sendable { case muscu, cardio }

/// Comment on fait l'exercice.
public enum Posture: String, Codable, Hashable, Sendable { case fauteuil, transfert, debout }

public enum Muscle: String, Codable, Hashable, Sendable, CaseIterable {
    case pecs, dos, epaules, biceps, triceps, quadris, ischios, fessiers, mollets, abdos, cardio
}

public enum Equipment: String, Codable, Hashable, Sendable {
    case machine, disques, poulie, smith, halteres, cardio
}

public enum Brand: String, Codable, Hashable, Sendable { case technogym, hammer, autre }

public enum SessionStatus: String, Codable, Hashable, Sendable { case planned, done }

/// Schéma de répétitions (nouveau, absent du web).
public enum RepScheme: String, Codable, Hashable, Sendable { case pyramid, classic }

public struct Exercise: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var kind: Kind
    public var muscle: Muscle
    public var posture: Posture
    /// Il faut quelqu'un pour charger/décharger les disques ou installer.
    public var help: Bool
    public var equipment: Equipment
    public var brand: Brand?
    /// Pas de charge par défaut pour les +/- (kg).
    public var step: Double?
    public var note: String?
    /// Photo de la machine (data URL JPEG compressée).
    public var photo: String?
    public var custom: Bool?
    public var deleted: Bool?

    public init(id: String, name: String, kind: Kind, muscle: Muscle, posture: Posture,
                help: Bool, equipment: Equipment, brand: Brand? = nil, step: Double? = nil,
                note: String? = nil, photo: String? = nil, custom: Bool? = nil, deleted: Bool? = nil) {
        self.id = id; self.name = name; self.kind = kind; self.muscle = muscle
        self.posture = posture; self.help = help; self.equipment = equipment
        self.brand = brand; self.step = step; self.note = note; self.photo = photo
        self.custom = custom; self.deleted = deleted
    }
}

public struct ProfileSettings: Codable, Hashable, Sendable {
    public var weeklyGoal: Int?
    public var defaultScheme: RepScheme?

    public init(weeklyGoal: Int? = nil, defaultScheme: RepScheme? = nil) {
        self.weeklyGoal = weeklyGoal; self.defaultScheme = defaultScheme
    }
}

public struct Profile: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var name: String
    /// 1 = vert, 2 = orange.
    public var slot: Int
    /// Photo de profil, carrée et compressée (data URL JPEG).
    public var avatar: String?
    /// A besoin qu'on l'aide à charger les disques.
    public var needsHelp: Bool?
    public var settings: ProfileSettings?

    public init(id: String, name: String, slot: Int, avatar: String? = nil,
                needsHelp: Bool? = nil, settings: ProfileSettings? = nil) {
        self.id = id; self.name = name; self.slot = slot; self.avatar = avatar
        self.needsHelp = needsHelp; self.settings = settings
    }
}

public struct SetEntry: Codable, Hashable, Sendable {
    public var kg: Double
    public var reps: Int
    public var done: Bool

    public init(kg: Double, reps: Int, done: Bool) {
        self.kg = kg; self.reps = reps; self.done = done
    }
}

public struct CardioEntry: Codable, Hashable, Sendable {
    public var minutes: Int
    public var distanceKm: Double?
    public var calories: Int?
    public var level: Int?
    public var done: Bool

    public init(minutes: Int, distanceKm: Double? = nil, calories: Int? = nil,
                level: Int? = nil, done: Bool) {
        self.minutes = minutes; self.distanceKm = distanceKm
        self.calories = calories; self.level = level; self.done = done
    }
}

public struct SessionItem: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var exerciseId: String
    public var sets: [SetEntry]
    public var cardio: CardioEntry?
    public var note: String?
    public var scheme: RepScheme?

    public init(id: String, exerciseId: String, sets: [SetEntry] = [],
                cardio: CardioEntry? = nil, note: String? = nil, scheme: RepScheme? = nil) {
        self.id = id; self.exerciseId = exerciseId; self.sets = sets
        self.cardio = cardio; self.note = note; self.scheme = scheme
    }
}

public struct Session: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var ownerId: String
    public var createdBy: String
    /// YYYY-MM-DD
    public var date: String
    public var title: String
    public var status: SessionStatus
    public var items: [SessionItem]
    public var notes: String?
    /// Ressenti global de 1 à 10.
    public var rpe: Int?
    public var durationMin: Int?
    /// Horodatage de la première série cochée.
    public var startedAt: String?
    /// Horodatage du bouton « Terminer ».
    public var endedAt: String?
    /// Même valeur pour les séances planifiées ensemble.
    public var groupId: String?
    /// Séance type du cycle d'où vient la séance (`CycleTemplate.id`), `nil` hors cycle.
    public var cycleId: String?
    public var deleted: Bool?
    public var updatedAt: String

    public init(id: String, ownerId: String, createdBy: String, date: String, title: String,
                status: SessionStatus, items: [SessionItem] = [], notes: String? = nil,
                rpe: Int? = nil, durationMin: Int? = nil, startedAt: String? = nil,
                endedAt: String? = nil, groupId: String? = nil, cycleId: String? = nil,
                deleted: Bool? = nil, updatedAt: String) {
        self.id = id; self.ownerId = ownerId; self.createdBy = createdBy; self.date = date
        self.title = title; self.status = status; self.items = items; self.notes = notes
        self.rpe = rpe; self.durationMin = durationMin; self.startedAt = startedAt
        self.endedAt = endedAt; self.groupId = groupId; self.cycleId = cycleId; self.deleted = deleted
        self.updatedAt = updatedAt
    }
}
