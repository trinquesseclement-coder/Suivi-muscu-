import Testing
import Foundation
@testable import SuiviCore

struct BackupTests {
    func session(_ id: String, updatedAt: String = "2026-11-12T10:00:00.000Z") -> Session {
        Session(id: id, ownerId: "local-clement", createdBy: "local-clement", date: "2026-11-12",
                title: "Séance \(id)", status: .done,
                items: [SessionItem(id: "i1", exerciseId: "m-chest-press",
                                    sets: [SetEntry(kg: 40, reps: 10, done: true)], scheme: .pyramid)],
                updatedAt: updatedAt)
    }

    @Test func exportRoundTrip() throws {
        let profiles = Dictionary(uniqueKeysWithValues: AppStore.defaultProfiles.map { ($0.id, $0) })
            .mapValues { p -> Profile in
                var p = p
                p.settings = ProfileSettings(weeklyGoal: 3, defaultScheme: .classic)
                return p
            }
        let sessions = ["a": session("a"), "b": session("b")]
        var chest = Catalogue.base.first { $0.id == "m-chest-press" }!
        chest.note = "Siège cran 4"
        let exercises = ["m-chest-press": ExerciseOverride(chest)]
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let data = Backup.export(profiles: profiles, sessions: sessions, exercises: exercises, now: now)
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["version"] as? Int == 1)
        #expect(json["exportedAt"] as? String == AppStore.timestamp(now))

        let back = try Backup.decode(data)
        #expect(back.sessions == sessions)
        #expect(back.profiles == profiles)
        #expect(back.exercises["m-chest-press"]?.applied(to: nil) == chest)
        #expect(back.skipped == 0)
    }

    @Test func decodesWebExport() throws {
        let web = """
        {
          "version": 1,
          "exportedAt": "2026-11-10T08:00:00.000Z",
          "profiles": {
            "local-clement": { "id": "local-clement", "name": "Clément", "slot": 1 }
          },
          "sessions": {
            "w1": {
              "id": "w1", "ownerId": "local-clement", "createdBy": "local-clement",
              "date": "2026-11-09", "title": "Haut du corps", "status": "done",
              "items": [ { "id": "i1", "exerciseId": "m-chest-press",
                           "sets": [ { "kg": 45, "reps": 10, "done": true } ] } ],
              "updatedAt": "2026-11-09T18:00:00.000Z", "champInconnu": 42
            }
          },
          "exercises": {
            "m-chest-press": { "id": "m-chest-press", "note": "Siège cran 4" }
          }
        }
        """
        let content = try Backup.decode(Data(web.utf8))
        #expect(content.skipped == 0)
        #expect(content.profiles["local-clement"]?.name == "Clément")
        let s = try #require(content.sessions["w1"])
        #expect(s.items[0].sets[0].kg == 45)
        let override = try #require(content.exercises["m-chest-press"])
        #expect(override.note == "Siège cran 4")
        #expect(override.name == nil)
        let base = Catalogue.base.first { $0.id == "m-chest-press" }
        let merged = try #require(override.applied(to: base))
        #expect(merged.note == "Siège cran 4")
        #expect(merged.posture == .transfert)
        #expect(merged.step == 5)
    }

    @Test func customOverrideNeedsNameKindAndMuscle() throws {
        let partial = try JSONDecoder().decode(ExerciseOverride.self,
                                               from: Data(#"{"id":"perso-1","name":"Rameur maison"}"#.utf8))
        #expect(partial.applied(to: nil) == nil)
        let enough = try JSONDecoder().decode(ExerciseOverride.self, from: Data(
            #"{"id":"perso-1","name":"Rameur maison","kind":"muscu","muscle":"dos"}"#.utf8))
        let ex = try #require(enough.applied(to: nil))
        #expect(ex.name == "Rameur maison")
        #expect(ex.posture == .transfert)
        #expect(ex.help == false)
        #expect(ex.equipment == .machine)
    }

    @Test func decodeSkipsUnreadableEntries() throws {
        let json = """
        {
          "version": 1, "profiles": {},
          "sessions": { "ok": \(String(data: try JSONEncoder().encode(session("ok")), encoding: .utf8)!),
                        "ko": { "id": "ko", "title": 3 } },
          "exercises": { "m-curl": { "id": "m-curl", "note": "ok" }, "bad": 12 }
        }
        """
        let content = try Backup.decode(Data(json.utf8))
        #expect(content.sessions.keys.sorted() == ["ok"])
        #expect(content.exercises.keys.sorted() == ["m-curl"])
        #expect(content.skipped == 2)
    }

    @Test func decodeRejectsWhatIsNotABackup() {
        #expect(throws: BackupError.self) { try Backup.decode(Data("pas du json".utf8)) }
        #expect(throws: BackupError.self) { try Backup.decode(Data("[1, 2]".utf8)) }
        #expect(throws: BackupError.self) { try Backup.decode(Data(#"{"version": 1}"#.utf8)) }
        #expect(throws: BackupError.self) {
            try Backup.decode(Data(#"{"profiles": {}, "sessions": [], "exercises": {}}"#.utf8))
        }
    }

    @MainActor @Test func backupCarriesCycle() throws {
        let mine = Cycle(templates: [CycleTemplate(id: "t-haut", title: "Haut",
                                                   items: [CycleItem(exerciseId: "m-curl")])])
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let data = Backup.export(profiles: [:], sessions: [:], exercises: [:], cycle: mine, now: now)
        #expect(try Backup.decode(data).cycle == mine)
        // Sans cycle enregistré, la clé est absente ; illisible, elle est ignorée sans rejeter le reste.
        let none = Backup.export(profiles: [:], sessions: [:], exercises: [:], now: now)
        let json = try #require(try JSONSerialization.jsonObject(with: none) as? [String: Any])
        #expect(json["cycle"] == nil)
        #expect(try Backup.decode(none).cycle == nil)
        let bad = #"{"profiles": {}, "sessions": {}, "exercises": {}, "cycle": {"templates": 3}}"#
        #expect(try Backup.decode(Data(bad.utf8)).cycle == nil)

        // Import : pris s'il n'y a pas de cycle enregistré, jamais à la place de celui du téléphone.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fresh = AppStore(fileURL: dir.appendingPathComponent("a.json"))
        _ = try fresh.importData(data)
        #expect(fresh.cycle == mine)
        let phone = Cycle(templates: [])
        let owned = AppStore(fileURL: dir.appendingPathComponent("b.json"))
        owned.saveCycle(phone)
        _ = try owned.importData(data)
        #expect(owned.cycle == phone)
        #expect(AppStore(fileURL: dir.appendingPathComponent("b.json")).cycle == phone)
        // L'export de l'appli emporte le cycle enregistré.
        #expect(try Backup.decode(owned.exportData()).cycle == phone)
    }
}
