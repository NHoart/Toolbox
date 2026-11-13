//
//  CounterStore.swift
//  counter
//

import Foundation
import SwiftUI
import Combine

/// Ein benannter, gespeicherter Zählerstand
struct SavedCounter: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var value: Int
    var date = Date()
}

/// State Management für den Zähler inkl. gespeicherter Stände
final class CounterStore: ObservableObject {
    @Published private(set) var count: Int
    @Published private(set) var savedCounters: [SavedCounter] = []

    /// Wie oft der Zähler pro Sekunde automatisch hochzählt.
    @Published var incrementsPerSecond: Int {
        didSet {
            // Beim Übernehmen eines fremden Stands nicht wieder hochladen.
            guard !isApplyingRemote else { return }
            let clamped = min(Self.maxRate, max(Self.minRate, incrementsPerSecond))
            guard clamped == incrementsPerSecond else {
                incrementsPerSecond = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: Self.rateKey)
            Self.markChanged()
        }
    }

    /// Läuft der automatische Zähler gerade?
    @Published private(set) var isAutoRunning = false

    static let minRate = 1
    static let maxRate = 100

    private static let countKey = "counter_value"
    private static let savedKey = "saved_counters"
    private static let rateKey = "counter_rate"
    private static let updatedKey = "sync.counter.updatedAt"

    private var history: [Int] = []

    private var autoTimer: Timer?
    private var autoRemainder: Double = 0
    private var countAtAutoStart = 0
    private var lastAutoPersist = Date.distantPast
    private var lastAutoSound = Date.distantPast
    private let tickInterval: TimeInterval = 1.0 / 30.0

    /// Wird gerade ein Stand von einem anderen Gerät eingespielt?
    private var isApplyingRemote = false
    private var remoteObserver: NSObjectProtocol?

    /// Damit der Ton bei hohen Raten nicht zum Dauerpiepen wird.
    private static let maxAutoSoundsPerSecond = 10.0

    private var historyEnabled: Bool {
        !UserDefaults.standard.bool(forKey: "disable_history")
    }

