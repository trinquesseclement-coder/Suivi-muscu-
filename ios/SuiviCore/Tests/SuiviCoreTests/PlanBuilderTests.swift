import Foundation
import Testing
@testable import SuiviCore

@Suite struct PlanBuilderTests {
    static let byId = PlanningTests.byId
    static let clement = PlanningTests.clement
    static let jules = PlanningTests.jules
    static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func done(_ id: String, owner: String, scheme: RepScheme, sets: [(Double, Int)]) -> Session {
        let item = SessionItem(id: "it-\(id)", exerciseId: "m-chest-press",
                               sets: sets.map { SetEntry(kg: $0.0, reps: $0.1, done: true) }, scheme: scheme)
        return Session(id: id, ownerId: owner, createdBy: owner, date: "2026-11-05", title: "Push",
                       status: .done, items: [item], updatedAt: "2026-11-05T10:00:00.000Z")
    }

    private func spec(_ exerciseId: String, scheme: RepScheme? = nil) -> PlanSpec {
        PlanSpec(id: UUID().uuidString, exerciseId: exerciseId, scheme: scheme, sets: 3, reps: 10, kg: 0, minutes: 15)
    }

    @Test func bothOwnersGetTheirOwnLoads() {
        let history = [
            done("sc", owner: Self.clement.id, scheme: .pyramid, sets: [(20, 12), (25, 10), (30, 8), (20, 12)]),
            done("sj", owner: Self.jules.id, scheme: .classic, sets: [(60, 10), (60, 10), (60, 10)]),
        ]
        let out = PlanBuilder.sessions(specs: [spec("m-chest-press")], target: .both,
                                       me: Self.clement, partner: Self.jules, date: "2026-11-14",
                                       title: "Push", notes: nil, sessions: history, byId: Self.byId, now: Self.now)
        #expect(out.count == 2)
        #expect(out[0].groupId != nil)
        #expect(out[0].groupId == out[1].groupId)
        #expect(out.allSatisfy { $0.status == .planned && $0.createdBy == Self.clement.id })
        let c = out.first { $0.ownerId == Self.clement.id }!.items[0]
        let j = out.first { $0.ownerId == Self.jules.id }!.items[0]
        #expect(c.sets.map(\.kg) == [20, 25, 30, 20])
        #expect(c.sets.map(\.reps) == [12, 10, 8, 12])
        #expect(j.sets.count == 3)
        #expect(j.sets.allSatisfy { $0.kg == 60 && $0.reps == 10 })
        #expect(!c.sets.contains { $0.kg == 60 })
        #expect(!j.sets.contains { [20, 25, 30].contains($0.kg) })
    }

    @Test func singleOwnerClassicSpecBuildsSets() {
        let sp = PlanSpec(id: "p", exerciseId: "m-chest-press", scheme: .classic, sets: 4, reps: 8, kg: 42.5, minutes: 0)
        let items = PlanBuilder.items(from: [sp], owner: Self.jules, single: true, sessions: [], byId: Self.byId)
        #expect(items[0].sets.count == 4)
        #expect(items[0].sets.allSatisfy { $0.kg == 42.5 && $0.reps == 8 && !$0.done })
    }

    @Test func singleOwnerPyramidSpecUsesPyramid() {
        let sp = spec("m-chest-press", scheme: .pyramid)
        let items = PlanBuilder.items(from: [sp], owner: Self.clement, single: true, sessions: [], byId: Self.byId)
        #expect(items[0].sets.map(\.reps) == [12, 10, 8, 12])
        #expect(items[0].scheme == .pyramid)
    }

    @Test func specForOwnerUsesDefaultSchemeAndLastLoads() {
        let ex = Self.byId["m-chest-press"]!
        let history = [done("sj", owner: Self.jules.id, scheme: .classic, sets: [(50, 12), (60, 10), (60, 10)])]
        let sj = PlanBuilder.spec(for: ex, owner: Self.jules, sessions: history)
        #expect(sj.scheme == .classic)
        #expect(sj.sets == 3 && sj.kg == 60 && sj.reps == 10)
        let sc = PlanBuilder.spec(for: ex, owner: Self.clement, sessions: history)
        #expect(sc.scheme == .pyramid)
        let both = PlanBuilder.spec(for: ex, owner: nil, sessions: history)
        #expect(both.scheme == nil)
    }

