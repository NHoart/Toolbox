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
            Self.markChanged()
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
        count = Self.defaults.integer(forKey: Self.countKey)

        let storedRate = Self.defaults.integer(forKey: Self.rateKey)
        incrementsPerSecond = storedRate > 0 ? min(Self.maxRate, storedRate) : 5

        if let data = Self.defaults.data(forKey: Self.savedKey),
           let decoded = try? JSONDecoder().decode([SavedCounter].self, from: data) {
            savedCounters = decoded
        }

        // A state from another device was adopted.
        remoteObserver = NotificationCenter.default.addObserver(forName: .syncDidApplyRemote,
                                                                object: nil,
                                                                queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.reloadFromDefaults() }
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

    /// Time of the last local change (for syncing).
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
            updatedAt: updatedAt ?? .distantPast
        )
    }

    /// Adopts a foreign state without marking it as a new local change.
    static func applySync(_ snapshot: SyncSnapshot) {
        let defaults = Self.defaults
        defaults.set(snapshot.count, forKey: countKey)
        if let data = try? JSONEncoder().encode(snapshot.savedCounters) {
            defaults.set(data, forKey: savedKey)
        }
        defaults.set(min(maxRate, max(minRate, snapshot.rate)), forKey: rateKey)
        updatedAt = snapshot.updatedAt
    }

    /// Notes the change for the Wi-Fi sync.
    private static func markChanged() {
        updatedAt = Date()
        NotificationCenter.default.post(name: .counterStoreDidChange, object: nil)
    }

    /// Takes changed values from UserDefaults into the published properties.
    private func reloadFromDefaults() {
        // Stop a running auto counter without saving the old state again.
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
}