    init() {
        count = UserDefaults.standard.integer(forKey: Self.countKey)

        let storedRate = UserDefaults.standard.integer(forKey: Self.rateKey)
        incrementsPerSecond = storedRate > 0 ? min(Self.maxRate, storedRate) : 5

        if let data = UserDefaults.standard.data(forKey: Self.savedKey),
           let decoded = try? JSONDecoder().decode([SavedCounter].self, from: data) {
            savedCounters = decoded
        }

        // Ein Stand von einem anderen Gerät wurde übernommen.
        remoteObserver = NotificationCenter.default.addObserver(forName: .syncDidApplyRemote,
                                                                object: nil,
                                                                queue: .main) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in self.reloadFromDefaults() }
        }
    }

    // MARK: - Zähler

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
        UserDefaults.standard.set(count, forKey: Self.countKey)
        Self.markChanged()
        HapticManager.shared.impactOccurred()
    }

    /// Setzt den Wert und merkt sich den alten für Undo
    private func setCount(_ newValue: Int) {
        if historyEnabled {
            history.append(count)
        }
        count = newValue
        UserDefaults.standard.set(count, forKey: Self.countKey)
        Self.markChanged()
    }

    // MARK: - Automatisches Zählen

    /// Startet das automatische Hochzählen mit der eingestellten Rate.
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

    /// Stoppt das automatische Hochzählen.
    func stopAutoCounting() {
        guard isAutoRunning else { return }

        isAutoRunning = false
        autoTimer?.invalidate()
        autoTimer = nil
        autoRemainder = 0
        UserDefaults.standard.set(count, forKey: Self.countKey)
        Self.markChanged()

        // Undo macht den kompletten automatischen Lauf rückgängig.
        if count != countAtAutoStart, historyEnabled {
            history.append(countAtAutoStart)
        }

        HapticManager.shared.impactOccurred()
    }

    private func autoTick() {
        guard isAutoRunning else { return }

        // Die Rate wird gleichmäßig über die Ticks verteilt, damit auch
        // hohe Raten nicht mehr Timer-Aufrufe als nötig benötigen.
        autoRemainder += Double(incrementsPerSecond) * tickInterval
        let steps = Int(autoRemainder)
        guard steps > 0 else { return }
        autoRemainder -= Double(steps)
        count += steps

        playAutoSoundIfNeeded()

        // Nicht bei jedem Tick in die UserDefaults schreiben.
        let now = Date()
        if now.timeIntervalSince(lastAutoPersist) >= 0.5 {
            lastAutoPersist = now
            UserDefaults.standard.set(count, forKey: Self.countKey)
        }
    }

    /// Spielt den Hochzähl-Ton, höchstens `maxAutoSoundsPerSecond` mal pro Sekunde.
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

    // MARK: - Gespeicherte Stände

    /// Speichert den aktuellen Stand unter dem angegebenen Namen
    func saveCurrent(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Stand \(savedCounters.count + 1)" : trimmed

        savedCounters.insert(SavedCounter(name: finalName, value: count), at: 0)
        persistSaved()
        HapticManager.shared.impactOccurred()
    }

    /// Lädt einen gespeicherten Stand als aktuellen Zählerstand
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
            UserDefaults.standard.set(data, forKey: Self.savedKey)
        }
        Self.markChanged()
    }

    // MARK: - Synchronisation mit anderen Geräten

    /// Zeitpunkt der letzten lokalen Änderung (für den Abgleich).
    static var updatedAt: Date? {
        get { UserDefaults.standard.object(forKey: updatedKey) as? Date }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: updatedKey)
            } else {
                UserDefaults.standard.removeObject(forKey: updatedKey)
            }
        }
    }

    /// Gibt es überhaupt Daten, die sich zu synchronisieren lohnen?
    static var hasData: Bool {
        if UserDefaults.standard.integer(forKey: countKey) != 0 { return true }
        guard let data = UserDefaults.standard.data(forKey: savedKey),
              let decoded = try? JSONDecoder().decode([SavedCounter].self, from: data) else {
            return false
        }
        return !decoded.isEmpty
    }

    /// Stand, der zwischen den Geräten ausgetauscht wird.
    struct SyncSnapshot: Codable {
        var count: Int
        var savedCounters: [SavedCounter]
        var rate: Int
        var updatedAt: Date
    }

    static func syncSnapshot() -> SyncSnapshot {
        let stored: [SavedCounter]
        if let data = UserDefaults.standard.data(forKey: savedKey),
           let decoded = try? JSONDecoder().decode([SavedCounter].self, from: data) {
            stored = decoded
        } else {
            stored = []
        }

        let storedRate = UserDefaults.standard.integer(forKey: rateKey)

        return SyncSnapshot(
            count: UserDefaults.standard.integer(forKey: countKey),
            savedCounters: stored,
            rate: storedRate > 0 ? min(maxRate, storedRate) : 5,
            // Ohne Änderungszeit gilt der Stand als alt: Ein frisches Gerät
            // soll damit keinen neueren Stand der anderen überschreiben.
            updatedAt: updatedAt ?? .distantPast
        )
    }

    /// Übernimmt einen fremden Stand, ohne ihn als neue lokale Änderung zu markieren.
    static func applySync(_ snapshot: SyncSnapshot) {
        let defaults = UserDefaults.standard
        defaults.set(snapshot.count, forKey: countKey)
        if let data = try? JSONEncoder().encode(snapshot.savedCounters) {
            defaults.set(data, forKey: savedKey)
        }
        defaults.set(min(maxRate, max(minRate, snapshot.rate)), forKey: rateKey)
        updatedAt = snapshot.updatedAt
    }

    /// Merkt die Änderung für den Abgleich im WLAN vor.
    private static func markChanged() {
        updatedAt = Date()
        NotificationCenter.default.post(name: .counterStoreDidChange, object: nil)
    }

    /// Übernimmt geänderte Werte aus den UserDefaults in die veröffentlichten Eigenschaften.
    private func reloadFromDefaults() {
        // Laufenden Auto-Zähler anhalten, ohne den alten Stand erneut zu speichern.
        if isAutoRunning {
            isAutoRunning = false
            autoTimer?.invalidate()
            autoTimer = nil
            autoRemainder = 0
        }

        isApplyingRemote = true
        defer { isApplyingRemote = false }

        count = UserDefaults.standard.integer(forKey: Self.countKey)
        if let data = UserDefaults.standard.data(forKey: Self.savedKey),
           let decoded = try? JSONDecoder().decode([SavedCounter].self, from: data) {
            savedCounters = decoded
        } else {
            savedCounters = []
        }

        let storedRate = UserDefaults.standard.integer(forKey: Self.rateKey)
        incrementsPerSecond = storedRate > 0 ? min(Self.maxRate, storedRate) : 5
    }
}

extension Notification.Name {
    /// Lokaler Zählerstand wurde geändert (LocalSync verteilt ihn).
    static let counterStoreDidChange = Notification.Name("Toolbox.counterStoreDidChange")
}
