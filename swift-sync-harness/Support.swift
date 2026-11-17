import Foundation

/// Headless replacement for haptics and sound. The real sync code uses these
/// calls only as UI feedback; the protocol test does not need them.
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
