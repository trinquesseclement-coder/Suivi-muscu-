import Foundation

/// Un exercice d'une séance type du cycle.
public struct CycleItem: Codable, Hashable, Sendable {
    public var exerciseId: String
    /// Durée imposée, pour le cardio seulement (`nil` = celle de la dernière fois).
    public var minutes: Int?

    public init(exerciseId: String, minutes: Int? = nil) {
        self.exerciseId = exerciseId; self.minutes = minutes
    }
}

/// Une séance type du cycle (« Épaules + dos »…).
public struct CycleTemplate: Codable, Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var items: [CycleItem]

    public init(id: String, title: String, items: [CycleItem]) {
        self.id = id; self.title = title; self.items = items
    }
}

/// Les séances types, faites l'une après l'autre en boucle, sans jours fixes.
public struct Cycle: Codable, Hashable, Sendable {
    public var templates: [CycleTemplate]

    public init(templates: [CycleTemplate]) { self.templates = templates }

    /// Le cycle de départ, tant que rien n'a été enregistré.
    public static let standard = Cycle(templates: [
        CycleTemplate(id: "cycle-epaules-dos", title: "Épaules + dos", items: [
            CycleItem(exerciseId: "m-lat-pulldown"),
            CycleItem(exerciseId: "m-rowing"),
            CycleItem(exerciseId: "poulie-tirage-horizontal"),
            CycleItem(exerciseId: "m-shoulder-press"),
            CycleItem(exerciseId: "m-elevation-laterale"),
            CycleItem(exerciseId: "poulie-face-pull"),
            CycleItem(exerciseId: "poulie-crunch"),
        ]),
        CycleTemplate(id: "cycle-pecs-bras", title: "Pecs + bras", items: [
            CycleItem(exerciseId: "m-chest-press"),
            CycleItem(exerciseId: "m-chest-press-incline"),
            CycleItem(exerciseId: "m-pec-deck"),
            CycleItem(exerciseId: "m-curl"),
            CycleItem(exerciseId: "poulie-triceps"),
            CycleItem(exerciseId: "m-dips-assis"),
            CycleItem(exerciseId: "m-crunch"),
        ]),
        CycleTemplate(id: "cycle-cardio", title: "Cardio", items: [
            CycleItem(exerciseId: "c-escalier", minutes: 15),
            CycleItem(exerciseId: "c-tapis", minutes: 15),
            CycleItem(exerciseId: "c-skierg", minutes: 10),
            CycleItem(exerciseId: "poulie-rotation-buste"),
        ]),
    ])
}
