import Foundation
import Testing
@testable import SuiviCore

@Suite struct PlanningTests {
    static let byId = Dictionary(uniqueKeysWithValues: Catalogue.base.map { ($0.id, $0) })
    static let clement = Profile(id: AppStore.clementId, name: "Clément", slot: 1)
    static let jules = Profile(id: AppStore.julesId, name: "Jules", slot: 2)
    static let profiles = [clement, jules]

    private func planned(_ id: String, owner: String, date: String, exos: [String]) -> Session {
        Session(id: id, ownerId: owner, createdBy: owner, date: date, title: "Séance", status: .planned,
                items: exos.map { SessionItem(id: "i-\($0)", exerciseId: $0) },
                updatedAt: "2026-11-10T10:00:00.000Z")
    }

    @Test func weekDaysStartMonday() {
        let days = PlanningWeek.days(containing: "2026-11-12")
        #expect(days.count == 7)
        #expect(days.first == "2026-11-09")
        #expect(days.last == "2026-11-15")
    }

    @Test func daySessionsSortedBySlot() {
        let j = planned("sj", owner: AppStore.julesId, date: "2026-11-12", exos: [])
        let c = planned("sc", owner: AppStore.clementId, date: "2026-11-12", exos: [])
        let other = planned("so", owner: AppStore.clementId, date: "2026-11-13", exos: [])
        let out = PlanningWeek.sessions(on: "2026-11-12", in: [j, other, c], profiles: Self.profiles)
        #expect(out.map(\.id) == ["sc", "sj"])
    }

    @Test func helpCountOnlyForHelpedOwner() {
        let exos = ["d-presse-45", "m-chest-press"]
        let c = planned("sc", owner: AppStore.clementId, date: "2026-11-12", exos: exos)
        let j = planned("sj", owner: AppStore.julesId, date: "2026-11-12", exos: exos)
        #expect(PlanningWeek.helpCount(c, profiles: Self.profiles, byId: Self.byId) == 1)
        #expect(PlanningWeek.helpCount(j, profiles: Self.profiles, byId: Self.byId) == 0)
    }
}
