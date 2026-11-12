import Testing
import Foundation
@testable import SuiviCore

struct BackupTextTests {
    func session(_ id: String, deleted: Bool? = nil) -> Session {
        var s = Session(id: id, ownerId: "local-clement", createdBy: "local-clement", date: "2026-11-12",
                        title: "Séance", status: .done, items: [], updatedAt: "2026-11-12T10:00:00.000Z")
        s.deleted = deleted
        return s
    }

    func content(sessions: Int, deleted: Int = 0, exercises: Int = 0) -> BackupContent {
        var s: [String: Session] = [:]
        for i in 0..<sessions { s["s\(i)"] = session("s\(i)") }
        for i in 0..<deleted { s["d\(i)"] = session("d\(i)", deleted: true) }
        var e: [String: ExerciseOverride] = [:]
        for i in 0..<exercises { e["e\(i)"] = ExerciseOverride(id: "e\(i)") }
        return BackupContent(profiles: [:], sessions: s, exercises: e, skipped: 0)
    }

    @Test func contentPlurals() {
        #expect(BackupText.content(content(sessions: 12, exercises: 3)) == "12 séances, 3 réglages de machines")
        #expect(BackupText.content(content(sessions: 1, exercises: 1)) == "1 séance, 1 réglage de machine")
        #expect(BackupText.content(content(sessions: 0, exercises: 2)) == "aucune séance, 2 réglages de machines")
        #expect(BackupText.content(content(sessions: 5)) == "5 séances")
        #expect(BackupText.content(content(sessions: 0)) == "aucune séance")
    }

    @Test func contentIgnoresDeletedSessions() {
        #expect(BackupText.content(content(sessions: 2, deleted: 4)) == "2 séances")
        #expect(BackupText.content(content(sessions: 0, deleted: 3)) == "aucune séance")
    }

    func s(_ a: Int, _ u: Int, _ k: Int, _ x: Int = 0) -> String {
        BackupText.summary(ImportSummary(added: a, updated: u, kept: k, skipped: x))
    }

    @Test func summaryPinnedExamples() {
        #expect(s(20, 0, 0) == "20 séances ajoutées.")
        #expect(s(10, 2, 0) == "10 séances ajoutées, 2 mises à jour.")
        #expect(s(0, 0, 3) == "3 séances gardées car plus récentes sur ce téléphone.")
        #expect(s(1, 1, 1, 1) == "1 séance ajoutée, 1 mise à jour, 1 gardée car plus récente sur ce téléphone, 1 illisible ignorée.")
        #expect(s(0, 0, 0) == "Tout était déjà à jour.")
    }

    @Test func summaryNamesSessionsOnlyInFirstPart() {
        #expect(s(1, 0, 0) == "1 séance ajoutée.")
        #expect(s(0, 1, 0) == "1 séance mise à jour.")
        #expect(s(0, 2, 0) == "2 séances mises à jour.")
        #expect(s(0, 0, 1) == "1 séance gardée car plus récente sur ce téléphone.")
        #expect(s(0, 0, 0, 1) == "1 séance illisible ignorée.")
        #expect(s(0, 0, 0, 2) == "2 séances illisibles ignorées.")
        #expect(s(0, 2, 3) == "2 séances mises à jour, 3 gardées car plus récentes sur ce téléphone.")
        #expect(s(0, 0, 1, 2) == "1 séance gardée car plus récente sur ce téléphone, 2 illisibles ignorées.")
    }

    @Test func summarySkipsZeroParts() {
        #expect(!s(3, 0, 0).contains("jour"))
        #expect(!s(3, 0, 0).contains("gardée"))
        #expect(!s(3, 1, 2).contains("illisible"))
    }

    @Test func fileName() {
        #expect(BackupText.fileName(today: "2026-11-12") == "suivi-muscu-2026-11-12.json")
    }
}
