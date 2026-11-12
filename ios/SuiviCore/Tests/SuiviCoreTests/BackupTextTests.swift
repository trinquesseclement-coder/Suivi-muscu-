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

    @Test func summaryAgreement() {
        func s(_ a: Int, _ u: Int, _ k: Int, _ x: Int = 0) -> String {
            BackupText.summary(ImportSummary(added: a, updated: u, kept: k, skipped: x))
        }
        #expect(s(10, 2, 0) == "10 ajoutées, 2 mises à jour, 0 gardée (plus récente sur ce téléphone)")
        #expect(s(0, 0, 0) == "0 ajoutée, 0 mise à jour, 0 gardée (plus récente sur ce téléphone)")
        #expect(s(1, 1, 1) == "1 ajoutée, 1 mise à jour, 1 gardée (plus récente sur ce téléphone)")
        #expect(s(0, 0, 3) == "0 ajoutée, 0 mise à jour, 3 gardées (plus récentes sur ce téléphone)")
    }

    @Test func summaryMentionsSkippedOnlyWhenAny() {
        let one = BackupText.summary(ImportSummary(added: 1, updated: 0, kept: 0, skipped: 1))
        #expect(one.hasSuffix(", 1 illisible ignorée"))
        let many = BackupText.summary(ImportSummary(added: 1, updated: 0, kept: 0, skipped: 4))
        #expect(many.hasSuffix(", 4 illisibles ignorées"))
        #expect(!BackupText.summary(ImportSummary(added: 1, updated: 0, kept: 0, skipped: 0)).contains("illisible"))
    }

    @Test func fileName() {
        #expect(BackupText.fileName(today: "2026-11-12") == "suivi-muscu-2026-11-12.json")
    }
}
