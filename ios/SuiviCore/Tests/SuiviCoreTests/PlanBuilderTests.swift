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
}
