import Foundation
import Observation
import os

/// Forme du fichier : mêmes clés que le cache web, dictionnaires indexés par id.
struct StoreFile: Codable {
    var profiles: [String: Profile]
    var sessions: [String: Session]
    /// Corrections du catalogue (parfois partielles, venues du web) et exercices personnalisés.
    var exercises: [String: ExerciseOverride]
    var meId: String
    /// Cycle enregistré ; `nil` = cycle de départ.
    var cycle: Cycle?
    /// Valeur `cycle` présente mais illisible : réécrite telle quelle tant qu'aucun cycle n'est
    /// enregistré, pour ne pas la détruire.
    var unreadableCycle: JSONValue?
    /// Corrections illisibles ignorées au chargement (jamais écrit).
    var skippedExercises = 0

    enum CodingKeys: String, CodingKey { case profiles, sessions, exercises, meId, cycle }

    init(profiles: [String: Profile], sessions: [String: Session],
         exercises: [String: ExerciseOverride], meId: String,
         cycle: Cycle? = nil, unreadableCycle: JSONValue? = nil) {
        self.profiles = profiles; self.sessions = sessions; self.exercises = exercises; self.meId = meId
        self.cycle = cycle; self.unreadableCycle = unreadableCycle
    }

    /// Profils et séances doivent être lisibles en entier (sinon tout le fichier part en copie
    /// `.corrupt`, pour ne jamais perdre une séance en réécrivant) ; une correction de machine
    /// ou un cycle illisibles sont seulement ignorés.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profiles = try c.decode([String: Profile].self, forKey: .profiles)
        sessions = try c.decode([String: Session].self, forKey: .sessions)
        let lossy = try c.decode(LossyMap<ExerciseOverride>.self, forKey: .exercises)
        exercises = lossy.byId(\.id)
        skippedExercises = lossy.skipped
        meId = try c.decode(String.self, forKey: .meId)
        cycle = (try? c.decodeIfPresent(Cycle.self, forKey: .cycle)) ?? nil
        if cycle == nil { unreadableCycle = (try? c.decodeIfPresent(JSONValue.self, forKey: .cycle)) ?? nil }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(profiles, forKey: .profiles)
        try c.encode(sessions, forKey: .sessions)
        try c.encode(exercises, forKey: .exercises)
        try c.encode(meId, forKey: .meId)
        if let cycle {
            try c.encode(cycle, forKey: .cycle)
        } else if let unreadableCycle {
            try c.encode(unreadableCycle, forKey: .cycle)
        }
    }
}