    @Test func cardioUsesSpecMinutes() {
        let sp = PlanSpec(id: "p", exerciseId: "c-velo", scheme: nil, sets: 3, reps: 10, kg: 0, minutes: 25)
        let ex = Exercise(id: "c-velo", name: "Vélo", kind: .cardio, muscle: .cardio, posture: .fauteuil,
                          help: false, equipment: .cardio)
        let items = PlanBuilder.items(from: [sp], owner: Self.clement, single: false, sessions: [], byId: ["c-velo": ex])
        #expect(items[0].cardio?.minutes == 25)
        #expect(items[0].sets.isEmpty)
    }

    @Test func emptyTitleUsesSuggestion() {
        let out = PlanBuilder.sessions(specs: [spec("m-chest-press"), spec("m-pec-deck")], target: .me,
                                       me: Self.clement, partner: Self.jules, date: "2026-11-14",
                                       title: "  ", notes: nil, sessions: [], byId: Self.byId, now: Self.now)
        #expect(out.count == 1)
        #expect(out[0].title == "Push")
        #expect(out[0].groupId == nil)
        #expect(out[0].ownerId == Self.clement.id)
    }

    @Test func specsFromSessionRoundTrip() {
        let s = done("sc", owner: Self.clement.id, scheme: .classic, sets: [(40, 8), (45, 8), (50, 6)])
        let specs = PlanBuilder.specs(from: s)
        #expect(specs.count == 1)
        #expect(specs[0].sets == 3 && specs[0].reps == 8 && specs[0].kg == 50)
        #expect(specs[0].scheme == .classic)
    }

    @Test func groupingHelpMovesHelpTogether() {
        let a = spec("m-chest-press"), h1 = spec("d-presse-45"), b = spec("m-pec-deck"), h2 = spec("d-chest-press")
        let out = PlanBuilder.groupingHelp([a, h1, b, h2], byId: Self.byId)
        #expect(out.map(\.id) == [a.id, h1.id, h2.id, b.id])
    }
    // MARK: Éditeur (tâche 5)

    @Test func copyingOwnSessionKeepsPlannedValues() {
        let s = done("sc", owner: Self.clement.id, scheme: .classic, sets: [(40, 8), (45, 8), (50, 6)])
        let specs = PlanBuilder.specs(copying: s, owner: Self.clement, sessions: [s], byId: Self.byId)
        #expect(specs.count == 1)
        #expect(specs[0].scheme == .classic && specs[0].sets == 3 && specs[0].reps == 8 && specs[0].kg == 50)
    }

    @Test func copyingPartnerSessionNeverTakesTheirLoads() {
        let mine = done("sc", owner: Self.clement.id, scheme: .pyramid, sets: [(20, 12), (25, 10), (30, 8), (20, 12)])
        let his = done("sj", owner: Self.jules.id, scheme: .classic, sets: [(60, 10), (60, 10), (60, 10)])
        let forMe = PlanBuilder.specs(copying: his, owner: Self.clement, sessions: [mine, his], byId: Self.byId)
        #expect(forMe.count == 1)
        #expect(forMe[0].scheme == .pyramid)
        #expect(forMe[0].kg == 30)
        let forBoth = PlanBuilder.specs(copying: his, owner: nil, sessions: [mine, his], byId: Self.byId)
        #expect(forBoth[0].scheme == nil && forBoth[0].kg == 0)
    }

    @Test func copyingSkipsUnknownExercises() {
        var s = done("sc", owner: Self.clement.id, scheme: .classic, sets: [(40, 8)])
        s.items.append(SessionItem(id: "x", exerciseId: "machine-masquee", sets: [SetEntry(kg: 10, reps: 10, done: true)]))
        #expect(PlanBuilder.specs(copying: s, owner: Self.clement, sessions: [], byId: Self.byId).count == 1)
        #expect(PlanBuilder.specs(copying: s, owner: Self.jules, sessions: [], byId: Self.byId).count == 1)
    }

