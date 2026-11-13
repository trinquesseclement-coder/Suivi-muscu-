import Foundation
import Testing
@testable import SuiviCore

/// Modifier le cycle depuis les Réglages : ordre, ajout, suppression, sans jamais changer un id.
@Suite struct CycleEditingTests {
    private var ids: [String] { ["cycle-epaules-dos", "cycle-pecs-bras", "cycle-cardio"] }

    @Test func movingTemplateKeepsIds() {
        var cycle = Cycle.standard
        cycle.moveTemplate(id: "cycle-epaules-dos", by: 1)
        #expect(cycle.templates.map(\.id) == ["cycle-pecs-bras", "cycle-epaules-dos", "cycle-cardio"])
        cycle.moveTemplate(id: "cycle-cardio", by: -1)
        #expect(cycle.templates.map(\.id) == ["cycle-pecs-bras", "cycle-cardio", "cycle-epaules-dos"])
        // Hors limites ou id inconnu : rien ne bouge.
        cycle.moveTemplate(id: "cycle-pecs-bras", by: -1)
        cycle.moveTemplate(id: "cycle-epaules-dos", by: 1)
        cycle.moveTemplate(id: "inconnu", by: 1)
        #expect(cycle.templates.map(\.id) == ["cycle-pecs-bras", "cycle-cardio", "cycle-epaules-dos"])
    }

    @Test func upsertReplacesInPlaceOrAppends() {
        var cycle = Cycle.standard
        var cardio = cycle.templates[2]
        cardio.title = "Cardio long"
        cycle.upsert(cardio)
        #expect(cycle.templates.map(\.id) == ids)
        #expect(cycle.templates[2].title == "Cardio long")

        let legs = CycleTemplate(id: Cycle.newTemplateId(), title: "Jambes",
                                 items: [CycleItem(exerciseId: "m-leg-press")])
        cycle.upsert(legs)
        #expect(cycle.templates.map(\.id) == ids + [legs.id])
    }

    @Test func removingTemplate() {
        var cycle = Cycle.standard
        cycle.removeTemplate(id: "cycle-pecs-bras")
        #expect(cycle.templates.map(\.id) == ["cycle-epaules-dos", "cycle-cardio"])
        cycle.removeTemplate(id: "cycle-epaules-dos")
        cycle.removeTemplate(id: "cycle-cardio")
        #expect(cycle.templates.isEmpty)
    }

    @Test func newTemplateIdIsUniqueAndPrefixed() {
        let a = Cycle.newTemplateId(), b = Cycle.newTemplateId()
        #expect(a != b)
        #expect(a.hasPrefix("cycle-"))
        #expect(a == a.lowercased())
    }

    @Test func addingSkipsExercisesAlreadyThere() {
        var cardio = Cycle.standard.templates[2]
        cardio.add([CycleItem(exerciseId: "c-tapis", minutes: 30),
                    CycleItem(exerciseId: "c-velo", minutes: 15),
                    CycleItem(exerciseId: "c-velo", minutes: 15),
                    CycleItem(exerciseId: "m-curl")])
        #expect(cardio.items.map(\.exerciseId)
                == ["c-escalier", "c-tapis", "c-skierg", "poulie-rotation-buste", "c-velo", "m-curl"])
        // L'exercice déjà là garde ses minutes.
        #expect(cardio.items[1].minutes == 15)
    }

    @Test func movingItem() {
        var t = Cycle.standard.templates[2]
        t.moveItem(at: 0, by: 1)
        #expect(t.items.map(\.exerciseId) == ["c-tapis", "c-escalier", "c-skierg", "poulie-rotation-buste"])
        t.moveItem(at: 3, by: 1)
        t.moveItem(at: 0, by: -1)
        t.moveItem(at: 9, by: -1)
        #expect(t.items.map(\.exerciseId) == ["c-tapis", "c-escalier", "c-skierg", "poulie-rotation-buste"])
    }
}