/// N'importe quelle valeur JSON, gardée telle quelle pour être réécrite sans perte.
enum JSONValue: Codable, Hashable {
    case null, bool(Bool), int(Int), double(Double), string(String)
    case array([JSONValue]), object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Int.self) { self = .int(v) }
        else if let v = try? c.decode(Double.self) { self = .double(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .int(let v): try c.encode(v)
        case .double(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }
}

/// Bilan d'un import : nombre de séances ajoutées, mises à jour, gardées (la locale était plus
/// récente), et d'entrées illisibles ignorées. Une séance identique des deux côtés ne compte nulle part.
public struct ImportSummary: Sendable, Equatable {
    public var added: Int
    public var updated: Int
    public var kept: Int
    public var skipped: Int

    public init(added: Int, updated: Int, kept: Int, skipped: Int) {
        self.added = added; self.updated = updated; self.kept = kept; self.skipped = skipped
    }
}

/// Stockage local observable : tout est écrit sur disque après chaque modification.
@Observable @MainActor
public final class AppStore {
    public nonisolated static let clementId = "local-clement"
    public nonisolated static let julesId = "local-jules"

    nonisolated static var defaultProfiles: [Profile] {
        [Profile(id: clementId, name: "Clément", slot: 1),
         Profile(id: julesId, name: "Jules", slot: 2)]
    }

    @ObservationIgnored private let fileURL: URL
    private var profileMap: [String: Profile]
    private var sessionMap: [String: Session]
    private var overrides: [String: ExerciseOverride]
    /// Cycle enregistré, `nil` tant qu'on garde le cycle de départ.
    private var storedCycle: Cycle?
    /// Valeur `cycle` illisible du fichier, réécrite telle quelle jusqu'au prochain `saveCycle`.
    @ObservationIgnored private var unreadableCycle: JSONValue?
    public private(set) var meId: String
    /// Description de la dernière erreur d'écriture, `nil` si la dernière écriture a réussi.
    public private(set) var lastSaveError: String?
    /// Problème rencontré au chargement (texte français), `nil` si le fichier a été lu normalement.
    /// Tant qu'il est posé après une lecture impossible, les écritures sont bloquées.
    public private(set) var loadProblem: String?
    /// Vrai quand écrire risquerait d'écraser un fichier existant qu'on n'a pas pu lire ni mettre de côté.
    @ObservationIgnored private var writesBlocked = false
    @ObservationIgnored private static let log = Logger(subsystem: "fr.suivimuscu.app", category: "AppStore")

    // MARK: Lecture

    public var profiles: [Profile] { profileMap.values.sorted { $0.slot < $1.slot } }

    /// Séances non supprimées, du plus récent au plus ancien (date puis `updatedAt`).
    public var sessions: [Session] {
        sessionMap.values
            .filter { $0.deleted != true }
            .sorted { $0.date != $1.date ? $0.date > $1.date : $0.updatedAt > $1.updatedAt }
    }

    /// Une séance par son id, `nil` si elle n'existe pas ou a été supprimée.
    public func session(_ id: String) -> Session? {
        guard let s = sessionMap[id], s.deleted != true else { return nil }
        return s
    }

    /// Catalogue de base fusionné avec les corrections, trié par nom, sans les supprimés.
    public var exercises: [Exercise] {
        mergedExercises
            .filter { $0.deleted != true }
            .sorted { $0.name.compare($1.name, locale: Locale(identifier: "fr_FR")) == .orderedAscending }
    }

    public var exerciseById: [String: Exercise] {
        Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    }

    /// Comme `exerciseById`, mais avec les machines masquées : pour l'historique, les records
    /// et « Dernière fois », qui doivent toujours afficher le nom.
    public var exerciseAnyById: [String: Exercise] {
        Dictionary(uniqueKeysWithValues: mergedExercises.map { ($0.id, $0) })
    }

    /// Catalogue de base avec les corrections, puis les machines perso utilisables.
    private var mergedExercises: [Exercise] {
        var result = Catalogue.base.map { overrides[$0.id]?.applied(to: $0) ?? $0 }
        result += overrides.values.filter { !Catalogue.baseIds.contains($0.id) }.compactMap { $0.applied(to: nil) }
        return result
    }

    /// Le cycle enregistré, sinon le cycle de départ.
    public var cycle: Cycle { storedCycle ?? .standard }

    public var me: Profile {
        profileMap[meId] ?? profiles.first ?? Self.defaultProfiles[0]
    }

    public var partner: Profile {
        Rules.partner(of: meId, in: profiles) ?? Self.defaultProfiles.first { $0.id != meId }!
    }

    // MARK: Initialisation

    public init(fileURL: URL) {
        self.fileURL = fileURL
        profileMap = Dictionary(uniqueKeysWithValues: Self.defaultProfiles.map { ($0.id, $0) })
        sessionMap = [:]
        overrides = [:]
        meId = Self.clementId
        load()
    }

    /// Fichier de démonstration, à côté du vrai fichier : `suivi.json` → `suivi-demo.json`.
    /// Le mode démo ne doit jamais toucher le vrai fichier.
    public nonisolated static func demoFileURL(besides realFile: URL) -> URL {
        realFile.deletingLastPathComponent().appendingPathComponent("suivi-demo.json")
    }

    /// Démarre avec les données de démonstration (écrase le contenu de `fileURL`, qui doit être
    /// un fichier de démo, voir `demoFileURL(besides:)`, jamais le vrai `suivi.json`).
    public static func demo(fileURL: URL, today: String, now: Date) -> AppStore {
        let store = AppStore(fileURL: fileURL)
        let d = DemoData.cache(today: today, now: now)
        store.profileMap = Dictionary(uniqueKeysWithValues: d.profiles.map { ($0.id, $0) })
        store.sessionMap = Dictionary(uniqueKeysWithValues: d.sessions.map { ($0.id, $0) })
        store.overrides = Dictionary(uniqueKeysWithValues: d.exercises.map { ($0.id, ExerciseOverride($0)) })
        store.meId = clementId
        store.storedCycle = nil
        store.unreadableCycle = nil
        store.persist()
        return store
    }

    // MARK: Écriture

    public func saveSession(_ session: Session) {
        var s = session
        s.updatedAt = Self.timestamp(Date())
        sessionMap[s.id] = s
        persist()
    }

    /// Suppression douce : la séance reste dans le fichier avec `deleted = true`.
    public func deleteSession(id: String) {
        guard var s = sessionMap[id] else { return }
        s.deleted = true
        saveSession(s)
    }

    /// Enregistre la machine entière (`deleted = true` la masque sans l'oublier).
    public func saveExercise(_ exercise: Exercise) {
        overrides[exercise.id] = ExerciseOverride(exercise)
        persist()
    }

    public func saveProfile(_ profile: Profile) {
        profileMap[profile.id] = profile
        persist()
    }

    /// Enregistre le cycle (il remplace aussi une valeur illisible lue au chargement).
    public func saveCycle(_ cycle: Cycle) {
        storedCycle = cycle
        unreadableCycle = nil
        persist()
    }

    public func switchProfile(to id: String) {
        guard profileMap[id] != nil else { return }
        meId = id
        persist()
    }

    /// Pose `startedAt` s'il manque et passe la séance à `.done`.
    public func startOrResume(sessionId: String) {
        guard var s = sessionMap[sessionId] else { return }
        if s.startedAt == nil { s.startedAt = Self.timestamp(Date()) }
        s.status = .done
        saveSession(s)
    }

    // MARK: Sauvegarde

    /// Sauvegarde au format du web. Les corrections du catalogue y sont complètes (fusionnées sur
    /// la machine de base), les séances supprimées y restent pour que la suppression voyage.
    public func exportData() -> Data {
        let base = Dictionary(uniqueKeysWithValues: Catalogue.base.map { ($0.id, $0) })
        let full = overrides.mapValues { o in o.applied(to: base[o.id]).map(ExerciseOverride.init) ?? o }
        return Backup.export(profiles: profileMap, sessions: sessionMap, exercises: full, cycle: storedCycle,
                             now: Date())
    }

    /// Importe une sauvegarde (web ou iOS) puis écrit une seule fois.
    /// - Séances : la plus récente selon `updatedAt` gagne, suppressions comprises.
    /// - Corrections de machines : fusionnées champ par champ, l'importée l'emporte.
    /// - Profils : jamais remplacés ; seuls `avatar` et `settings` sont pris s'ils manquent ici.
    /// - Cycle : pris seulement si le téléphone n'en a aucun (ni enregistré, ni illisible gardé).
    /// Lève `BackupError` si ce n'est pas une sauvegarde, ou si le fichier de l'appli n'a pas pu
    /// être lu (rien n'est alors changé, ni en mémoire ni sur disque).
    public func importData(_ data: Data) throws -> ImportSummary {
        guard !writesBlocked else { throw BackupError.storeLocked }
        let content = try Backup.decode(data)
        var summary = ImportSummary(added: 0, updated: 0, kept: 0, skipped: content.skipped)
        for incoming in content.sessions.values {
            guard let local = sessionMap[incoming.id] else {
                sessionMap[incoming.id] = incoming
                // Une suppression d'une séance inconnue ici est gardée, sans rien ajouter de visible.
                if incoming.deleted != true { summary.added += 1 }
                continue
            }
            switch Self.compareTimestamps(incoming.updatedAt, local.updatedAt) {
            case .orderedDescending:
                sessionMap[incoming.id] = incoming
                summary.updated += 1
            case .orderedAscending:
                summary.kept += 1
            case .orderedSame:
                break
            }
        }
        for incoming in content.exercises.values {
            overrides[incoming.id] = overrides[incoming.id]?.merging(incoming) ?? incoming
        }
        for incoming in content.profiles.values {
            guard var local = profileMap[incoming.id] else { continue }
            if local.avatar == nil { local.avatar = incoming.avatar }
            if local.settings == nil { local.settings = incoming.settings }
            profileMap[incoming.id] = local
        }
        if storedCycle == nil, unreadableCycle == nil, let cycle = content.cycle { storedCycle = cycle }
        persist()
        return summary
    }

    /// Compare deux horodatages ISO 8601 (avec ou sans millisecondes) ; texte brut en dernier recours.
    nonisolated static func compareTimestamps(_ a: String, _ b: String) -> ComparisonResult {
        if let da = parseTimestamp(a), let db = parseTimestamp(b) {
            return da == db ? .orderedSame : (da < db ? .orderedAscending : .orderedDescending)
        }
        return a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
    }

    private nonisolated static func parseTimestamp(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f.date(from: s) { return d }
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }

    // MARK: Fichier

    /// ISO 8601 avec millisecondes, en UTC (« 2026-11-12T17:30:00.000Z »), comme le web.
    public nonisolated static func timestamp(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            // Lecture impossible (protection des données avant le premier déverrouillage, erreur disque…) :
            // le fichier reste en place, on ne l'écrasera pas.
            writesBlocked = true
            loadProblem = "Données inaccessibles pour l'instant : rien n'a été modifié."
            Self.log.error("Lecture impossible : \(error.localizedDescription, privacy: .public)")
            return
        }
        do {
            let file = try JSONDecoder().decode(StoreFile.self, from: data)
            profileMap = file.profiles
            for p in Self.defaultProfiles where profileMap[p.id] == nil { profileMap[p.id] = p }
            sessionMap = file.sessions
            overrides = file.exercises
            storedCycle = file.cycle
            unreadableCycle = file.unreadableCycle
            if file.unreadableCycle != nil {
                Self.log.error("Cycle illisible ignoré : cycle de départ utilisé")
            }
            if file.skippedExercises > 0 {
                Self.log.error("Corrections de machines illisibles ignorées : \(file.skippedExercises, privacy: .public)")
            }
            meId = profileMap[file.meId] != nil ? file.meId : Self.clementId
        } catch {
            // Contenu illisible : copie datée à côté (les anciennes copies ne sont jamais supprimées).
            loadProblem = "Données illisibles : une copie a été gardée sur le téléphone."
            Self.log.error("Décodage impossible : \(error.localizedDescription, privacy: .public)")
            do {
                try FileManager.default.moveItem(at: fileURL, to: Self.backupURL(for: fileURL, now: Date()))
            } catch {
                // Impossible de mettre le fichier de côté : on ne l'écrase pas.
                writesBlocked = true
                Self.log.error("Copie impossible : \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// `suivi.json` → `suivi.json.corrupt-20261112-183000` (UTC), suffixe numérique si le nom existe déjà.
    nonisolated static func backupURL(for url: URL, now: Date) -> URL {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd-HHmmss"
        let base = url.appendingPathExtension("corrupt-\(f.string(from: now))")
        var candidate = base
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = URL(fileURLWithPath: base.path + "-\(n)")
            n += 1
        }
        return candidate
    }

    private func persist() {
        if writesBlocked {
            lastSaveError = "Écriture bloquée : le fichier existant n'a pas pu être lu."
            return
        }
        do {
            let file = StoreFile(profiles: profileMap, sessions: sessionMap, exercises: overrides, meId: meId,
                                 cycle: storedCycle, unreadableCycle: unreadableCycle)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(file)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            if lastSaveError != nil { lastSaveError = nil }
        } catch {
            lastSaveError = String(describing: error)
            Self.log.error("Échec de l'écriture : \(error.localizedDescription, privacy: .public)")
        }
    }
}
