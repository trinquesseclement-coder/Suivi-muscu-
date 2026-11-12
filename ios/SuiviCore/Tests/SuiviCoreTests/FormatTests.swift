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

    /// Le mot du jour seul, à côté du sélecteur de date de l'éditeur.
    @Test func dayWord() {
        #expect(Format.dayWord("2026-11-12", today: "2026-11-12") == "Aujourd’hui")
        #expect(Format.dayWord("2026-11-13", today: "2026-11-12") == "Demain")
        #expect(Format.dayWord("2026-11-11", today: "2026-11-12") == "Hier")
        #expect(Format.dayWord("2026-11-14", today: "2026-11-12") == "Samedi")
        #expect(Format.dayWord("pas-une-date", today: "2026-11-12") == "")
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

    @Test func dayMonthAndLoad() {
        #expect(Format.dayMonth("2026-11-06") == "6 nov.")
        #expect(Format.dayMonth("2026-05-13") == "13 mai")
        #expect(Format.load(21.25) == "21,25")
        #expect(Format.load(27.5) == "27,5")
        #expect(Format.load(40) == "40")
        #expect(Format.load(0.1 + 0.2) == "0,3")
    }

    /// Colonne des jours du planning : « Lun » au-dessus de « 9 ».
    @Test func weekdayShortAndDayOfMonth() {
        #expect(Format.weekdayShort("2026-11-09") == "Lun")
        #expect(Format.weekdayShort("2026-11-12") == "Jeu")
        #expect(Format.weekdayShort("2026-11-15") == "Dim")
        #expect(Format.dayOfMonth("2026-11-09") == "9")
        #expect(Format.dayOfMonth("2026-11-15") == "15")
    }
}
