import Testing
import Foundation
@testable import SuiviCore

@MainActor
struct StoreTests {
    func tempFile() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("suivi.json")
    }

    func makeSession(id: String = "s1", date: String = "2026-11-12", done: Int = 2) -> Session {
        let sets = (0..<3).map { SetEntry(kg: 40, reps: 10, done: $0 < done) }
        return Session(id: id, ownerId: "local-clement", createdBy: "local-clement", date: date,
                       title: "Test", status: .done,
                       items: [SessionItem(id: "i1", exerciseId: "m-chest-press", sets: sets)],
                       updatedAt: "2026-11-12T10:00:00.000Z")
    }

    @Test func freshStoreHasTwoProfiles() {
        let store = AppStore(fileURL: tempFile())
        #expect(store.profiles.count == 2)
        #expect(store.meId == "local-clement")
        #expect(store.me.name == "Clément")
        #expect(store.me.slot == 1)
        #expect(store.partner.id == "local-jules")
        #expect(store.partner.slot == 2)
        #expect(store.sessions.isEmpty)
    }

    @Test func reloadKeepsLiveSession() {
        let url = tempFile()
        let store = AppStore(fileURL: url)
        store.saveSession(makeSession())
        let again = AppStore(fileURL: url)
        #expect(again.sessions.count == 1)
        let doneCount = again.sessions[0].items[0].sets.filter(\.done).count
        #expect(doneCount == 2)
    }

    @Test func deletedSessionsAreHidden() throws {
        let url = tempFile()
        let store = AppStore(fileURL: url)
        store.saveSession(makeSession())
        store.deleteSession(id: "s1")
        #expect(store.sessions.isEmpty)
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let sessions = json?["sessions"] as? [String: Any]
        let s1 = sessions?["s1"] as? [String: Any]
        #expect(s1?["deleted"] as? Bool == true)
        #expect(AppStore(fileURL: url).sessions.isEmpty)
    }

    @Test func exerciseOverrideMerges() {
        let url = tempFile()
        let store = AppStore(fileURL: url)
        var ex = store.exerciseById["m-chest-press"]!
        ex.note = "Siège cran 4"
        store.saveExercise(ex)
        let got = store.exerciseById["m-chest-press"]!
        #expect(got.note == "Siège cran 4")
        #expect(got.name == "Chest press")
        #expect(store.exercises.count == Catalogue.base.count)
        #expect(AppStore(fileURL: url).exerciseById["m-chest-press"]?.note == "Siège cran 4")
    }

    @Test func switchProfileAndStartOrResume() {
        let url = tempFile()
        let store = AppStore(fileURL: url)
        store.switchProfile(to: "local-jules")
        #expect(store.me.id == "local-jules")
        #expect(store.partner.id == "local-clement")
        #expect(AppStore(fileURL: url).meId == "local-jules")
        var planned = makeSession(done: 0)
        planned.status = .planned
        store.saveSession(planned)
        store.startOrResume(sessionId: "s1")
        let s = store.sessions[0]
        #expect(s.status == .done)
        #expect(s.startedAt?.hasSuffix("Z") == true)
        #expect(s.startedAt?.contains(".") == true)
        let first = s.startedAt
        store.startOrResume(sessionId: "s1")
        #expect(store.sessions[0].startedAt == first)
    }

    @Test func sessionsSortedNewestFirst() {
        let store = AppStore(fileURL: tempFile())
        store.saveSession(makeSession(id: "a", date: "2026-11-01"))
        store.saveSession(makeSession(id: "b", date: "2026-11-10"))
        #expect(store.sessions.map(\.id) == ["b", "a"])
    }

    func backups(of url: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: url.deletingLastPathComponent(),
                                                    includingPropertiesForKeys: nil)
            .filter { $0.lastPathComponent.hasPrefix("suivi.json.corrupt-") }
    }

    @Test func corruptFileStartsFreshAndKeepsTimestampedBackup() throws {
        let url = tempFile()
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Une copie plus ancienne ne doit jamais être supprimée.
        let older = dir.appendingPathComponent("suivi.json.corrupt-20200101-000000")
        try Data("ancienne copie".utf8).write(to: older)
        try Data("pas du json {".utf8).write(to: url)
        let store = AppStore(fileURL: url)
        #expect(store.profiles.count == 2)
        #expect(store.sessions.isEmpty)
        #expect(store.loadProblem == "Données illisibles : une copie a été gardée sur le téléphone.")
        #expect(!FileManager.default.fileExists(atPath: url.path))
        let found = try backups(of: url)
        #expect(found.count == 2)
        #expect(try Data(contentsOf: older) == Data("ancienne copie".utf8))
        let fresh = try #require(found.first { $0.lastPathComponent != older.lastPathComponent })
        #expect(try Data(contentsOf: fresh) == Data("pas du json {".utf8))
        // Après une copie réussie, on peut écrire normalement.
        store.saveSession(makeSession())
        #expect(store.lastSaveError == nil)
        #expect(AppStore(fileURL: url).sessions.count == 1)
    }

    @Test func secondCorruptionSameSecondKeepsBothBackups() throws {
        let url = tempFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let now = Date()
        let first = AppStore.backupURL(for: url, now: now)
        try Data("a".utf8).write(to: first)
        let second = AppStore.backupURL(for: url, now: now)
        #expect(second != first)
    }

    @Test func unreadableFileIsLeftAloneAndWritesAreBlocked() throws {
        let url = tempFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let original = try JSONEncoder().encode(StoreFile(
            profiles: Dictionary(uniqueKeysWithValues: AppStore.defaultProfiles.map { ($0.id, $0) }),
            sessions: ["s1": makeSession()], exercises: [:], meId: AppStore.clementId))
        try original.write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path) }

        let store = AppStore(fileURL: url)
        #expect(store.loadProblem == "Données inaccessibles pour l'instant : rien n'a été modifié.")
        #expect(store.sessions.isEmpty)
        #expect(try backups(of: url).isEmpty)

        store.saveSession(makeSession(id: "s2"))
        #expect(store.lastSaveError != nil)
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
        #expect(try Data(contentsOf: url) == original)
    }

    @Test func unreadablePathIsNotMovedNorOverwritten() throws {
        // Un dossier à la place du fichier : la lecture échoue, rien ne doit bouger.
        let url = tempFile()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let store = AppStore(fileURL: url)
        #expect(store.loadProblem != nil)
        store.saveSession(makeSession())
        #expect(store.lastSaveError != nil)
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue)
        #expect(try backups(of: url).isEmpty)
    }

    @Test func demoNeverTouchesTheRealFile() throws {
        let real = tempFile()
        try FileManager.default.createDirectory(at: real.deletingLastPathComponent(), withIntermediateDirectories: true)
        let bytes = Data("{\"vraies\": \"données\"}".utf8)
        try bytes.write(to: real)
        let demoURL = AppStore.demoFileURL(besides: real)
        #expect(demoURL != real)
        #expect(demoURL.deletingLastPathComponent() == real.deletingLastPathComponent())
        let now = Date()
        let store = AppStore.demo(fileURL: demoURL, today: Dates.isoDate(now), now: now)
        #expect(!store.sessions.isEmpty)
        #expect(FileManager.default.fileExists(atPath: demoURL.path))
        #expect(try Data(contentsOf: real) == bytes)
    }

    @Test func writeFailureIsSurfaced() throws {
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("x".utf8).write(to: blocker)
        let store = AppStore(fileURL: blocker.appendingPathComponent("suivi.json"))
        #expect(store.lastSaveError == nil)
        store.saveSession(makeSession())
        #expect(store.lastSaveError != nil)
        #expect(store.sessions.count == 1)
        let ok = AppStore(fileURL: tempFile())
        ok.saveSession(makeSession())
        #expect(ok.lastSaveError == nil)
    }

    @Test func demoDataLoads() {
        let now = Date()
        let today = Dates.isoDate(now)
        let store = AppStore.demo(fileURL: tempFile(), today: today, now: now)
        #expect(store.profiles.count == 2)
        #expect(store.sessions.filter { $0.status == .done && $0.endedAt != nil }.count >= 16)
        let tomorrow = Dates.addDays(today, 1)
        for id in ["local-clement", "local-jules"] {
            #expect(store.sessions.contains { $0.ownerId == id && $0.date == tomorrow
                && $0.status == .planned && $0.title == "Séance à deux" })
        }
        #expect(store.sessions.contains { $0.ownerId == "local-jules" && Rules.isLive($0, now: now) })
        #expect(store.me.needsHelp == true)
        #expect(store.exerciseById["m-chest-press"]?.note == "Siège cran 4, dossier cran 2")
    }

    @Test func sessionLookupHidesDeleted() {
        let store = AppStore(fileURL: tempFile())
        store.saveSession(makeSession())
        #expect(store.session("s1")?.title == "Test")
        store.deleteSession(id: "s1")
        #expect(store.session("s1") == nil)
        #expect(store.session("absent") == nil)
    }

    // MARK: Corrections de machines tolérantes

    func writeRaw(_ json: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(json.utf8).write(to: url)
    }

    func storeJSON(sessions: String = "{}", exercises: String = "{}") -> String {
        """
        {"meId": "local-clement",
         "profiles": {"local-clement": {"id": "local-clement", "name": "Clément", "slot": 1},
                      "local-jules": {"id": "local-jules", "name": "Jules", "slot": 2}},
         "sessions": \(sessions), "exercises": \(exercises)}
        """
    }

    func encoded(_ session: Session) throws -> String {
        String(data: try JSONEncoder().encode(session), encoding: .utf8)!
    }

    @Test func partialOverrideMergesOntoCatalogue() throws {
        let url = tempFile()
        try writeRaw(storeJSON(exercises: #"{"m-chest-press": {"id": "m-chest-press", "note": "Siège cran 4"}}"#), to: url)
        let store = AppStore(fileURL: url)
        #expect(store.loadProblem == nil)
        #expect(try backups(of: url).isEmpty)
        let ex = try #require(store.exerciseById["m-chest-press"])
        #expect(ex.note == "Siège cran 4")
        #expect(ex.name == "Chest press")
        #expect(ex.posture == .transfert)
        #expect(ex.step == 5)
        // Une écriture ne perd pas la correction.
        store.saveSession(makeSession())
        #expect(AppStore(fileURL: url).exerciseById["m-chest-press"]?.note == "Siège cran 4")
    }

    @Test func unreadableOverrideDoesNotCorruptTheFile() throws {
        let url = tempFile()
        try writeRaw(storeJSON(sessions: #"{"s1": \#(try encoded(makeSession()))}"#,
                               exercises: #"{"bad": 12, "m-curl": {"id": "m-curl", "note": "Cran 3"}}"#), to: url)
        let store = AppStore(fileURL: url)
        #expect(store.loadProblem == nil)
        #expect(try backups(of: url).isEmpty)
        #expect(store.sessions.count == 1)
        #expect(store.exerciseById["m-curl"]?.note == "Cran 3")
        #expect(store.exercises.count == Catalogue.base.count)
    }

    @Test func unreadableSessionInStoreFileStillGoesToCorrupt() throws {
        let url = tempFile()
        let raw = storeJSON(sessions: #"{"s1": \#(try encoded(makeSession())), "s2": {"id": "s2", "title": 3}}"#)
        try writeRaw(raw, to: url)
        let store = AppStore(fileURL: url)
        #expect(store.loadProblem == "Données illisibles : une copie a été gardée sur le téléphone.")
        #expect(store.sessions.isEmpty)
        let found = try backups(of: url)
        #expect(found.count == 1)
        #expect(try Data(contentsOf: found[0]) == Data(raw.utf8))
    }

    @Test func hiddenExerciseStillResolvesInHistory() {
        let url = tempFile()
        let store = AppStore(fileURL: url)
        var ex = store.exerciseById["m-chest-press"]!
        ex.deleted = true
        store.saveExercise(ex)
        #expect(store.exerciseById["m-chest-press"] == nil)
        #expect(!store.exercises.contains { $0.id == "m-chest-press" })
        #expect(store.exerciseAnyById["m-chest-press"]?.name == "Chest press")
        #expect(AppStore(fileURL: url).exerciseAnyById["m-chest-press"]?.deleted == true)
    }

    // MARK: Sauvegarde et import

    func backupData(sessions: [Session] = [], extraSessions: [String: String] = [:],
                    exercises: String = "{}", profiles: String = "{}") throws -> Data {
        var entries = try sessions.map { "\"\($0.id)\": \(try encoded($0))" }
        entries += extraSessions.map { "\"\($0.key)\": \($0.value)" }
        let json = """
        {"version": 1, "exportedAt": "2026-11-12T12:00:00.000Z", "profiles": \(profiles),
         "sessions": {\(entries.joined(separator: ","))}, "exercises": \(exercises)}
        """
        return Data(json.utf8)
    }

    func withUpdatedAt(_ s: Session, _ updatedAt: String, title: String? = nil) -> Session {
        var s = s
        s.updatedAt = updatedAt
        if let title { s.title = title }
        return s
    }

    @Test func importKeepsNewerLocalSession() throws {
        let store = AppStore(fileURL: tempFile())
        store.saveSession(withUpdatedAt(makeSession(), "x", title: "Locale"))  // updatedAt = maintenant
        let older = withUpdatedAt(makeSession(), "2020-01-01T00:00:00.000Z", title: "Ancienne")
        let summary = try store.importData(try backupData(sessions: [older]))
        #expect(summary == ImportSummary(added: 0, updated: 0, kept: 1, skipped: 0))
        #expect(store.session("s1")?.title == "Locale")
    }

    @Test func importAddsAndUpdates() throws {
        let url = tempFile()
        let store = AppStore(fileURL: url)
        store.saveSession(withUpdatedAt(makeSession(), "x", title: "Locale"))
        let newer = withUpdatedAt(makeSession(), "2099-01-01T00:00:00.000Z", title: "Importée")
        let fresh = withUpdatedAt(makeSession(id: "s2"), "2026-11-01T00:00:00.000Z", title: "Nouvelle")
        let summary = try store.importData(try backupData(sessions: [newer, fresh]))
        #expect(summary == ImportSummary(added: 1, updated: 1, kept: 0, skipped: 0))
        #expect(store.session("s1")?.title == "Importée")
        #expect(store.session("s1")?.updatedAt == "2099-01-01T00:00:00.000Z")
        #expect(store.session("s2")?.title == "Nouvelle")
        // Une seule écriture, à la fin : un nouveau chargement voit tout.
        let again = AppStore(fileURL: url)
        #expect(again.session("s1")?.title == "Importée")
        #expect(again.session("s2")?.title == "Nouvelle")
    }

    @Test func importIgnoresIdenticalSession() throws {
        let store = AppStore(fileURL: tempFile())
        store.saveSession(makeSession())
        let same = try #require(store.session("s1"))
        let summary = try store.importData(try backupData(sessions: [same]))
        #expect(summary == ImportSummary(added: 0, updated: 0, kept: 0, skipped: 0))
    }

    @Test func importSkipsUnreadableSession() throws {
        let store = AppStore(fileURL: tempFile())
        let data = try backupData(sessions: [makeSession(id: "a"), makeSession(id: "b")],
                                  extraSessions: ["c": #"{"id": "c", "date": 20261112}"#])
        let summary = try store.importData(data)
        #expect(summary == ImportSummary(added: 2, updated: 0, kept: 0, skipped: 1))
        #expect(store.sessions.map(\.id).sorted() == ["a", "b"])
    }

    @Test func importedDeletionFollowsNewestWins() throws {
        let store = AppStore(fileURL: tempFile())
        store.saveSession(withUpdatedAt(makeSession(id: "live"), "x"))
        var oldDeletion = withUpdatedAt(makeSession(id: "live"), "2020-01-01T00:00:00.000Z")
        oldDeletion.deleted = true
        #expect(try store.importData(try backupData(sessions: [oldDeletion])).kept == 1)
        #expect(store.session("live") != nil)

        var newDeletion = withUpdatedAt(makeSession(id: "live"), "2099-01-01T00:00:00.000Z")
        newDeletion.deleted = true
        #expect(try store.importData(try backupData(sessions: [newDeletion])).updated == 1)
        #expect(store.session("live") == nil)

        // Une suppression plus ancienne ne ressuscite rien.
        let oldLive = withUpdatedAt(makeSession(id: "live"), "2050-01-01T00:00:00.000Z")
        #expect(try store.importData(try backupData(sessions: [oldLive])).kept == 1)
        #expect(store.session("live") == nil)
    }

    @Test func importMergesOverridesAndOnlyFillsMissingProfileFields() throws {
        let store = AppStore(fileURL: tempFile())
        var clement = store.me
        clement.avatar = "data:image/jpeg;base64,LOCAL"
        store.saveProfile(clement)
        var chest = store.exerciseById["m-chest-press"]!
        chest.photo = "data:image/jpeg;base64,PHOTO"
        store.saveExercise(chest)
        let profiles = """
        {"local-clement": {"id": "local-clement", "name": "Autre nom", "slot": 2,
                           "avatar": "data:image/jpeg;base64,IMPORT", "settings": {"weeklyGoal": 4}},
         "local-jules": {"id": "local-jules", "name": "Jules", "slot": 2,
                         "avatar": "data:image/jpeg;base64,JULES"},
         "inconnu": {"id": "inconnu", "name": "Inconnu", "slot": 3}}
        """
        let exercises = #"{"m-chest-press": {"id": "m-chest-press", "note": "Siège cran 4"}}"#
        _ = try store.importData(try backupData(exercises: exercises, profiles: profiles))
        #expect(store.me.name == "Clément")
        #expect(store.me.slot == 1)
        #expect(store.me.avatar == "data:image/jpeg;base64,LOCAL")
        #expect(store.me.settings?.weeklyGoal == 4)
        #expect(store.partner.avatar == "data:image/jpeg;base64,JULES")
        #expect(store.profiles.count == 2)
        let merged = try #require(store.exerciseById["m-chest-press"])
        #expect(merged.note == "Siège cran 4")
        #expect(merged.photo == "data:image/jpeg;base64,PHOTO")
    }

    @Test func importRejectsNonBackupAndChangesNothing() throws {
        let url = tempFile()
        let store = AppStore(fileURL: url)
        store.saveSession(makeSession())
        let before = try Data(contentsOf: url)
        #expect(throws: BackupError.self) { try store.importData(Data("pas une sauvegarde".utf8)) }
        #expect(throws: BackupError.self) { try store.importData(Data(#"{"version": 1}"#.utf8)) }
        #expect(try Data(contentsOf: url) == before)
        #expect(store.sessions.count == 1)
    }

    @Test func importWhileWriteBlockedThrowsAndChangesNothing() throws {
        // Un dossier à la place du fichier : lecture impossible, écritures bloquées.
        let url = tempFile()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let store = AppStore(fileURL: url)
        #expect(store.loadProblem != nil)
        #expect(throws: BackupError.self) { try store.importData(try backupData(sessions: [makeSession()])) }
        #expect(store.sessions.isEmpty)
        var isDir: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue)
    }

    @Test func exportDataRoundTripsWithFullOverrides() throws {
        let url = tempFile()
        try writeRaw(storeJSON(sessions: #"{"s1": \#(try encoded(makeSession()))}"#,
                               exercises: #"{"m-chest-press": {"id": "m-chest-press", "note": "Siège cran 4"}}"#), to: url)
        let store = AppStore(fileURL: url)
        store.deleteSession(id: "s1")
        let data = store.exportData()
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["version"] as? Int == 1)
        let chest = (json["exercises"] as? [String: Any])?["m-chest-press"] as? [String: Any]
        #expect(chest?["name"] as? String == "Chest press")
        #expect(chest?["posture"] as? String == "transfert")
        #expect(chest?["note"] as? String == "Siège cran 4")
        #expect(json["meId"] == nil)
        let content = try Backup.decode(data)
        #expect(content.sessions["s1"]?.deleted == true)  // la suppression voyage aussi
        #expect(content.profiles.count == 2)

        let other = AppStore(fileURL: tempFile())
        // Une séance supprimée inconnue ici est gardée comme suppression, sans compter comme ajout.
        let summary = try other.importData(data)
        #expect(summary == ImportSummary(added: 0, updated: 0, kept: 0, skipped: 0))
        #expect(other.sessions.isEmpty)
        #expect(try Backup.decode(other.exportData()).sessions["s1"]?.deleted == true)
        #expect(other.exerciseById["m-chest-press"]?.note == "Siège cran 4")
    }

    // MARK: Cycle

    func storeJSON(sessions: String = "{}", cycle: String) -> String {
        """
        {"meId": "local-clement",
         "profiles": {"local-clement": {"id": "local-clement", "name": "Clément", "slot": 1},
                      "local-jules": {"id": "local-jules", "name": "Jules", "slot": 2}},
         "sessions": \(sessions), "exercises": {}, "cycle": \(cycle)}
        """
    }

    @Test func oldStoreFileLoadsWithStandardCycle() throws {
        let url = tempFile()
        let old = try encoded(makeSession())
        #expect(!old.contains("cycleId"))
        try writeRaw(storeJSON(sessions: #"{"s1": \#(old)}"#), to: url)
        let store = AppStore(fileURL: url)
        #expect(store.loadProblem == nil)
        #expect(try backups(of: url).isEmpty)
        #expect(store.sessions.count == 1)
        #expect(store.sessions[0].cycleId == nil)
        #expect(store.cycle == Cycle.standard)
        // Écrire n'ajoute pas de cycle tant qu'on n'en a pas enregistré.
        store.saveSession(makeSession(id: "s2"))
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        #expect(json?["cycle"] == nil)
    }

    @Test func savedCycleSurvivesReload() throws {
        let url = tempFile()
        let store = AppStore(fileURL: url)
        let mine = Cycle(templates: [
            CycleTemplate(id: "t-haut", title: "Haut", items: [CycleItem(exerciseId: "m-curl")]),
            CycleTemplate(id: "t-cardio", title: "Cardio", items: [CycleItem(exerciseId: "c-tapis", minutes: 20)]),
        ])
        store.saveCycle(mine)
        #expect(store.lastSaveError == nil)
        #expect(store.cycle == mine)
        var s = makeSession()
        s.cycleId = "t-haut"
        store.saveSession(s)
        let again = AppStore(fileURL: url)
        #expect(again.cycle == mine)
        #expect(again.session("s1")?.cycleId == "t-haut")
    }

    @Test func unreadableCycleFallsBackToStandard() throws {
        let url = tempFile()
        try writeRaw(storeJSON(sessions: #"{"s1": \#(try encoded(makeSession()))}"#, cycle: "42"), to: url)
        let store = AppStore(fileURL: url)
        #expect(store.loadProblem == nil)
        #expect(try backups(of: url).isEmpty)
        #expect(store.sessions.count == 1)
        #expect(store.cycle == Cycle.standard)
        // Une écriture ne détruit pas la valeur illisible ; seul `saveCycle` la remplace.
        store.saveSession(makeSession(id: "s2"))
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        #expect(json?["cycle"] as? Int == 42)
        #expect(AppStore(fileURL: url).sessions.count == 2)
        store.saveCycle(Cycle(templates: []))
        #expect(AppStore(fileURL: url).cycle == Cycle(templates: []))
    }

    @Test func demoHasStandardCycle() {
        let url = tempFile()
        AppStore(fileURL: url).saveCycle(Cycle(templates: []))
        let now = Date()
        let store = AppStore.demo(fileURL: url, today: Dates.isoDate(now), now: now)
        #expect(store.cycle == Cycle.standard)
        #expect(AppStore(fileURL: url).cycle == Cycle.standard)
    }
}
