import Foundation
import Testing
@testable import SuiviCore

@Suite struct StatsTests {
    static let now = Rules.parseTimestamp("2026-11-12T12:00:00.000Z")!

    private func done(_ n: Int = 3) -> [SessionItem] {
        [SessionItem(id: "i", exerciseId: "m-chest-press",
                     sets: (0..<n).map { _ in SetEntry(kg: 40, reps: 10, done: true) })]
    }

    private func session(_ id: String, owner: String = "p1", date: String = "2026-11-12",
                         items: [SessionItem]? = nil, durationMin: Int? = nil,
                         startedAt: String? = nil, endedAt: String? = nil,
                         updatedAt: String = "2026-11-12T10:00:00.000Z",
                         status: SessionStatus = .done) -> Session {
        Session(id: id, ownerId: owner, createdBy: owner, date: date, title: "Séance", status: status,
                items: items ?? done(), durationMin: durationMin, startedAt: startedAt,
                endedAt: endedAt, updatedAt: updatedAt)
    }

    private let clement = Profile(id: "p1", name: "Clément", slot: 1)

    @Test func typedDurationWins() {
        let s = session("a", durationMin: 70, startedAt: "2026-11-12T10:00:00.000Z",
                        endedAt: "2026-11-12T12:00:00.000Z")
        #expect(Stats.durationMinutes(s, now: Self.now) == 70)
    }

    @Test func typedDurationCapped() {
        #expect(Stats.durationMinutes(session("a", durationMin: 300), now: Self.now) == 240)
    }

    @Test func unfinishedSessionCappedAt150() {
        let s = session("a", startedAt: "2026-11-11T18:00:00.000Z", updatedAt: "2026-11-12T08:00:00.000Z")
        #expect(Stats.durationMinutes(s, now: Self.now) == 150)
    }

    @Test func derivedDurationFromStartAndEnd() {
        let s = session("a", startedAt: "2026-11-12T10:00:00.000Z", endedAt: "2026-11-12T10:55:30.000Z")
        #expect(Stats.durationMinutes(s, now: Self.now) == 55)
    }

    @Test func negativeAndMissingDurations() {
        let back = session("a", startedAt: "2026-11-12T10:00:00.000Z", endedAt: "2026-11-12T09:00:00.000Z")
        #expect(Stats.durationMinutes(back, now: Self.now) == 0)
        #expect(Stats.durationMinutes(session("b"), now: Self.now) == 0)
    }

    @Test func nonCountingSessionIsWorthNothing() {
        let empty = session("a", items: [SessionItem(id: "i", exerciseId: "x",
                                                     sets: [SetEntry(kg: 40, reps: 10, done: false)])],
                            durationMin: 60)
        #expect(!Stats.counts(empty))
        #expect(Stats.durationMinutes(empty, now: Self.now) == 0)
        let w = Stats.week([empty], owner: clement, containing: "2026-11-12", now: Self.now)
        #expect(w.sessions == 0 && w.minutes == 0)
    }

    @Test func plannedSessionWithProgressCounts() {
        #expect(Stats.counts(session("a", status: .planned)))
        let cardio = SessionItem(id: "i", exerciseId: "c", cardio: CardioEntry(minutes: 15, done: true))
        #expect(Stats.counts(session("b", items: [cardio])))
    }

    @Test func sundayBelongsToPreviousMonday() {
        let s = session("a", date: "2026-11-15", durationMin: 50)
        #expect(Stats.week([s], owner: clement, containing: "2026-11-12", now: Self.now).sessions == 1)
        #expect(Stats.week([s], owner: clement, containing: "2026-11-16", now: Self.now).sessions == 0)
    }

    @Test func weekSumsSessionsAndMinutes() {
        let list = [session("a", date: "2026-11-09", durationMin: 55),
                    session("b", date: "2026-11-10", durationMin: 50),
                    session("c", date: "2026-11-12", durationMin: 60),
                    session("d", owner: "p2", date: "2026-11-12", durationMin: 99)]
        let w = Stats.week(list, owner: clement, containing: "2026-11-12", now: Self.now)
        #expect(w.sessions == 3)
        #expect(w.minutes == 165)
        #expect(Stats.formatHours(w.minutes) == "2h45")
    }

