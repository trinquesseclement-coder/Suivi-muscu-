import Foundation

/// Libellés en français (miroir de `fmtDay` et `fmtTonnage` dans `appli/src/lib/util.ts`).
/// Tables écrites à la main pour ne pas dépendre de la langue du téléphone.
public enum Format {
    static let monthsLong = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
                             "août", "septembre", "octobre", "novembre", "décembre"]
    /// Abréviations usuelles (celles d'`Intl` en fr-FR) : « mai », « juin », « août » sans point.
    static let monthsShort = ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.",
                              "août", "sept.", "oct.", "nov.", "déc."]
    /// Indexé par `Calendar.weekday` - 1 (dimanche = 0).
    static let weekdays = ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]

    private static func parts(_ iso: String) -> (year: Int, month: Int, day: Int)? {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, (1...12).contains(p[1]) else { return nil }
        return (p[0], p[1], p[2])
    }

    /// Semaine du lundi au dimanche : « Du 9 au 15 nov. », « Du 27 oct. au 2 nov. ».
    public static func weekLabel(containing iso: String) -> String {
        let monday = Dates.weekStart(iso)
        let sunday = Dates.addDays(monday, 6)
        guard let a = parts(monday), let b = parts(sunday) else { return "" }
        if a.month == b.month {
            return "Du \(a.day) au \(b.day) \(monthsShort[b.month - 1])"
        }
        return "Du \(a.day) \(monthsShort[a.month - 1]) au \(b.day) \(monthsShort[b.month - 1])"
    }

    /// « Aujourd’hui », « Hier », « Demain », sinon « Dimanche 8 novembre ».
    public static func day(_ iso: String, today: String) -> String {
        if iso == today { return "Aujourd’hui" }
        if iso == Dates.addDays(today, -1) { return "Hier" }
        if iso == Dates.addDays(today, 1) { return "Demain" }
        guard let p = parts(iso), let d = Dates.parse(iso) else { return iso }
        let wd = weekdays[Dates.calendar.component(.weekday, from: d) - 1]
        return wd.prefix(1).uppercased() + wd.dropFirst() + " \(p.day) \(monthsLong[p.month - 1])"
    }

    /// Le jour en un mot : « Aujourd’hui », « Hier », « Demain », sinon « Samedi » ; vide si illisible.
    public static func dayWord(_ iso: String, today: String) -> String {
        if iso == today { return "Aujourd’hui" }
        if iso == Dates.addDays(today, -1) { return "Hier" }
        if iso == Dates.addDays(today, 1) { return "Demain" }
        guard parts(iso) != nil, let d = Dates.parse(iso) else { return "" }
        let wd = weekdays[Dates.calendar.component(.weekday, from: d) - 1]
        return wd.prefix(1).uppercased() + wd.dropFirst()
    }

    /// Jour de la semaine abrégé, comme la colonne du planning web : « Lun », « Jeu ».
    public static func weekdayShort(_ iso: String) -> String {
        guard let d = Dates.parse(iso) else { return "" }
        let wd = weekdays[Dates.calendar.component(.weekday, from: d) - 1]
        return wd.prefix(1).uppercased() + wd.dropFirst().prefix(2)
    }

    /// Numéro du jour dans le mois : « 9 », « 15 ».
    public static func dayOfMonth(_ iso: String) -> String {
        guard let p = parts(iso) else { return iso }
        return String(p.day)
    }

    /// Nombre à une décimale au plus, virgule française : 5.4 → « 5,4 », 5.0 → « 5 ».
    public static func number(_ n: Double) -> String {
        let r = (n * 10).rounded() / 10
        if r == r.rounded() { return String(Int(r)) }
        return String(format: "%.1f", r).replacingOccurrences(of: ".", with: ",")
    }

    /// Jour et mois abrégé, comme `fmtDM` du web : « 6 nov. », « 13 mai ».
    public static func dayMonth(_ iso: String) -> String {
        guard let p = parts(iso) else { return iso }
        return "\(p.day) \(monthsShort[p.month - 1])"
    }

    /// Charge saisie, deux décimales au plus (pas de 1,25 kg) : 21.25 → « 21,25 », 40 → « 40 ».
    public static func load(_ n: Double) -> String {
        let r = (n * 100).rounded() / 100
        if r == r.rounded() { return String(Int(r)) }
        var text = String(format: "%.2f", r)
        while text.hasSuffix("0") { text.removeLast() }
        return text.replacingOccurrences(of: ".", with: ",")
    }

    /// 5 400 kg → « 5,4 t » ; 850 → « 850 kg ».
    public static func tonnage(_ kg: Double) -> String {
        if kg >= 1000 { return "\(number(kg / 1000)) t" }
        return "\(Int(kg.rounded())) kg"
    }
}
