import Foundation

/// Dates « YYYY-MM-DD » en heure de Paris (calendrier grégorien), comme `util.ts` côté web.
public enum Dates {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Paris")!
        return c
    }()

    public static func isoDate(_ d: Date) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", p.year!, p.month!, p.day!)
    }

    public static func parse(_ iso: String) -> Date? {
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }

    public static func addDays(_ iso: String, _ n: Int) -> String {
        guard let d = parse(iso), let r = calendar.date(byAdding: .day, value: n, to: d) else { return iso }
        return isoDate(r)
    }

    /// Lundi de la semaine de la date donnée.
    public static func weekStart(_ iso: String) -> String {
        guard let d = parse(iso) else { return iso }
        let dow = (calendar.component(.weekday, from: d) + 5) % 7 // lundi = 0
        return addDays(iso, -dow)
    }
}
