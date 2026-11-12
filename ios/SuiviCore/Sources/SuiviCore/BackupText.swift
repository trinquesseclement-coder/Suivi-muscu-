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

    /// « 10 séances ajoutées, 2 mises à jour. » : seules les parts non nulles, dans l'ordre ajoutées,
    /// mises à jour, gardées, illisibles ; « séance(s) » n'est dit qu'une fois, dans la première part.
    /// Tout à zéro : « Tout était déjà à jour. »
    public static func summary(_ s: ImportSummary) -> String {
        // (nombre, singulier, pluriel) sans le nom « séance ».
        let parts: [(Int, String, String)] = [
            (s.added, "ajoutée", "ajoutées"),
            (s.updated, "mise à jour", "mises à jour"),
            (s.kept, "gardée car plus récente sur ce téléphone", "gardées car plus récentes sur ce téléphone"),
            (s.skipped, "illisible ignorée", "illisibles ignorées"),
        ]
        var pieces: [String] = []
        for (count, one, many) in parts where count > 0 {
            let noun = pieces.isEmpty ? (count > 1 ? " séances" : " séance") : ""
            pieces.append("\(count)\(noun) \(count > 1 ? many : one)")
        }
        guard !pieces.isEmpty else { return "Tout était déjà à jour." }
        return pieces.joined(separator: ", ") + "."
    }

    /// « suivi-muscu-2026-11-12.json » pour la date du jour au format AAAA-MM-JJ.
    public static func fileName(today: String) -> String { "suivi-muscu-\(today).json" }
}
