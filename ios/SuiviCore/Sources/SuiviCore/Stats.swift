import Foundation

/// Statistiques (miroir de `appli/src/lib/stats.ts`). La tâche 4 complète ce fichier.
public enum Stats {
    /// Séries faites d'un item.
    public static func doneSets(_ item: SessionItem) -> [SetEntry] {
        item.sets.filter(\.done)
    }

    /// Dernière fois où la personne a fait l'exercice (séance terminée).
    /// `sessions` est supposé trié du plus récent au plus ancien.
    public static func lastPerformance(_ sessions: [Session], ownerId: String, exerciseId: String,
                                       excluding: String? = nil) -> (session: Session, item: SessionItem)? {
        for s in sessions {
            if s.ownerId != ownerId || s.status != .done || s.id == excluding { continue }
            if let it = s.items.first(where: {
                $0.exerciseId == exerciseId && (!doneSets($0).isEmpty || $0.cardio?.done == true)
            }) {
                return (s, it)
            }
        }
        return nil
    }
}
