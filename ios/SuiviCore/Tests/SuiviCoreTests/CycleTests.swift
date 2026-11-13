import Foundation
import Testing
@testable import SuiviCore

@Suite struct CycleTests {
    static let byId = PlanningTests.byId
    static let clement = PlanningTests.clement
    static let jules = PlanningTests.jules
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let standard = Cycle.standard

    /// Séance du cycle de `owner`, avec une série validée si `done`.
    private func cycled(_ cycleId: String?, owner: String = AppStore.clementId, date: String,
                        done: Bool = true, deleted: Bool? = nil) -> Session {
        let item = SessionItem(id: "it", exerciseId: "m-chest-press",
                               sets: [SetEntry(kg: 40, reps: 10, done: done)], scheme: .classic)
        return Session(id: UUID().uuidString, ownerId: owner, createdBy: owner, date: date, title: "Cycle",
                       status: done ? .done : .planned, items: [item], groupId: nil, cycleId: cycleId,
                       deleted: deleted, updatedAt: "\(date)T10:00:00.000Z")
    }

    private func next(_ sessions: [Session], owner: String = AppStore.clementId) -> String? {
        CyclePlanner.next(Self.standard, sessions: sessions, ownerId: owner)?.id
    }

    // MARK: Cycle de départ

    @Test func standardCycleUsesCatalogueExercises() {
        let cycle = Cycle.standard
        #expect(cycle.templates.map(\.id) == ["cycle-epaules-dos", "cycle-pecs-bras", "cycle-cardio"])
        #expect(cycle.templates.map(\.title) == ["Épaules + dos", "Pecs + bras", "Cardio"])
        for item in cycle.templates.flatMap(\.items) {
            #expect(Catalogue.baseIds.contains(item.exerciseId), "\(item.exerciseId) absent du catalogue")
        }
        #expect(cycle.templates.map(\.items.count) == [7, 7, 4])
    }

    // MARK: Séance suivante

    @Test func nextIsFirstWithoutHistory() {
        #expect(next([]) == "cycle-epaules-dos")
        #expect(CyclePlanner.last(Self.standard, sessions: [], ownerId: AppStore.clementId) == nil)
    }

    @Test func nextFollowsLastCountingSession() {
        #expect(next([cycled("cycle-epaules-dos", date: "2026-11-10")]) == "cycle-pecs-bras")
        let looped = [cycled("cycle-cardio", date: "2026-11-11"), cycled("cycle-pecs-bras", date: "2026-11-09")]
        #expect(next(looped) == "cycle-epaules-dos")
        // Une séance hors cycle plus récente ne compte pas.
        let withFree = [cycled(nil, date: "2026-11-12"), cycled("cycle-epaules-dos", date: "2026-11-10")]
        #expect(next(withFree) == "cycle-pecs-bras")
    }

