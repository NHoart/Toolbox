//
//  CounterStore.swift
//  counter
//

import Foundation
import SwiftUI
import Combine

/// A named, saved counter value
struct SavedCounter: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var value: Int
    var date = Date()
}

/// State management for the counter including saved values
final class CounterStore: ObservableObject {
    @Published private(set) var count: Int
    @Published private(set) var savedCounters: [SavedCounter] = []

    /// How many times per second the counter counts up automatically.
    @Published var incrementsPerSecond: Int {
        didSet {
            // Do not upload again while adopting a foreign state.
            guard !isApplyingRemote else { return }
            let clamped = min(Self.maxRate, max(Self.minRate, incrementsPerSecond))
            guard clamped == incrementsPerSecond else {
                incrementsPerSecond = clamped
                return
            }
            Self.defaults.set(clamped, forKey: Self.rateKey)
            Self.markRateChanged()
        }
    }

    /// Is the automatic counter running right now?
    @Published private(set) var isAutoRunning = false

    static let minRate = 1
    static let maxRate = 100

    private static let countKey = "counter_value"
    private static let savedKey = "saved_counters"
    private static let rateKey = "counter_rate"
    private static let updatedKey = "sync.counter.updatedAt"
    private static let rateUpdatedKey = "sync.counter.rateUpdatedAt"
    private static let rateMigrationKey = "sync.counter.rateMigrated"

    /// The headless interop test isolates its data through its own suite.
    private static let defaults: UserDefaults = {
        if let testSuite = ProcessInfo.processInfo.environment["TOOLBOX_DEFAULTS_SUITE"],
           let suite = UserDefaults(suiteName: testSuite) {
            return suite
        }
        return .standard
    }()

    private var history: [Int] = []

    private var autoTimer: Timer?
    private var autoRemainder: Double = 0
    private var countAtAutoStart = 0
    private var lastAutoPersist = Date.distantPast
    private var lastAutoSound = Date.distantPast
    private let tickInterval: TimeInterval = 1.0 / 30.0

    /// Is a state from another device being applied right now?
    private var isApplyingRemote = false
    private var remoteObserver: NSObjectProtocol?

    /// So the sound does not turn into a permanent beep at high rates.
    private static let maxAutoSoundsPerSecond = 10.0

    private var historyEnabled: Bool {
        !Self.defaults.bool(forKey: "disable_history")
    }

    init() {
        Self.migrateLegacyRateTimestamp()
        count = Self.defaults.integer(forKey: Self.countKey)

        let storedRate = Self.defaults.integer(forKey: Self.rateKey)
        incrementsPerSecond = storedRate > 0 ? min(Self.maxRate, storedRate) : 5

        if let data = Self.defaults.data(forKey: Self.savedKey),
           let decoded = try? JSONDecoder().decode([SavedCounter].self, from: data) {
            savedCounters = decoded
        }

        // A counter state from another device was adopted.
        remoteObserver = NotificationCenter.default.addObserver(forName: .counterSyncDidApply,
                                                                object: nil,
                                                                queue: .main) { [weak self] notification in
            guard let self else { return }
            // A speed-only update must not stop a running auto count; a
            // foreign count still does.
            let countsApplied = notification.userInfo?["countsApplied"] as? Bool ?? true
            Task { @MainActor in self.reloadFromDefaults(stopAuto: countsApplied) }
        }
    }

    // MARK: - Counter

    func increment() {
        setCount(count + 1)
        HapticManager.shared.impactOccurred()
        SoundManager.shared.playIncrement()
    }

    func decrement() {
        guard count > 0 else { return }
        setCount(count - 1)
        HapticManager.shared.impactOccurred()
        SoundManager.shared.playDecrement()
    }

    func reset() {
        stopAutoCounting()
        guard count != 0 else { return }
        setCount(0)
        HapticManager.shared.heavyImpactOccurred()
        SoundManager.shared.playReset()
    }

    func undo() {
        guard historyEnabled, let previous = history.popLast() else { return }
        count = previous
        Self.defaults.set(count, forKey: Self.countKey)
        Self.markChanged()
        HapticManager.shared.impactOccurred()
    }

    /// Sets the value and remembers the old one for undo
    private func setCount(_ newValue: Int) {
        if historyEnabled {
            history.append(count)
        }
        count = newValue
        Self.defaults.set(count, forKey: Self.countKey)
        Self.markChanged()
    }

    // MARK: - Automatic counting

    /// Starts automatic counting up at the configured rate.
    func startAutoCounting() {
        guard !isAutoRunning else { return }

        isAutoRunning = true
        autoRemainder = 0
        countAtAutoStart = count
        lastAutoPersist = Date()
        lastAutoSound = .distantPast

        let timer = Timer(timeInterval: tickInterval, repeats: true) { [weak self] _ in
            self?.autoTick()
        }
        autoTimer = timer
        RunLoop.main.add(timer, forMode: .common)

        HapticManager.shared.impactOccurred()
    }

