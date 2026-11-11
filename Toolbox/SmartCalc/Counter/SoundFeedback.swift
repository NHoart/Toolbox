//
//  SoundFeedback.swift
//  counter
//

import AVFoundation
import AudioToolbox

/// Ton-Feedback für den Zähler.
///
/// Die Audio-Session läuft in der Kategorie `.ambient`: Ist das Handy
/// stummgeschaltet, bleibt die App still; Musik anderer Apps läuft weiter.
final class SoundManager {
    static let shared = SoundManager()

    /// Kann später über eine Einstellung abgeschaltet werden.
    var isSoundEnabled = true

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    #if os(iOS)
    /// Die Session wird einmalig asynchron aktiviert. Das synchrone
    /// `setActive(_:)` blockiert auf dem Main-Thread und kann die App
    /// unresponsive werden lassen.
    private var isSessionActive = false
    private var isActivatingSession = false
    /// Ton, der noch auf die Aktivierung wartet, damit der erste Tipp nicht stumm bleibt.
    private var pendingTone: (frequency: Double, duration: Double)?
    #endif

    private init() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        #endif

        engine.attach(player)
        // Seit iOS 27 ersetzt `connectNode(_:to:format:)` das veraltete `connect(_:to:format:)`.
        try? engine.connectNode(player, to: engine.mainMixerNode, format: format)

        #if os(iOS)
        activateSession()
        #endif
    }

    // MARK: - Töne

    /// Heller Ton beim Hochzählen.
    func playIncrement() {
        play(frequency: 880)
    }

    /// Tiefere Variante beim Runterzählen.
    func playDecrement() {
        play(frequency: 587.33)
    }

    /// Etwas längerer Ton beim Zurücksetzen.
    func playReset() {
        play(frequency: 440, duration: 0.18)
    }

    // MARK: - Wiedergabe

    private func play(frequency: Double, duration: Double = 0.09) {
        guard isSoundEnabled else { return }

        #if os(iOS)
        guard isSessionActive else {
            // Aktivierung läuft noch: Ton merken und danach abspielen.
            pendingTone = (frequency, duration)
            activateSession()
            return
        }
        #endif

        playNow(frequency: frequency, duration: duration)
    }

    private func playNow(frequency: Double, duration: Double) {
        if !engine.isRunning {
            try? engine.start()
        }

        guard engine.isRunning,
              let buffer = makeBuffer(frequency: frequency, duration: duration) else {
            // Fallback: System-Ton, respektiert den Stummschalter ebenfalls.
            AudioServicesPlaySystemSound(1104)
            return
        }

        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        // Seit iOS 27 ersetzt `playAudio()` das veraltete `play()`.
        try? player.playAudio()
    }

    #if os(iOS)
    /// Aktiviert die Audio-Session asynchron, ohne den Main-Thread zu blockieren.
    private func activateSession() {
        guard !isSessionActive, !isActivatingSession else { return }
        isActivatingSession = true

        Task { @MainActor in
            defer { isActivatingSession = false }

            do {
                try await AVAudioSession.sharedInstance().activate(options: [])
                isSessionActive = true

                if let tone = pendingTone {
                    pendingTone = nil
                    playNow(frequency: tone.frequency, duration: tone.duration)
                }
            } catch {
                // Aktivierung fehlgeschlagen: wartenden Ton als System-Ton spielen.
                if pendingTone != nil {
                    pendingTone = nil
                    AudioServicesPlaySystemSound(1104)
                }
            }
        }
    }
    #endif

    /// Kurzer Sinus-Ton mit weichem Ein- und Ausblenden (kein Knacken).
    private func makeBuffer(frequency: Double, duration: Double) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)

        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else {
            return nil
        }

        buffer.frameLength = frameCount

        let totalFrames = Int(frameCount)
        let fadeFrames = max(1, Int(sampleRate * 0.012))

        for frame in 0..<totalFrames {
            let fadeIn = min(1.0, Double(frame) / Double(fadeFrames))
            let fadeOut = min(1.0, Double(totalFrames - frame) / Double(fadeFrames))
            let envelope = min(fadeIn, fadeOut)
            let tone = sin(2 * .pi * frequency * Double(frame) / sampleRate)
            samples[frame] = Float(tone * envelope * 0.25)
        }

        return buffer
    }
}