    @Test func goalDefaultsTo3() {
        #expect(Stats.week([], owner: clement, containing: "2026-11-12", now: Self.now).goal == 3)
        let p = Profile(id: "p1", name: "Clément", slot: 1, settings: ProfileSettings(weeklyGoal: 5))
        #expect(Stats.week([], owner: p, containing: "2026-11-12", now: Self.now).goal == 5)
    }

    @Test func togetherCountsSharedDays() {
        let list = [session("c1", owner: "p1", date: "2026-11-09", durationMin: 40),
                    session("c2", owner: "p1", date: "2026-11-12", durationMin: 60),
                    session("j1", owner: "p2", date: "2026-11-11", durationMin: 30),
                    session("j2", owner: "p2", date: "2026-11-12", durationMin: 45)]
        let t = Stats.together(list, a: "p1", b: "p2", containing: "2026-11-12", now: Self.now)
        #expect(t.days == 1)
        #expect(t.minutes == 105)
    }

    @Test func formatHours() {
        #expect(Stats.formatHours(165) == "2h45")
        #expect(Stats.formatHours(60) == "1h")
        #expect(Stats.formatHours(45) == "45 min")
        #expect(Stats.formatHours(0) == "0 min")
        #expect(Stats.formatHours(125) == "2h05")
    }

    @Test func e1rmAndTonnage() {
        #expect(Stats.e1rm(kg: 60, reps: 1) == 60)
        #expect(Stats.e1rm(kg: 60, reps: 0) == 0)
        #expect(abs(Stats.e1rm(kg: 60, reps: 30) - 60 * (1 + 12.0 / 30)) < 1e-9)
        #expect(Stats.sessionTonnage(session("a", items: done(3))) == 1200)
    }

    @Test func sessionPRsDetectsBeatenRecord() {
        func s(_ id: String, _ date: String, _ kg: Double) -> Session {
            session(id, date: date, items: [SessionItem(id: "i", exerciseId: "m-chest-press",
                                                        sets: [SetEntry(kg: kg, reps: 10, done: true)])])
        }
        let before = s("a", "2026-11-05", 40)
        let better = s("b", "2026-11-12", 50)
        let same = s("c", "2026-11-12", 40)
        #expect(Stats.sessionPRs([before, better], better) == ["m-chest-press"])
        #expect(Stats.sessionPRs([before, same], same).isEmpty)
        #expect(Stats.sessionPRs([better], better).isEmpty)
    }

    @Test func previousBestsAndRecordFlag() {
        let before = session("a", date: "2026-11-05", items: [
            SessionItem(id: "i", exerciseId: "m-chest-press", sets: [SetEntry(kg: 40, reps: 10, done: true)])])
        let now = session("b", date: "2026-11-12", items: [
            SessionItem(id: "j", exerciseId: "m-chest-press", sets: [SetEntry(kg: 45, reps: 10, done: true)])])
        let best = Stats.previousBests([before, now], now)["m-chest-press"] ?? 0
        #expect(abs(best - Stats.e1rm(kg: 40, reps: 10)) < 0.001)
        #expect(Stats.isRecord(SetEntry(kg: 45, reps: 10, done: true), best: best))
        #expect(!Stats.isRecord(SetEntry(kg: 45, reps: 10, done: false), best: best))
        #expect(!Stats.isRecord(SetEntry(kg: 40, reps: 10, done: true), best: best))
        #expect(!Stats.isRecord(SetEntry(kg: 45, reps: 10, done: true), best: 0))
    }

    @Test func finishPrefillUsesNowWhenNotEnded() {
        let now = Rules.parseTimestamp("2026-11-12T11:00:00.000Z")!
        var s = Session(id: "s", ownerId: "local-clement", createdBy: "local-clement", date: "2026-11-12",
                        title: "T", status: .done,
                        items: [SessionItem(id: "i", exerciseId: "m-chest-press", sets: [SetEntry(kg: 40, reps: 10, done: true)])],
                        updatedAt: "2026-11-12T10:05:00.000Z")
        s.startedAt = "2026-11-12T10:00:00.000Z"
        #expect(Stats.finishPrefillMinutes(s, now: now) == 60)
        s.endedAt = "2026-11-12T10:44:00.000Z"
        #expect(Stats.finishPrefillMinutes(s, now: now) == 45)
        s.endedAt = nil
        s.startedAt = "2026-11-12T01:00:00.000Z"
        #expect(Stats.finishPrefillMinutes(s, now: now) == 240)
        s.durationMin = 33
        #expect(Stats.finishPrefillMinutes(s, now: now) == 33)
    }
}
