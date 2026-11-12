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

// MARK: Modifier le cycle (Réglages)

/// Les ids ne changent jamais : `CyclePlanner` retrouve la dernière séance faite par son `cycleId`.
extension Cycle {
    /// Identifiant d'une nouvelle séance type.
    public static func newTemplateId() -> String { "cycle-\(UUID().uuidString.lowercased())" }

    /// Remplace la séance type de même id, à sa place ; sinon l'ajoute à la fin.
    public mutating func upsert(_ template: CycleTemplate) {
        if let i = templates.firstIndex(where: { $0.id == template.id }) {
            templates[i] = template
        } else {
            templates.append(template)
        }
    }

    /// Retire la séance type du cycle (les séances déjà faites ne sont pas touchées).
    public mutating func removeTemplate(id: String) {
        templates.removeAll { $0.id == id }
    }

    /// Monte (`-1`) ou descend (`+1`) la séance type d'un rang ; rien hors des limites.
    public mutating func moveTemplate(id: String, by offset: Int) {
        guard let i = templates.firstIndex(where: { $0.id == id }) else { return }
        templates.move(at: i, by: offset)
    }
}

extension CycleTemplate {
    /// Ajoute les exercices à la fin, dans l'ordre ; un exercice déjà présent n'est pas ajouté deux fois.
    public mutating func add(_ newItems: [CycleItem]) {
        for item in newItems where !items.contains(where: { $0.exerciseId == item.exerciseId }) {
            items.append(item)
        }
    }

    /// Monte (`-1`) ou descend (`+1`) l'exercice d'un rang ; rien hors des limites.
    public mutating func moveItem(at index: Int, by offset: Int) {
        items.move(at: index, by: offset)
    }
}

extension Array {
    fileprivate mutating func move(at index: Int, by offset: Int) {
        let target = index + offset
        guard indices.contains(index), indices.contains(target) else { return }
        swapAt(index, target)
    }
}
