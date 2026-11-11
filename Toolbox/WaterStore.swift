import Foundation
import WidgetKit

// WICHTIG: Diese Datei muss in BEIDEN Targets sein (App + Widget).
// Die App Group muss in beiden Targets unter "Signing & Capabilities" angehakt sein.
enum WaterStore {
    static let appGroupID = "group.com.noahsapps.Wassertracker"

    static let defaults: UserDefaults = {
        guard let d = UserDefaults(suiteName: appGroupID) else {
            assertionFailure("App Group '\(appGroupID)' nicht verfügbar. Capability in App- UND Widget-Target prüfen!")
            return .standard
        }
        return d
    }()

    enum Key {
        static let glass = "glassML"
        static let bottle = "bottleML"
        static let goal = "goalML"
        static let total = "totalML"
        static let day = "totalDay"
        static let history = "historyML"
        static let recentAdds = "recentAddsML"
    }

    /// Ein Tag im Verlauf (für HistoryView).
    struct DayEntry: Identifiable {
        let date: Date
        let ml: Int
        var id: Date { date }
    }

    static var glassML: Int {
        get { let v = defaults.integer(forKey: Key.glass); return v == 0 ? 250 : v }
        set { defaults.set(newValue, forKey: Key.glass) }
    }

    static var bottleML: Int {
        get { let v = defaults.integer(forKey: Key.bottle); return v == 0 ? 500 : v }
        set { defaults.set(newValue, forKey: Key.bottle) }
    }

    static var goalML: Int {
        get { let v = defaults.integer(forKey: Key.goal); return v == 0 ? 2000 : v }
        set { defaults.set(newValue, forKey: Key.goal) }
    }

    /// Verlauf: Tag ("yyyy-MM-dd") -> ml
    private static var history: [String: Int] {
        get { defaults.dictionary(forKey: Key.history) as? [String: Int] ?? [:] }
        set { defaults.set(newValue, forKey: Key.history) }
    }

    /// Heutige Menge; setzt sich automatisch bei neuem Tag auf 0.
    static var todayML: Int {
        let today = dayString(Date())
        if let v = history[today] { return v }
        guard defaults.string(forKey: Key.day) == today else { return 0 }
        return defaults.integer(forKey: Key.total)
    }

    /// Zuletzt hinzugefügte Mengen (jüngste zuletzt) für "Rückgängig".
    /// Liegt in der App Group, damit auch im Widget eingetragene Mengen erfasst werden.
    private static var recentAdds: [Int] {
        get {
            guard defaults.string(forKey: Key.day) == dayString(Date()) else { return [] }
            return defaults.array(forKey: Key.recentAdds) as? [Int] ?? []
        }
        set { defaults.set(newValue, forKey: Key.recentAdds) }
    }

    /// Menge, die als Nächstes rückgängig gemacht würde (nil = nichts zum Rückgängigmachen).
    static var lastAddedML: Int? { recentAdds.last }

    static func add(_ ml: Int) {
        setToday(max(0, todayML + ml))
        guard ml > 0 else { return }
        var stack = recentAdds
        stack.append(ml)
        // Nur die letzten 50 Einträge behalten
        if stack.count > 50 { stack.removeFirst(stack.count - 50) }
        recentAdds = stack
    }

    /// Entfernt die zuletzt hinzugefügte Menge (Glas oder Flasche) und gibt sie zurück.
    @discardableResult
    static func undoLast() -> Int? {
        var stack = recentAdds
        guard let last = stack.popLast() else { return nil }
        recentAdds = stack
        setToday(max(0, todayML - last))
        return last
    }

    static func reset() {
        defaults.removeObject(forKey: Key.recentAdds)
        setToday(0)
    }

    /// Letzte n Tage (älteste zuerst, heute zuletzt), Tage ohne Eintrag = 0.
    static func lastDays(_ n: Int) -> [DayEntry] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let h = history
        let today = dayString(start)
        return (0..<n).reversed().compactMap { offset in
            guard let date = cal.date(byAdding: .day, value: -offset, to: start) else { return nil }
            let key = dayString(date)
            let ml = key == today ? todayML : (h[key] ?? 0)
            return DayEntry(date: date, ml: ml)
        }
    }

    private static func setToday(_ value: Int) {
        let today = dayString(Date())
        defaults.set(value, forKey: Key.total)
        defaults.set(today, forKey: Key.day)

        var h = history
        h[today] = value
        // Alte Einträge (> 400 Tage) aufräumen
        if let cutoff = Calendar.current.date(byAdding: .day, value: -400, to: Date()) {
            let cutoffKey = dayString(cutoff)
            h = h.filter { $0.key >= cutoffKey }
        }
        history = h

        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
