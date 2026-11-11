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
            let clamped = min(Self.maxRate, max(Self.minRate, incrementsPerSecond))
            guard clamped == incrementsPerSecond else {
                incrementsPerSecond = clamped
                return
            }
            UserDefaults.standard.set(clamped, forKey: rateKey)
        }
    }

    /// Läuft der automatische Zähler gerade?
    @Published private(set) var isAutoRunning = false

    static let minRate = 1
    static let maxRate = 100

    private var history: [Int] = []

    private let countKey = "counter_value"
    private let savedKey = "saved_counters"
    private let rateKey = "counter_rate"

    private var autoTimer: Timer?
    private var autoRemainder: Double = 0
    private var countAtAutoStart = 0
    private var lastAutoPersist = Date.distantPast
    private var lastAutoSound = Date.distantPast
    private let tickInterval: TimeInterval = 1.0 / 30.0

    /// Damit der Ton bei hohen Raten nicht zum Dauerpiepen wird.
    private static let maxAutoSoundsPerSecond = 10.0

    private var historyEnabled: Bool {
        !UserDefaults.standard.bool(forKey: "disable_history")
    }

    init() {
        count = UserDefaults.standard.integer(forKey: countKey)

        let storedRate = UserDefaults.standard.integer(forKey: rateKey)
        incrementsPerSecond = storedRate > 0 ? min(Self.maxRate, storedRate) : 5

        if let data = UserDefaults.standard.data(forKey: savedKey),
           let decoded = try? JSONDecoder().decode([SavedCounter].self, from: data) {
            savedCounters = decoded
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
        UserDefaults.standard.set(count, forKey: countKey)
        HapticManager.shared.impactOccurred()
    }

    /// Setzt den Wert und merkt sich den alten für Undo
    private func setCount(_ newValue: Int) {
        if historyEnabled {
            history.append(count)
        }
        count = newValue
        UserDefaults.standard.set(count, forKey: countKey)
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
        UserDefaults.standard.set(count, forKey: countKey)

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
            UserDefaults.standard.set(count, forKey: countKey)
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
            UserDefaults.standard.set(data, forKey: savedKey)
        }
    }
}