    /// Stops automatic counting up.
    func stopAutoCounting() {
        guard isAutoRunning else { return }

        isAutoRunning = false
        autoTimer?.invalidate()
        autoTimer = nil
        autoRemainder = 0
        Self.defaults.set(count, forKey: Self.countKey)
        Self.markChanged()

        // Undo reverts the entire automatic run.
        if count != countAtAutoStart, historyEnabled {
            history.append(countAtAutoStart)
        }

        HapticManager.shared.impactOccurred()
    }

    private func autoTick() {
        guard isAutoRunning else { return }

        // The rate is spread evenly across the ticks so that even
        // high rates need no more timer calls than necessary.
        autoRemainder += Double(incrementsPerSecond) * tickInterval
        let steps = Int(autoRemainder)
        guard steps > 0 else { return }
        autoRemainder -= Double(steps)
        count += steps

        playAutoSoundIfNeeded()

        // Do not write to UserDefaults on every tick.
        let now = Date()
        if now.timeIntervalSince(lastAutoPersist) >= 0.5 {
            lastAutoPersist = now
            Self.defaults.set(count, forKey: Self.countKey)
        }
    }

    /// Plays the count-up sound, at most `maxAutoSoundsPerSecond` times per second.
    private func playAutoSoundIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastAutoSound) >= 1.0 / Self.maxAutoSoundsPerSecond else { return }
        lastAutoSound = now
        SoundManager.shared.playIncrement()
    }

    deinit {
        autoTimer?.invalidate()
        if let remoteObserver {
            NotificationCenter.default.removeObserver(remoteObserver)
        }
    }

    // MARK: - Saved counters

    /// Saves the current value under the given name
    func saveCurrent(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty
            ? String(localized: "Count \(savedCounters.count + 1)")
            : trimmed

        savedCounters.insert(SavedCounter(name: finalName, value: count), at: 0)
        persistSaved()
        HapticManager.shared.impactOccurred()
    }

    /// Loads a saved value as the current counter value
    func load(_ saved: SavedCounter) {
        stopAutoCounting()
        setCount(saved.value)
        HapticManager.shared.impactOccurred()
    }

    func deleteSaved(at offsets: IndexSet) {
        savedCounters.remove(atOffsets: offsets)
        persistSaved()
    }

    private func persistSaved() {
        if let data = try? JSONEncoder().encode(savedCounters) {
            Self.defaults.set(data, forKey: Self.savedKey)
        }
        Self.markChanged()
    }

    // MARK: - Sync with other devices

    /// Time of the last local change of the count (for syncing).
    static var updatedAt: Date? {
        get { Self.defaults.object(forKey: updatedKey) as? Date }
        set {
            if let newValue {
                Self.defaults.set(newValue, forKey: updatedKey)
            } else {
                Self.defaults.removeObject(forKey: updatedKey)
            }
        }
    }

    /// Time of the last change of the auto-count speed.
    ///
    /// Count and speed keep separate timestamps: changing only the speed must
    /// not make an old count look newer than the count of another device –
    /// that used to overwrite a newer count on the next sync.
    static var rateUpdatedAt: Date? {
        get { Self.defaults.object(forKey: rateUpdatedKey) as? Date }
        set {
            if let newValue {
                Self.defaults.set(newValue, forKey: rateUpdatedKey)
            } else {
                Self.defaults.removeObject(forKey: rateUpdatedKey)
            }
        }
    }

    /// States from older versions carry only the single counter timestamp.
    /// Freeze it once as the rate time; the flag also keeps a fresh install
    /// from stamping its default rate when the first count is logged.
    private static func migrateLegacyRateTimestamp() {
        let defaults = Self.defaults
        guard !defaults.bool(forKey: rateMigrationKey) else { return }
        defaults.set(true, forKey: rateMigrationKey)
        guard defaults.object(forKey: rateUpdatedKey) == nil,
              let legacy = updatedAt else { return }
        defaults.set(legacy, forKey: rateUpdatedKey)
    }

    /// Is there any data worth syncing at all?
    static var hasData: Bool {
        if Self.defaults.integer(forKey: countKey) != 0 { return true }
        guard let data = Self.defaults.data(forKey: savedKey),
              let decoded = try? JSONDecoder().decode([SavedCounter].self, from: data) else {
            return false
        }
        return !decoded.isEmpty
    }

    /// State that is exchanged between the devices.
    struct SyncSnapshot: Codable {
        var count: Int
        var savedCounters: [SavedCounter]
        var rate: Int
        var updatedAt: Date
        /// Missing in states of older app versions or when the speed was
        /// never changed; such a state does not count as a rate change.
        var rateUpdatedAt: Date?
    }

    static func syncSnapshot() -> SyncSnapshot {
        let stored: [SavedCounter]
        if let data = Self.defaults.data(forKey: savedKey),
           let decoded = try? JSONDecoder().decode([SavedCounter].self, from: data) {
            stored = decoded
        } else {
            stored = []
        }

        let storedRate = Self.defaults.integer(forKey: rateKey)

        return SyncSnapshot(
            count: Self.defaults.integer(forKey: countKey),
            savedCounters: stored,
            rate: storedRate > 0 ? min(maxRate, storedRate) : 5,
            // Without a change time the state counts as old: a fresh device
            // must not overwrite a newer state of the others with it.
            updatedAt: updatedAt ?? .distantPast,
            rateUpdatedAt: rateUpdatedAt
        )
    }

    /// Result of merging a foreign state.
    struct MergeResult {
        /// Something was taken over from the other device.
        var applied = false
        /// The count (not just the speed) was taken over.
        var countsApplied = false
        /// The other device has older count data or speed and needs our state.
        var peerIsBehind = false
    }

    /// Merges a foreign state area by area.
    ///
    /// Count (including saved values) and speed are compared with their own
    /// timestamps: a device that only changed the speed keeps its old count
    /// timestamp and cannot overwrite a newer count from another device.
    static func mergeSync(_ remote: SyncSnapshot) -> MergeResult {
        var result = MergeResult()

        let localAmountsAt = updatedAt
        let localRateAt = rateUpdatedAt
        // States without a rate time (old app versions or a device that never
        // changed the speed) count as old – they must not overwrite a real
        // speed with the default value.
        let remoteRateAt = remote.rateUpdatedAt ?? .distantPast

        if let local = localAmountsAt {
            if remote.updatedAt > local {
                applyCounts(remote)
                result.applied = true
                result.countsApplied = true
            } else if remote.updatedAt < local {
                result.peerIsBehind = true
            }
        } else {
            applyCounts(remote)
            result.applied = true
            result.countsApplied = true
        }

        if let local = localRateAt {
            if remoteRateAt > local {
                applyRate(remote)
                result.applied = true
            } else if remoteRateAt < local {
                result.peerIsBehind = true
            }
        } else {
            applyRate(remote)
            result.applied = true
        }

        return result
    }

    /// Adopts a foreign state without merging – for imports and tests.
    static func applySync(_ snapshot: SyncSnapshot) {
        applyCounts(snapshot)
        applyRate(snapshot)
    }

    private static func applyCounts(_ snapshot: SyncSnapshot) {
        let defaults = Self.defaults
        defaults.set(snapshot.count, forKey: countKey)
        if let data = try? JSONEncoder().encode(snapshot.savedCounters) {
            defaults.set(data, forKey: savedKey)
        }
        updatedAt = snapshot.updatedAt
    }

    private static func applyRate(_ snapshot: SyncSnapshot) {
        Self.defaults.set(min(maxRate, max(minRate, snapshot.rate)), forKey: rateKey)
        // A state without its own rate time never changed the speed: it must
        // not count as newer than a real speed on another device.
        rateUpdatedAt = snapshot.rateUpdatedAt ?? .distantPast
    }

    /// Notes a count change for the Wi-Fi sync.
    private static func markChanged() {
        updatedAt = Date()
        NotificationCenter.default.post(name: .counterStoreDidChange, object: nil)
    }

    /// Notes a speed change; the count timestamp stays untouched.
    private static func markRateChanged() {
        rateUpdatedAt = Date()
        NotificationCenter.default.post(name: .counterStoreDidChange, object: nil)
    }

    /// Takes changed values from UserDefaults into the published properties.
    private func reloadFromDefaults(stopAuto: Bool) {
        if !stopAuto {
            // Speed-only update: adopt the speed without touching the running
            // count, which can be ahead of the value persisted by the timer.
            isApplyingRemote = true
            defer { isApplyingRemote = false }
            let storedRate = Self.defaults.integer(forKey: Self.rateKey)
            incrementsPerSecond = storedRate > 0 ? min(Self.maxRate, storedRate) : 5
            return
        }

        // Stop a running auto counter without saving the old state again – a
        // foreign count replaces it.
        if isAutoRunning {
            isAutoRunning = false
            autoTimer?.invalidate()
            autoTimer = nil
            autoRemainder = 0
        }

        isApplyingRemote = true
        defer { isApplyingRemote = false }

        count = Self.defaults.integer(forKey: Self.countKey)
        if let data = Self.defaults.data(forKey: Self.savedKey),
           let decoded = try? JSONDecoder().decode([SavedCounter].self, from: data) {
            savedCounters = decoded
        } else {
            savedCounters = []
        }

        let storedRate = Self.defaults.integer(forKey: Self.rateKey)
        incrementsPerSecond = storedRate > 0 ? min(Self.maxRate, storedRate) : 5
    }
}

extension Notification.Name {
    /// The local counter value changed (LocalSync distributes it).
    static let counterStoreDidChange = Notification.Name("Toolbox.counterStoreDidChange")
    /// A counter state from another device was adopted.
    static let counterSyncDidApply = Notification.Name("Toolbox.counterSyncDidApply")
}
