import Foundation
import Testing
@testable import SuiviCore

@Suite struct LoadStatsTests {
    static let now = Rules.parseTimestamp("2026-11-12T12:00:00.000Z")!
    static let today = "2026-11-12" // jeudi, semaine du 2026-11-09

    private let byId: [String: Exercise] = [
        "m-chest-press": Exercise(id: "m-chest-press", name: "Presse pectorale", kind: .muscu, muscle: .pecs,
                                  posture: .fauteuil, help: false, equipment: .machine),
        "m-row": Exercise(id: "m-row", name: "Rowing", kind: .muscu, muscle: .dos,
                          posture: .fauteuil, help: false, equipment: .machine),
        "c-bike": Exercise(id: "c-bike", name: "Vélo", kind: .cardio, muscle: .cardio,
                           posture: .fauteuil, help: false, equipment: .cardio),
    ]

    private func sets(_ pairs: [(Double, Int)], done: Bool = true) -> [SetEntry] {
        pairs.map { SetEntry(kg: $0.0, reps: $0.1, done: done) }
    }

    private func session(_ id: String, owner: String = "p1", date: String = Self.today,
                         items: [SessionItem], status: SessionStatus = .done,
                         deleted: Bool? = nil) -> Session {
        Session(id: id, ownerId: owner, createdBy: owner, date: date, title: "Séance", status: status,
                items: items, deleted: deleted, updatedAt: "2026-11-12T10:00:00.000Z")
    }

    private func item(_ exerciseId: String, _ pairs: [(Double, Int)]) -> SessionItem {
        SessionItem(id: "i-\(exerciseId)", exerciseId: exerciseId, sets: sets(pairs))
    }

    @Test func weeksAreOldestFirstAndCount8() {
        let w = LoadStats.weeks([], ownerId: "p1", byId: byId, count: 8, today: Self.today, now: Self.now)
        #expect(w.count == 8)
        #expect(w.last?.week == "2026-11-09")
        #expect(w.first?.week == "2026-09-21")
        #expect(w.map(\.week) == w.map(\.week).sorted())
        #expect(w.allSatisfy { $0.sessions == 0 && $0.tonnage == 0 && $0.sets == 0 })
    }

    @Test func weekLoadSumsTonnageAndMuscles() {
        var chest = item("m-chest-press", [(40, 10), (40, 10)])
        chest.sets.append(SetEntry(kg: 40, reps: 10, done: false))
        let cardio = SessionItem(id: "c", exerciseId: "c-bike",
                                 cardio: CardioEntry(minutes: 15, done: true))
        let w = LoadStats.weeks([session("a", items: [chest]), session("b", date: "2026-11-10", items: [cardio])],
                                ownerId: "p1", byId: byId, count: 8, today: Self.today, now: Self.now)
        let cur = w[7]
        #expect(cur.sessions == 2)
        #expect(cur.tonnage == 800)
        #expect(cur.sets == 2)
        #expect(cur.setsByMuscle[.pecs] == 2)
        #expect(cur.cardioMinutes == 15)
        #expect(w[6].sessions == 0)
    }

    @Test func weekLoadIgnoresOtherOwnerDeletedAndEmptySessions() {
        let mine = item("m-chest-press", [(40, 10)])
        let notDone = SessionItem(id: "n", exerciseId: "m-row", sets: sets([(50, 10)], done: false))
        let w = LoadStats.weeks([
            session("a", items: [mine]),
            session("b", owner: "p2", items: [mine]),
            session("c", items: [mine], deleted: true),
            session("d", items: [notDone]),
        ], ownerId: "p1", byId: byId, count: 2, today: Self.today, now: Self.now)
        #expect(w[1].sessions == 1)
        #expect(w[1].tonnage == 400)
    }

    @Test func weekLoadDropsSessionsOutsideRange() {
        let old = session("a", date: "2026-01-05", items: [item("m-chest-press", [(40, 10)])])
        let w = LoadStats.weeks([old], ownerId: "p1", byId: byId, count: 8, today: Self.today, now: Self.now)
        #expect(w.allSatisfy { $0.sessions == 0 })
    }

    @Test func historyTopSetAndE1rm() {
        let s = session("a", items: [item("m-chest-press", [(40, 10), (45, 8)])])
        let h = LoadStats.history([s], ownerId: "p1", exerciseId: "m-chest-press")
        #expect(h.count == 1)
        #expect(h[0].topKg == 45)
        #expect(h[0].topReps == 8)
        #expect(h[0].e1rm == 45 * (1 + 8.0 / 30))
        #expect(h[0].tonnage == 40 * 10 + 45 * 8)
        #expect(h[0].sessionId == "a")
    }