    @Test func abandonedSessionDoesNotAdvance() {
        let history = [cycled("cycle-pecs-bras", date: "2026-11-12", done: false),
                       cycled("cycle-cardio", date: "2026-11-11", deleted: true),
                       cycled("cycle-epaules-dos", date: "2026-11-10")]
        #expect(CyclePlanner.last(Self.standard, sessions: history, ownerId: AppStore.clementId)?.id
                == "cycle-epaules-dos")
        #expect(next(history) == "cycle-pecs-bras")
    }

    @Test func nextIsPerPerson() {
        let history = [cycled("cycle-pecs-bras", owner: AppStore.clementId, date: "2026-11-12"),
                       cycled("cycle-epaules-dos", owner: AppStore.clementId, date: "2026-11-10"),
                       cycled("cycle-epaules-dos", owner: AppStore.julesId, date: "2026-11-10")]
        #expect(next(history, owner: AppStore.clementId) == "cycle-cardio")
        #expect(next(history, owner: AppStore.julesId) == "cycle-pecs-bras")
    }

    @Test func sameDayOrderUsesStartNotLastEdit() {
        var morning = cycled("cycle-pecs-bras", date: "2026-11-12")
        morning.startedAt = "2026-11-12T08:00:00.000Z"
        var afternoon = cycled("cycle-cardio", date: "2026-11-12")
        afternoon.startedAt = "2026-11-12T15:00:00.000Z"
        afternoon.updatedAt = "2026-11-12T16:00:00.000Z"
        // Une charge corrigée le soir dans la séance du matin : elle devient la plus récemment modifiée.
        morning.updatedAt = "2026-11-12T20:00:00.000Z"
        for order in [[morning, afternoon], [afternoon, morning]] {
            #expect(CyclePlanner.last(Self.standard, sessions: order, ownerId: AppStore.clementId)?.id
                    == "cycle-cardio")
            #expect(next(order) == "cycle-epaules-dos")
        }
    }

    @Test func startedWithoutValidatedSetDoesNotAdvance() {
        var started = cycled("cycle-pecs-bras", date: "2026-11-12", done: false)
        started.status = .done
        started.startedAt = "2026-11-12T08:00:00.000Z"
        let history = [started, cycled("cycle-epaules-dos", date: "2026-11-10")]
        #expect(CyclePlanner.last(Self.standard, sessions: history, ownerId: AppStore.clementId)?.id
                == "cycle-epaules-dos")
        #expect(next(history) == "cycle-pecs-bras")
    }

    @Test func removedTemplateIsIgnored() {
        let history = [cycled("cycle-ancien", date: "2026-11-12"), cycled("cycle-epaules-dos", date: "2026-11-10")]
        #expect(CyclePlanner.last(Self.standard, sessions: history, ownerId: AppStore.clementId)?.id
                == "cycle-epaules-dos")
        #expect(next(history) == "cycle-pecs-bras")
    }

    @Test func emptyCycleHasNoNext() {
        let empty = Cycle(templates: [])
        let history = [cycled("cycle-epaules-dos", date: "2026-11-10")]
        #expect(CyclePlanner.next(empty, sessions: history, ownerId: AppStore.clementId) == nil)
        #expect(CyclePlanner.last(empty, sessions: history, ownerId: AppStore.clementId) == nil)
    }

    // MARK: Proposer le cycle

    @Test func offersCycleWhenNothingToday() {
        let today = "2026-11-12"
        func offers(_ s: [Session]) -> Bool {
            CyclePlanner.offersCycle(sessions: s, ownerId: AppStore.clementId, today: today, now: Self.now)
        }
        var plannedToday = cycled(nil, date: today, done: false)
        plannedToday.status = .planned
        var live = cycled(nil, date: today)
        live.startedAt = AppStore.timestamp(Self.now.addingTimeInterval(-600))
        var finished = live
        finished.endedAt = AppStore.timestamp(Self.now.addingTimeInterval(-60))
        let inThreeDays = cycled(nil, date: "2026-11-15", done: false)

        #expect(!offers([plannedToday]))
        #expect(!offers([live]))
        #expect(offers([inThreeDays]))
        #expect(offers([finished]))
        #expect(offers([]))
        // Une séance supprimée ou celle de l'autre ne bloque pas.
        var deleted = plannedToday
        deleted.deleted = true
        #expect(offers([deleted]))
        var julesToday = plannedToday
        julesToday.ownerId = AppStore.julesId
        #expect(offers([julesToday]))
        #expect(!CyclePlanner.partnerIsFree(sessions: [julesToday], partnerId: AppStore.julesId,
                                            today: today, now: Self.now))
        #expect(CyclePlanner.partnerIsFree(sessions: [plannedToday], partnerId: AppStore.julesId,
                                           today: today, now: Self.now))
    }

    // MARK: Construction

    private func template(_ id: String) -> CycleTemplate {
        Self.standard.templates.first { $0.id == id }!
    }

    private func build(_ id: String, target: PlanTarget, sessions: [Session] = [],
                       byId: [String: Exercise] = CycleTests.byId) -> [Session] {
        CyclePlanner.sessions(for: template(id), target: target, me: Self.clement, partner: Self.jules,
                              date: "2026-11-14", sessions: sessions, byId: byId, now: Self.now)
    }

    private func history(_ id: String, owner: String, scheme: RepScheme, sets: [(Double, Int)]) -> Session {
        let item = SessionItem(id: "it-\(id)", exerciseId: "m-chest-press",
                               sets: sets.map { SetEntry(kg: $0.0, reps: $0.1, done: true) }, scheme: scheme)
        return Session(id: id, ownerId: owner, createdBy: owner, date: "2026-11-05", title: "Push",
                       status: .done, items: [item], updatedAt: "2026-11-05T10:00:00.000Z")
    }

    @Test func bothGetTheirOwnLoadsFromCycle() throws {
        let past = [
            history("sc", owner: Self.clement.id, scheme: .pyramid, sets: [(20, 12), (25, 10), (30, 8), (20, 12)]),
            history("sj", owner: Self.jules.id, scheme: .classic, sets: [(60, 10), (60, 10), (60, 10)]),
        ]
        let out = build("cycle-pecs-bras", target: .both, sessions: past)
        #expect(out.count == 2)
        #expect(out[0].groupId != nil)
        #expect(out[0].groupId == out[1].groupId)
        #expect(out.allSatisfy {
            $0.cycleId == "cycle-pecs-bras" && $0.title == "Pecs + bras" && $0.status == .planned
                && $0.createdBy == Self.clement.id && $0.date == "2026-11-14"
        })
        #expect(out.allSatisfy { $0.items.map(\.exerciseId) == template("cycle-pecs-bras").items.map(\.exerciseId) })
        let c = try #require(out.first { $0.ownerId == Self.clement.id }?.items.first)
        let j = try #require(out.first { $0.ownerId == Self.jules.id }?.items.first)
        #expect(c.exerciseId == "m-chest-press")
        #expect(c.sets.map(\.kg) == [20, 25, 30, 20])
        #expect(c.sets.map(\.reps) == [12, 10, 8, 12])
        #expect(j.sets.count == 3)
        #expect(j.sets.allSatisfy { $0.kg == 60 })
        #expect(!c.sets.contains { $0.kg == 60 })
        #expect(!j.sets.contains { [20, 25, 30].contains($0.kg) })
    }

    @Test func classicHistoryIsCopiedSetBySetWhateverTheTarget() throws {
        // Clément (pyramide par défaut) a fait le chest press en classique dans l'appli.
        let past = [history("sc", owner: Self.clement.id, scheme: .classic, sets: [(50, 10), (55, 8), (60, 6)])]
        let alone = try #require(build("cycle-pecs-bras", target: .me, sessions: past).first)
        let together = try #require(build("cycle-pecs-bras", target: .both, sessions: past)
            .first { $0.ownerId == Self.clement.id })
        let item = try #require(alone.items.first { $0.exerciseId == "m-chest-press" })
        #expect(item.scheme == .classic)
        #expect(item.sets == [SetEntry(kg: 50, reps: 10, done: false), SetEntry(kg: 55, reps: 8, done: false),
                              SetEntry(kg: 60, reps: 6, done: false)])
        func withoutIds(_ s: Session) -> [SessionItem] {
            s.items.map { var i = $0; i.id = ""; return i }
        }
        #expect(withoutIds(alone) == withoutIds(together))
    }

    @Test func pyramidHistoryCarriesLoadsByPositionInCycle() throws {
        var past = history("sc", owner: Self.clement.id, scheme: .pyramid, sets: [(20, 12), (25, 10), (30, 8), (22, 12)])
        past.items[0].sets[3].done = false
        for target in [PlanTarget.me, .both] {
            let mine = try #require(build("cycle-pecs-bras", target: target, sessions: [past])
                .first { $0.ownerId == Self.clement.id })
            let item = try #require(mine.items.first { $0.exerciseId == "m-chest-press" })
            #expect(item.scheme == .pyramid)
            #expect(item.sets.map(\.kg) == [20, 25, 30, 22])
        }
    }

    @Test func singleTargetBuildsOneSession() {
        let out = build("cycle-epaules-dos", target: .me)
        #expect(out.count == 1)
        #expect(out[0].groupId == nil)
        #expect(out[0].ownerId == Self.clement.id)
        #expect(out[0].cycleId == "cycle-epaules-dos")
        let forJules = build("cycle-epaules-dos", target: .partner)
        #expect(forJules.map(\.ownerId) == [Self.jules.id])
        #expect(forJules[0].createdBy == Self.clement.id)
    }

    @Test func cardioTakesTemplateMinutes() throws {
        // Même avec un dernier escalier de 25 min, la séance type impose 15 min.
        var past = history("e", owner: Self.clement.id, scheme: .classic, sets: [])
        past.items = [SessionItem(id: "c", exerciseId: "c-escalier", cardio: CardioEntry(minutes: 25, done: true))]
        for target in [PlanTarget.me, .both] {
            let out = build("cycle-cardio", target: target, sessions: [past])
            for s in out {
                let stairs = try #require(s.items.first { $0.exerciseId == "c-escalier" })
                #expect(stairs.cardio?.minutes == 15)
                #expect(s.items.first { $0.exerciseId == "c-skierg" }?.cardio?.minutes == 10)
            }
        }
    }

    @Test func hiddenExercisesAreSkipped() {
        var byId = Self.byId
        byId["m-pec-deck"] = nil
        let out = build("cycle-pecs-bras", target: .me, byId: byId)
        #expect(out.count == 1)
        #expect(out[0].items.count == 6)
        #expect(!out[0].items.contains { $0.exerciseId == "m-pec-deck" })
        #expect(build("cycle-pecs-bras", target: .both, byId: [:]).isEmpty)
    }

    @Test func editedPlanKeepsCycleId() {
        let s = build("cycle-epaules-dos", target: .me)[0]
        let edited = PlanBuilder.edited(s, specs: PlanBuilder.specs(from: s), owner: Self.clement,
                                        date: "2026-11-15", title: "", notes: nil, sessions: [],
                                        byId: Self.byId, now: Self.now)
        #expect(edited.cycleId == "cycle-epaules-dos")
    }

    @Test func cycleIdIsAbsentFromJSONWhenNil() throws {
        let plain = cycled(nil, date: "2026-11-10")
        let json = String(data: try JSONEncoder().encode(plain), encoding: .utf8)!
        #expect(!json.contains("cycleId"))
        let tagged = cycled("cycle-cardio", date: "2026-11-10")
        let back = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(tagged))
        #expect(back.cycleId == "cycle-cardio")
    }

    // MARK: Séances prévues jamais commencées

    @Test func staleSessionsSelectsOnlyUntouchedPastCycleSessions() {
        let today = "2026-11-13"
        func planned(_ id: String, owner: String = AppStore.julesId, date: String = "2026-11-12",
                     cycleId: String? = "cycle-pecs-bras") -> Session {
            var s = cycled(cycleId, owner: owner, date: date, done: false)
            s.id = id
            return s
        }
        let stale = planned("stale")
        let todays = planned("today", date: today)
        var started = planned("started")
        started.startedAt = "2026-11-12T08:00:00.000Z"
        var withSet = planned("with-set")
        withSet.items[0].sets[0].done = true
        let free = planned("free", cycleId: nil)
        let other = planned("other", owner: AppStore.clementId)
        var deleted = planned("deleted")
        deleted.deleted = true
        var done = planned("done")
        done.status = .done
        let all = [stale, todays, started, withSet, free, other, deleted, done]
        #expect(CyclePlanner.staleSessions(all, ownerIds: [AppStore.julesId], today: today).map(\.id) == ["stale"])
        #expect(Set(CyclePlanner.staleSessions(all, ownerIds: [AppStore.julesId, AppStore.clementId], today: today)
            .map(\.id)) == ["stale", "other"])
        #expect(CyclePlanner.staleSessions(all, ownerIds: [], today: today).isEmpty)
    }
}
