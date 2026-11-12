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

    @Test func corruptFileStartsFreshAndKeepsBackup() throws {
        let url = tempFile()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("pas du json {".utf8).write(to: url)
        let store = AppStore(fileURL: url)
        #expect(store.profiles.count == 2)
        let backup = url.appendingPathExtension("corrupt")
        #expect(FileManager.default.fileExists(atPath: backup.path))
        #expect(try Data(contentsOf: backup) == Data("pas du json {".utf8))
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
}