    @Test func historyIsOldestFirstAndPerOwner() {
        let later = session("late", date: "2026-11-12", items: [item("m-row", [(50, 10)])])
        let earlier = session("early", date: "2026-11-02", items: [item("m-row", [(40, 10)])])
        let other = session("other", owner: "p2", items: [item("m-row", [(90, 10)])])
        let h = LoadStats.history([later, other, earlier], ownerId: "p1", exerciseId: "m-row")
        #expect(h.map(\.sessionId) == ["early", "late"])
    }

    @Test func cardioHistoryKeepsOnlyDoneEntries() {
        func cardioSession(_ id: String, date: String, done: Bool) -> Session {
            session(id, date: date, items: [SessionItem(id: "c", exerciseId: "c-bike",
                cardio: CardioEntry(minutes: 20, distanceKm: 6.5, level: 4, done: done))])
        }
        let h = LoadStats.cardioHistory([cardioSession("b", date: "2026-11-12", done: true),
                                         cardioSession("a", date: "2026-11-05", done: true),
                                         cardioSession("x", date: "2026-11-08", done: false)],
                                        ownerId: "p1", exerciseId: "c-bike")
        #expect(h.map(\.sessionId) == ["a", "b"])
        #expect(h[0] == CardioPoint(date: "2026-11-05", sessionId: "a", minutes: 20, distanceKm: 6.5, level: 4))
    }

    @Test func recordsKeepBestE1rm() {
        let s1 = session("a", date: "2026-11-01", items: [item("m-chest-press", [(40, 10)])])
        let s2 = session("b", date: "2026-11-05", items: [item("m-chest-press", [(50, 8)])])
        let s3 = session("c", date: "2026-11-09", items: [item("m-chest-press", [(45, 8)])])
        let r = LoadStats.records([s3, s1, s2], ownerId: "p1")
        #expect(r["m-chest-press"] == PR(exerciseId: "m-chest-press", kg: 50, reps: 8,
                                         e1rm: 50 * (1 + 8.0 / 30), date: "2026-11-05"))
    }

    @Test func recordsTieKeepsOldestDate() {
        let newer = session("n", date: "2026-11-09", items: [item("m-row", [(40, 10)])])
        let older = session("o", date: "2026-11-02", items: [item("m-row", [(40, 10)])])
        #expect(LoadStats.records([newer, older], ownerId: "p1")["m-row"]?.date == "2026-11-02")
        #expect(LoadStats.records([older, newer], ownerId: "p1")["m-row"]?.date == "2026-11-02")
    }

    @Test func recordsIgnoreOtherOwnerAndDeleted() {
        let theirs = session("t", owner: "p2", items: [item("m-row", [(100, 10)])])
        let gone = session("g", items: [item("m-row", [(80, 10)])], deleted: true)
        #expect(LoadStats.records([theirs, gone], ownerId: "p1").isEmpty)
    }

    @Test func doneExerciseIdsMostRecentFirst() {
        let s1 = session("a", date: "2026-11-01", items: [item("m-chest-press", [(40, 10)]),
                                                          item("m-row", [(40, 10)])])
        let s2 = session("b", date: "2026-11-09", items: [item("m-chest-press", [(40, 10)])])
        let skipped = SessionItem(id: "s", exerciseId: "c-bike", sets: sets([(0, 10)], done: false))
        let s3 = session("c", date: "2026-11-12", items: [skipped])
        #expect(LoadStats.doneExerciseIds([s1, s2, s3], ownerId: "p1") == ["m-chest-press", "m-row"])
    }

    @Test func doneExerciseIdsIncludesDoneCardio() {
        let cardio = SessionItem(id: "c", exerciseId: "c-bike", cardio: CardioEntry(minutes: 10, done: true))
        let s = session("a", date: "2026-11-12", items: [cardio])
        #expect(LoadStats.doneExerciseIds([s], ownerId: "p1") == ["c-bike"])
    }

    @Test func weeksCountValidatedSetsOfUnfinishedSession() {
        let s = session("a", items: [item("m-chest-press", [(40, 10), (40, 10)])], status: .planned)
        let cur = LoadStats.weeks([s], ownerId: "p1", byId: byId, count: 8, today: Self.today, now: Self.now)[7]
        #expect(cur.sessions == 1)
        #expect(cur.tonnage == 800)
        #expect(cur.sets == 2)
        #expect(cur.setsByMuscle[.pecs] == 2)
        #expect(LoadStats.history([s], ownerId: "p1", exerciseId: "m-chest-press").isEmpty)
        #expect(LoadStats.records([s], ownerId: "p1").isEmpty)
    }

    @Test func e1rmRepCapAtTwelveFlowsIntoHistoryAndRecords() {
        let s = session("a", items: [item("m-row", [(40, 20)])])
        let expected = 40 * (1 + 12.0 / 30)
        #expect(LoadStats.history([s], ownerId: "p1", exerciseId: "m-row")[0].e1rm == expected)
        #expect(LoadStats.records([s], ownerId: "p1")["m-row"]?.e1rm == expected)
    }
}
