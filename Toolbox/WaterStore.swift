import Foundation
import CoreFoundation
import WidgetKit

// IMPORTANT: This file must be in BOTH targets (app + widget).
// The App Group must be enabled in both targets under "Signing & Capabilities".
enum WaterStore {
    static let appGroupID = "group.com.noahsapps.Wassertracker"

    static let defaults: UserDefaults = {
        // The headless interop test isolates its data through its own suite.
        if let testSuite = ProcessInfo.processInfo.environment["TOOLBOX_DEFAULTS_SUITE"],
           let d = UserDefaults(suiteName: testSuite) {
            return d
        }
        guard let d = UserDefaults(suiteName: appGroupID) else {
            assertionFailure("App group '\(appGroupID)' is not available. Check the capability on BOTH the app and widget target!")
            return .standard
        }
        return d
    }()

    /// Cross-process name for water changes. The widget and Siri run in
    /// another process, so a plain NotificationCenter post stays there.
    static let changeNotificationName = "Toolbox.waterStoreDidChange"

    enum Key {
        static let glass = "glassML"
        static let bottle = "bottleML"
        static let goal = "goalML"
        static let total = "totalML"
        static let day = "totalDay"
        static let history = "historyML"
        static let recentAdds = "recentAddsML"
        static let updatedAt = "sync.water.updatedAt"
        static let sizesUpdatedAt = "sync.water.sizesUpdatedAt"
    }

    /// One day in the history (for HistoryView).
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

    /// Today's amount; resets to 0 automatically on a new day.
    static var todayML: Int {
        let today = dayString(Date())
        if let v = history[today] { return v }
        guard defaults.string(forKey: Key.day) == today else { return 0 }
        return defaults.integer(forKey: Key.total)
    }

    /// Recently added amounts (newest last) for "Undo".
    /// Lives in the App Group so amounts logged in the widget are recorded too.
    private static var recentAdds: [Int] {
        get {
            guard defaults.string(forKey: Key.day) == dayString(Date()) else { return [] }
            return defaults.array(forKey: Key.recentAdds) as? [Int] ?? []
        }
        set { defaults.set(newValue, forKey: Key.recentAdds) }
    }

    /// Amount that would be undone next (nil = nothing to undo).
    static var lastAddedML: Int? { recentAdds.last }

    static func add(_ ml: Int) {
        setToday(max(0, todayML + ml))
        guard ml > 0 else { return }
        var stack = recentAdds
        stack.append(ml)
        // Keep only the last 50 entries
        if stack.count > 50 { stack.removeFirst(stack.count - 50) }
        recentAdds = stack
    }

    /// Removes the most recently added amount (glass or bottle) and returns it.
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

    /// Last n days (oldest first, today last), days without an entry = 0.
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
        // Clean up old entries (> 400 days)
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

    // MARK: - Sync with other devices

    /// Time of the last local change of the amounts (for syncing).
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

