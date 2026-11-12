import Foundation

/// Les phrases de l'écran « Sauvegarde », construites ici pour que les accords (0, 1, n) soient testés.
public enum BackupText {
    /// « 12 séances, 3 réglages de machines » ; les séances supprimées ne comptent pas,
    /// et les réglages de machines ne sont cités que s'il y en a.
    public static func content(_ c: BackupContent) -> String {
        let sessions = c.sessions.values.filter { $0.deleted != true }.count
        let exercises = c.exercises.count
        let first = sessions == 0 ? "aucune séance" : "\(sessions) séance\(sessions > 1 ? "s" : "")"
        guard exercises > 0 else { return first }
        return "\(first), \(exercises) réglage\(exercises > 1 ? "s" : "") de machine\(exercises > 1 ? "s" : "")"
    }

    /// « 10 ajoutées, 2 mises à jour, 0 gardée (plus récente sur ce téléphone) », puis
    /// « , 3 illisibles ignorées » seulement s'il y en a.
    public static func summary(_ s: ImportSummary) -> String {
        let keptPlural = s.kept > 1
        var text = "\(s.added) ajoutée\(s.added > 1 ? "s" : ""), "
            + "\(s.updated) \(s.updated > 1 ? "mises" : "mise") à jour, "
            + "\(s.kept) gardée\(keptPlural ? "s" : "") (plus récente\(keptPlural ? "s" : "") sur ce téléphone)"
        if s.skipped > 0 {
            text += ", \(s.skipped) illisible\(s.skipped > 1 ? "s" : "") ignorée\(s.skipped > 1 ? "s" : "")"
        }
        return text
    }

    /// « suivi-muscu-2026-11-12.json » pour la date du jour au format AAAA-MM-JJ.
    public static func fileName(today: String) -> String { "suivi-muscu-\(today).json" }
}
