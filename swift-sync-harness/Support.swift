import Foundation

/// Headless-Ersatz für Haptik und Ton. Der echte Sync-Code nutzt diese
/// Aufrufe nur als UI-Feedback; für den Protokolltest sind sie nicht nötig.
final class HapticManager {
    static let shared = HapticManager()

    private init() {}

    func impactOccurred() {}
    func heavyImpactOccurred() {}
}

final class SoundManager {
    static let shared = SoundManager()

    private init() {}

    var isSoundEnabled = true

    func playIncrement() {}
    func playDecrement() {}
    func playReset() {}
}