    /// Time of the last change of glass, bottle or goal.
    ///
    /// Amounts and sizes keep separate timestamps: a settings change alone
    /// must not make an old water level look newer than the level of another
    /// device. Exactly that used to overwrite amounts logged on the other
    /// device as soon as the two devices synced again.
    static var sizesUpdatedAt: Date? {
        get {
            if let date = defaults.object(forKey: Key.sizesUpdatedAt) as? Date {
                return date
            }
            // States from older versions carry only the single `updatedAt`.
            // Freeze it once as the sizes time, so later amount changes no
            // longer move the sizes timestamp along with them.
            guard let legacy = updatedAt else { return nil }
            defaults.set(legacy, forKey: Key.sizesUpdatedAt)
            return legacy
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.sizesUpdatedAt)
            } else {
                defaults.removeObject(forKey: Key.sizesUpdatedAt)
            }
        }
    }

    /// Is there any data worth syncing at all?
    static var hasData: Bool {
        !history.isEmpty || defaults.integer(forKey: Key.total) != 0
    }

    /// State that is exchanged between the devices.
    struct SyncSnapshot: Codable {
        var history: [String: Int]
        var recentAdds: [Int]
        var day: String?
        var total: Int
        var glass: Int
        var bottle: Int
        var goal: Int
        var updatedAt: Date
        /// Missing in states of older app versions or when no size was ever
        /// changed; such a state does not count as a size change.
        var sizesUpdatedAt: Date?
    }

    static func syncSnapshot() -> SyncSnapshot {
        SyncSnapshot(
            history: history,
            // Only today's undo stack belongs to the current amount; a stack
            // from yesterday must not travel to other devices as today's.
            recentAdds: recentAdds,
            day: defaults.string(forKey: Key.day),
            total: defaults.integer(forKey: Key.total),
            glass: glassML,
            bottle: bottleML,
            goal: goalML,
            // Without a change time the state counts as old: a fresh device
            // must not overwrite a newer state of the others with it.
            updatedAt: updatedAt ?? .distantPast,
            sizesUpdatedAt: sizesUpdatedAt
        )
    }

    /// Result of merging a foreign state.
    struct MergeResult {
        /// Something was taken over from the other device.
        var applied = false
        /// The other device has older amounts or sizes and needs our state.
        var peerIsBehind = false
    }

    /// Merges a foreign state area by area.
    ///
    /// Amounts and sizes are compared with their own timestamps: a device that
    /// only changed the goal keeps its old amount timestamp and therefore
    /// cannot overwrite newer amounts of another device.
    static func mergeSync(_ remote: SyncSnapshot) -> MergeResult {
        var result = MergeResult()

        // Read both local timestamps before applying anything: `sizesUpdatedAt`
        // migrates from `updatedAt` on older states and must see the old value,
        // not the amount time that is about to be adopted.
        let localAmountsAt = updatedAt
        let localSizesAt = sizesUpdatedAt
        // States without a sizes time (old app versions or a device that never
        // changed a size) count as old – they must not overwrite real sizes.
        let remoteSizesAt = remote.sizesUpdatedAt ?? .distantPast

        if let local = localAmountsAt {
            if remote.updatedAt > local {
                applyAmounts(remote)
                result.applied = true
            } else if remote.updatedAt < local {
                result.peerIsBehind = true
            }
        } else {
            applyAmounts(remote)
            result.applied = true
        }

        if let local = localSizesAt {
            if remoteSizesAt > local {
                applySizes(remote)
                result.applied = true
            } else if remoteSizesAt < local {
                result.peerIsBehind = true
            }
        } else {
            applySizes(remote)
            result.applied = true
        }

        return result
    }

    /// Adopts a foreign state without merging – for imports and tests.
    static func applySync(_ snapshot: SyncSnapshot) {
        applyAmounts(snapshot)
        applySizes(snapshot)
    }

    private static func applyAmounts(_ snapshot: SyncSnapshot) {
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

        updatedAt = snapshot.updatedAt
    }

    private static func applySizes(_ snapshot: SyncSnapshot) {
        defaults.set(snapshot.glass, forKey: Key.glass)
        defaults.set(snapshot.bottle, forKey: Key.bottle)
        defaults.set(snapshot.goal, forKey: Key.goal)

        // A state without its own sizes time never changed a size: it must
        // not count as newer than real sizes on another device.
        sizesUpdatedAt = snapshot.sizesUpdatedAt ?? .distantPast
    }

    /// Sets all three sizes at once and marks only the sizes as changed.
    static func setSizes(glass: Int, bottle: Int, goal: Int) {
        guard glass != glassML || bottle != bottleML || goal != goalML else { return }
        glassML = glass
        bottleML = bottle
        goalML = goal
        markSizesChanged()
    }

    /// Notes a local change of the amounts, refreshes the widget and triggers
    /// the sync.
    static func markChanged() {
        updatedAt = Date()
        notifyChanged()
    }

    /// Notes a local change of glass, bottle or goal. The amounts keep their
    /// own timestamp, so the size alone cannot make an old water level newer.
    static func markSizesChanged() {
        sizesUpdatedAt = Date()
        notifyChanged()
    }

    private static func notifyChanged() {
        WidgetCenter.shared.reloadAllTimelines()
        NotificationCenter.default.post(name: .waterStoreDidChange, object: nil)
        // Also tell the running app when the change was made by the widget or
        // Siri in their own process.
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(changeNotificationName as CFString),
            nil,
            nil,
            true
        )
    }

    // MARK: - Changes from the widget process

    private static var observesExternalChanges = false

    /// Forwards water changes made in the widget or by Siri (another process)
    /// into this process, so the running app syncs them immediately and
    /// refreshes its views. Called once from the app; the widget only posts.
    static func startObservingExternalChanges() {
        guard !observesExternalChanges else { return }
        observesExternalChanges = true

        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .waterStoreDidChange, object: nil)
                }
            },
            changeNotificationName as CFString,
            nil,
            .deliverImmediately
        )
    }
}

extension Notification.Name {
    /// Local water tracker data changed (LocalSync distributes it).
    static let waterStoreDidChange = Notification.Name("Toolbox.waterStoreDidChange")
}
