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
        static let updatedAt = "sync.water.updatedAt"
    }

    /// Ein Tag im Verlauf (für HistoryView).
    struct DayEntry: Identifiable {
        let date: Date
        let ml: Int
        var id: Date { date }
    }

    static var glassML: Int {
        get { let v = defaults.integer(forKey: Key.glass); return v == 0 ? 200 : v }
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

        markChanged()
    }

    private static func dayString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    // MARK: - Synchronisation mit anderen Geräten

    /// Zeitpunkt der letzten lokalen Änderung (für den Abgleich).
    static var updatedAt: Date? {
        get { defaults.object(forKey: Key.updatedAt) as? Date }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.updatedAt)
            } else {
                defaults.removeObject(forKey: Key.updatedAt)
            }
        }
    }

    /// Gibt es überhaupt Daten, die sich zu synchronisieren lohnen?
    static var hasData: Bool {
        !history.isEmpty || defaults.integer(forKey: Key.total) != 0
    }

    /// Stand, der zwischen den Geräten ausgetauscht wird.
    struct SyncSnapshot: Codable {
        var history: [String: Int]
        var recentAdds: [Int]
        var day: String?
        var total: Int
        var glass: Int
        var bottle: Int
        var goal: Int
        var updatedAt: Date
    }

    static func syncSnapshot() -> SyncSnapshot {
        SyncSnapshot(
            history: history,
            recentAdds: defaults.array(forKey: Key.recentAdds) as? [Int] ?? [],
            day: defaults.string(forKey: Key.day),
            total: defaults.integer(forKey: Key.total),
            glass: glassML,
            bottle: bottleML,
            goal: goalML,
            // Ohne Änderungszeit gilt der Stand als alt: Ein frisches Gerät
            // soll damit keinen neueren Stand der anderen überschreiben.
            updatedAt: updatedAt ?? .distantPast
        )
    }

    /// Übernimmt einen fremden Stand, ohne ihn als neue lokale Änderung zu markieren.
    static func applySync(_ snapshot: SyncSnapshot) {
        var h = snapshot.history
        if let cutoff = Calendar.current.date(byAdding: .day, value: -400, to: Date()) {
            let cutoffKey = dayString(cutoff)
            h = h.filter { $0.key >= cutoffKey }
        }

        defaults.set(h, forKey: Key.history)
        defaults.set(snapshot.recentAdds, forKey: Key.recentAdds)
        if let day = snapshot.day {
            defaults.set(day, forKey: Key.day)
        } else {
            defaults.removeObject(forKey: Key.day)
        }
        defaults.set(snapshot.total, forKey: Key.total)
        defaults.set(snapshot.glass, forKey: Key.glass)
        defaults.set(snapshot.bottle, forKey: Key.bottle)
        defaults.set(snapshot.goal, forKey: Key.goal)

        updatedAt = snapshot.updatedAt
    }

    /// Merkt eine lokale Änderung vor, lädt das Widget nach und stößt den Abgleich an.
    static func markChanged() {
        updatedAt = Date()
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .waterStoreDidChange, object: nil)
    }
}

extension Notification.Name {
    /// Lokale Wassertracker-Daten wurden geändert (LocalSync verteilt sie).
    static let waterStoreDidChange = Notification.Name("Toolbox.waterStoreDidChange")
}
