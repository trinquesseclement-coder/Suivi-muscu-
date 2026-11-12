import Testing
@testable import SuiviCore

@Suite struct FormatTests {
    @Test func weekLabelSameMonth() {
        #expect(Format.weekLabel(containing: "2026-11-12") == "Du 9 au 15 nov.")
        #expect(Format.weekLabel(containing: "2026-11-09") == "Du 9 au 15 nov.")
        #expect(Format.weekLabel(containing: "2026-11-15") == "Du 9 au 15 nov.")
    }

    @Test func weekLabelAcrossMonths() {
        #expect(Format.weekLabel(containing: "2026-10-29") == "Du 26 oct. au 1 nov.")
        #expect(Format.weekLabel(containing: "2026-12-31") == "Du 28 déc. au 3 janv.")
    }

    @Test func weekLabelMonthWithoutDot() {
        #expect(Format.weekLabel(containing: "2026-05-13") == "Du 11 au 17 mai")
    }

    @Test func dayLabels() {
        #expect(Format.day("2026-11-12", today: "2026-11-12") == "Aujourd’hui")
        #expect(Format.day("2026-11-11", today: "2026-11-12") == "Hier")
        #expect(Format.day("2026-11-13", today: "2026-11-12") == "Demain")
        #expect(Format.day("2026-11-08", today: "2026-11-12") == "Dimanche 8 novembre")
        #expect(Format.day("2026-11-01", today: "2026-11-12") == "Dimanche 1 novembre")
        #expect(Format.day("2026-11-15", today: "2026-11-12") == "Dimanche 15 novembre")
    }

    @Test func tonnage() {
        #expect(Format.tonnage(5400) == "5,4 t")
        #expect(Format.tonnage(5000) == "5 t")
        #expect(Format.tonnage(10_950) == "11 t")
        #expect(Format.tonnage(850) == "850 kg")
        #expect(Format.tonnage(0) == "0 kg")
    }

    @Test func counts() {
        let s = Session(id: "s", ownerId: "p", createdBy: "p", date: "2026-11-12", title: "T", status: .done,
                        items: [
                            SessionItem(id: "a", exerciseId: "m-chest-press",
                                        sets: [SetEntry(kg: 40, reps: 10, done: true),
                                               SetEntry(kg: 40, reps: 10, done: false)]),
                            SessionItem(id: "b", exerciseId: "c-velo",
                                        cardio: CardioEntry(minutes: 15, done: true)),
                            SessionItem(id: "c", exerciseId: "m-shoulder-press",
                                        sets: [SetEntry(kg: 20, reps: 10, done: false)])
                        ], updatedAt: "2026-11-12T10:00:00.000Z")
        let byId = Dictionary(uniqueKeysWithValues: Catalogue.base.map { ($0.id, $0) })
        #expect(Stats.sessionSetCount(s) == 1)
        #expect(Stats.sessionCardioMinutes(s, byId: byId) == 15)
        #expect(Stats.startedItemCount(s) == 2)
    }
}
