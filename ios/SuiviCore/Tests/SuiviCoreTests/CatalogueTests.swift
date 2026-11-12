import Testing
@testable import SuiviCore

@Suite struct CatalogueTests {
    private func exercise(_ id: String) throws -> Exercise {
        try #require(Catalogue.base.first { $0.id == id })
    }

    @Test func catalogueHas70() {
        #expect(Catalogue.base.count == 70)
        #expect(Catalogue.base.filter { $0.kind == .cardio }.count == 11)
    }

    @Test func baseIdsListEveryCatalogueMachineOnly() {
        #expect(Catalogue.baseIds == Set(Catalogue.base.map(\.id)) && Catalogue.baseIds.count == 70
                && !Catalogue.baseIds.contains("perso-1"))
    }

    @Test func catalogueSpotChecks() throws {
        let chest = try exercise("m-chest-press")
        #expect(chest.posture == .transfert)
        #expect(chest.step == 5)
        #expect(chest.brand == .technogym)

        let presse = try exercise("d-presse-45")
        #expect(presse.help)
        #expect(presse.brand == .hammer)

        #expect(try exercise("c-skierg").brand == .autre)
        #expect(try exercise("poulie-rotation-externe").step == 1.25)
    }

    @Test func weekStartIsMonday() {
        #expect(Dates.weekStart("2026-11-15") == "2026-11-09")
        #expect(Dates.weekStart("2026-11-16") == "2026-11-16")
    }

    @Test func addDaysCrossesMonth() {
        #expect(Dates.addDays("2026-11-30", 1) == "2026-12-01")
        #expect(Dates.addDays("2026-03-01", -1) == "2026-02-28")
    }

    @Test func illustrationURLs() throws {
        let u = try #require(Illustrations.urls(for: "m-chest-press"))
        #expect(u.start.absoluteString == "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/Machine_Bench_Press/0.jpg")
        #expect(u.end.lastPathComponent == "1.jpg")
        #expect(Illustrations.urls(for: "inconnu") == nil)
    }

    @Test func muscleLabels() {
        #expect(Catalogue.muscleLabel(.pecs) == "Pectoraux")
        #expect(Catalogue.muscleLabel(.quadris) == "Quadriceps")
    }
}
