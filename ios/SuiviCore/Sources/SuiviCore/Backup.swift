import Foundation

/// Correction d'une machine telle qu'elle est stockée : tous les champs d'`Exercise` sont
/// optionnels sauf `id` (le web n'écrit souvent que `id` et `note`).
/// Un champ illisible (type ou valeur inconnue) est ignoré, pas toute la correction.
public struct ExerciseOverride: Codable, Hashable, Sendable {
    public var id: String
    public var name: String?
    public var kind: Kind?
    public var muscle: Muscle?
    public var posture: Posture?
    public var help: Bool?
    public var equipment: Equipment?
    public var brand: Brand?
    public var step: Double?
    public var note: String?
    public var photo: String?
    public var custom: Bool?
    public var deleted: Bool?

    public init(id: String) { self.id = id }

    /// Correction complète, champ pour champ, à partir d'une machine entière.
    public init(_ e: Exercise) {
        id = e.id; name = e.name; kind = e.kind; muscle = e.muscle; posture = e.posture
        help = e.help; equipment = e.equipment; brand = e.brand; step = e.step; note = e.note
        photo = e.photo; custom = e.custom; deleted = e.deleted
    }

    enum CodingKeys: String, CodingKey {
        case id, name, kind, muscle, posture, help, equipment, brand, step, note, photo, custom, deleted
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        func field<T: Decodable>(_ key: CodingKeys) -> T? { (try? c.decodeIfPresent(T.self, forKey: key)) ?? nil }
        name = field(.name); kind = field(.kind); muscle = field(.muscle); posture = field(.posture)
        help = field(.help); equipment = field(.equipment); brand = field(.brand); step = field(.step)
        note = field(.note); photo = field(.photo); custom = field(.custom); deleted = field(.deleted)
    }

    /// Fusionne la correction sur `base`, champ par champ (comme `{ ...base, ...correction }` côté web).
    /// Sans base (machine perso), il faut au moins `name`, `kind` et `muscle`, sinon `nil` ;
    /// les autres champs prennent les valeurs d'une nouvelle machine du web.
    public func applied(to base: Exercise?) -> Exercise? {
        let start: Exercise
        if let base {
            start = base
        } else {
            guard let name, let kind, let muscle else { return nil }
            start = Exercise(id: id, name: name, kind: kind, muscle: muscle, posture: .transfert,
                             help: false, equipment: kind == .cardio ? .cardio : .machine)
        }
        var e = start
        e.id = id
        if let name { e.name = name }
        if let kind { e.kind = kind }
        if let muscle { e.muscle = muscle }
        if let posture { e.posture = posture }
        if let help { e.help = help }
        if let equipment { e.equipment = equipment }
        if let brand { e.brand = brand }
        if let step { e.step = step }
        if let note { e.note = note }
        if let photo { e.photo = photo }
        if let custom { e.custom = custom }
        if let deleted { e.deleted = deleted }
        return e
    }

    /// Superpose `other` sur cette correction : les champs présents dans `other` gagnent.
    func merging(_ other: ExerciseOverride) -> ExerciseOverride {
        var r = self
        r.name = other.name ?? name; r.kind = other.kind ?? kind; r.muscle = other.muscle ?? muscle
        r.posture = other.posture ?? posture; r.help = other.help ?? help
        r.equipment = other.equipment ?? equipment; r.brand = other.brand ?? brand
        r.step = other.step ?? step; r.note = other.note ?? note; r.photo = other.photo ?? photo
        r.custom = other.custom ?? custom; r.deleted = other.deleted ?? deleted
        return r
    }
}

/// Le contenu d'une sauvegarde, après décodage.
public struct BackupContent: Sendable {
    public var profiles: [String: Profile]
    public var sessions: [String: Session]
    public var exercises: [String: ExerciseOverride]
    /// Entrées ignorées parce qu'illisibles.
    public var skipped: Int
}

public enum BackupError: Error, Sendable {
    /// Le fichier n'est pas une sauvegarde (pas du JSON, ou sans `profiles`/`sessions`/`exercises`).
    case notABackup
    /// Le fichier de l'appli n'a pas pu être lu : on n'écrit rien par-dessus.
    case storeLocked
}

/// Sauvegarde au format du web : `{ version: 1, exportedAt, profiles, sessions, exercises }`.
public enum Backup {
    struct File: Encodable {
        var version = 1
        var exportedAt: String
        var profiles: [String: Profile]
        var sessions: [String: Session]
        var exercises: [String: ExerciseOverride]
    }

    public static func export(profiles: [String: Profile], sessions: [String: Session],
                              exercises: [String: ExerciseOverride], now: Date) -> Data {
        let file = File(exportedAt: AppStore.timestamp(now), profiles: profiles,
                        sessions: sessions, exercises: exercises)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        // Des dictionnaires de valeurs Codable simples : l'encodage ne peut pas échouer.
        return (try? encoder.encode(file)) ?? Data()
    }

    /// Accepte un export du web ou de l'iOS. Les champs inconnus sont ignorés ; une entrée illisible
    /// est ignorée et comptée dans `skipped`, sans rejeter le reste.
    public static func decode(_ data: Data) throws -> BackupContent {
        let root: Root
        do {
            root = try JSONDecoder().decode(Root.self, from: data)
        } catch {
            throw BackupError.notABackup
        }
        let (p, s, e) = (root.profiles, root.sessions, root.exercises)
        return BackupContent(profiles: p.byId(\.id), sessions: s.byId(\.id), exercises: e.byId(\.id),
                             skipped: p.skipped + s.skipped + e.skipped)
    }

    private struct Root: Decodable {
        var profiles: LossyMap<Profile>
        var sessions: LossyMap<Session>
        var exercises: LossyMap<ExerciseOverride>
    }
}

/// Un objet JSON `{id: valeur}` dont chaque valeur est décodée séparément : une valeur illisible
/// est mise de côté et comptée au lieu de faire échouer tout l'objet.
struct LossyMap<Value: Decodable>: Decodable {
    var values: [Value]
    var skipped: Int

    /// Valeurs indexées par leur propre id (la première l'emporte en cas de doublon).
    func byId(_ id: (Value) -> String) -> [String: Value] {
        Dictionary(values.map { (id($0), $0) }, uniquingKeysWith: { first, _ in first })
    }

    private struct Entry: Decodable {
        var value: Value?
        init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
    }

    init(from decoder: Decoder) throws {
        let entries = try [String: Entry](from: decoder)
        values = entries.keys.sorted().compactMap { entries[$0]?.value }
        skipped = entries.count - values.count
    }
}
