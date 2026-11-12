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
}