    @Test func retargetKeepsIdsAndUsesNewOwnerLoads() {
        let his = done("sj", owner: Self.jules.id, scheme: .classic, sets: [(60, 10), (60, 10), (60, 10)])
        let start = PlanSpec(id: "keep", exerciseId: "m-chest-press", scheme: .pyramid, sets: 4, reps: 12, kg: 30, minutes: 0)
        let out = PlanBuilder.retarget([start], owner: Self.jules, sessions: [his], byId: Self.byId)
        #expect(out.map(\.id) == ["keep"])
        #expect(out[0].scheme == .classic && out[0].kg == 60 && out[0].sets == 3)
        let both = PlanBuilder.retarget([start], owner: nil, sessions: [his], byId: Self.byId)
        #expect(both[0].id == "keep" && both[0].scheme == nil && both[0].kg == 0)
    }

    @Test func editedSessionKeepsIdentity() {
        let a = SessionItem(id: "a", exerciseId: "m-chest-press", sets: [SetEntry(kg: 40, reps: 10, done: false)], scheme: .classic)
        let b = SessionItem(id: "b", exerciseId: "d-presse-45", sets: [SetEntry(kg: 50, reps: 10, done: false)], scheme: .classic)
        let s = Session(id: "s1", ownerId: Self.clement.id, createdBy: Self.clement.id, date: "2026-11-14",
                        title: "Full body", status: .planned, items: [a, b], groupId: "g1",
                        updatedAt: "2026-11-01T10:00:00.000Z")
        let specs = Array(PlanBuilder.specs(from: s).prefix(1))
        let out = PlanBuilder.edited(s, specs: specs, owner: Self.clement, date: "2026-11-15", title: "",
                                     notes: "  tôt  ", sessions: [], byId: Self.byId, now: Self.now)
        #expect(out.id == "s1" && out.groupId == "g1" && out.createdBy == Self.clement.id)
        #expect(out.ownerId == Self.clement.id && out.status == .planned)
        #expect(out.date == "2026-11-15" && out.notes == "tôt" && out.title == "Push")
        #expect(out.items.count == 1 && out.items[0].sets.allSatisfy { $0.kg == 40 && $0.reps == 10 })
        #expect(out.updatedAt == AppStore.timestamp(Self.now))
    }

    @Test func editedSessionCanChangeOwner() {
        let his = done("sj", owner: Self.jules.id, scheme: .classic, sets: [(60, 10), (60, 10), (60, 10)])
        let s = Session(id: "s1", ownerId: Self.clement.id, createdBy: Self.clement.id, date: "2026-11-14",
                        title: "Push", status: .planned, items: [], updatedAt: "2026-11-01T10:00:00.000Z")
        let specs = PlanBuilder.retarget([spec("m-chest-press", scheme: .pyramid)], owner: Self.jules,
                                         sessions: [his], byId: Self.byId)
        let out = PlanBuilder.edited(s, specs: specs, owner: Self.jules, date: s.date, title: "Push",
                                     notes: nil, sessions: [his], byId: Self.byId, now: Self.now)
        #expect(out.id == "s1" && out.ownerId == Self.jules.id && out.createdBy == Self.clement.id)
        #expect(out.items[0].sets.allSatisfy { $0.kg == 60 })
    }

    @Test func titleSuggestionFromSpecs() {
        #expect(PlanBuilder.titleSuggestion([spec("m-chest-press"), spec("m-pec-deck")], byId: Self.byId) == "Push")
        #expect(PlanBuilder.titleSuggestion([], byId: Self.byId) == "Séance")
    }

    @Test func helpScatteredOnlyWhenHelpIsSplit() {
        let a = spec("m-chest-press"), h1 = spec("d-presse-45"), b = spec("m-pec-deck"), h2 = spec("d-chest-press")
        #expect(PlanBuilder.helpIsScattered([a, h1, b, h2], byId: Self.byId))
        #expect(!PlanBuilder.helpIsScattered([a, h1, h2, b], byId: Self.byId))
        #expect(!PlanBuilder.helpIsScattered([a, h1, b], byId: Self.byId))
    }
}
