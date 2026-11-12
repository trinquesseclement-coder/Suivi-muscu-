import Foundation
import Observation

/// Forme du fichier : mêmes clés que le cache web, dictionnaires indexés par id.
struct StoreFile: Codable {
    var profiles: [String: Profile]
    var sessions: [String: Session]
    /// Corrections du catalogue et exercices personnalisés (valeurs complètes).
    var exercises: [String: Exercise]
    var meId: String
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
    private var overrides: [String: Exercise]
    public private(set) var meId: String

    // MARK: Lecture

    public var profiles: [Profile] { profileMap.values.sorted { $0.slot < $1.slot } }

    /// Séances non supprimées, du plus récent au plus ancien (date puis `updatedAt`).
    public var sessions: [Session] {
        sessionMap.values
            .filter { $0.deleted != true }
            .sorted { $0.date != $1.date ? $0.date > $1.date : $0.updatedAt > $1.updatedAt }
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

    private var mergedExercises: [Exercise] {
        var result = Catalogue.base.map { overrides[$0.id] ?? $0 }
        let baseIds = Set(Catalogue.base.map(\.id))
        result += overrides.values.filter { !baseIds.contains($0.id) }
        return result
    }

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

    /// Démarre avec les données de démonstration (écrase le contenu du fichier).
    public static func demo(fileURL: URL, today: String, now: Date) -> AppStore {
        let store = AppStore(fileURL: fileURL)
        let d = DemoData.cache(today: today, now: now)
        store.profileMap = Dictionary(uniqueKeysWithValues: d.profiles.map { ($0.id, $0) })
        store.sessionMap = Dictionary(uniqueKeysWithValues: d.sessions.map { ($0.id, $0) })
        store.overrides = Dictionary(uniqueKeysWithValues: d.exercises.map { ($0.id, $0) })
        store.meId = clementId
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

    public func saveExercise(_ exercise: Exercise) {
        overrides[exercise.id] = exercise
        persist()
    }

    public func saveProfile(_ profile: Profile) {
        profileMap[profile.id] = profile
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

    // MARK: Fichier

    /// ISO 8601 avec millisecondes, en UTC (« 2026-11-12T17:30:00.000Z »), comme le web.
    nonisolated static func timestamp(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let file = try JSONDecoder().decode(StoreFile.self, from: data)
            profileMap = file.profiles
            for p in Self.defaultProfiles where profileMap[p.id] == nil { profileMap[p.id] = p }
            sessionMap = file.sessions
            overrides = file.exercises
            meId = profileMap[file.meId] != nil ? file.meId : Self.clementId
        } catch {
            // Fichier illisible : on garde une copie `.corrupt` et on repart de zéro.
            let backup = fileURL.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
        }
    }

    private func persist() {
        let file = StoreFile(profiles: profileMap, sessions: sessionMap, exercises: overrides, meId: meId)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(file) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
