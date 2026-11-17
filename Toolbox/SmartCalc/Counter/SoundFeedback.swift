//
//  SoundFeedback.swift
//  counter
//

import AVFoundation
import AudioToolbox

/// Sound feedback for the counter.
///
/// The audio session runs in the `.ambient` category: if the phone is
/// muted, the app stays silent; music from other apps keeps playing.
final class SoundManager {
    static let shared = SoundManager()

    /// Can later be turned off through a setting.
    var isSoundEnabled = true

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    #if os(iOS)
    /// The session is activated once asynchronously. The synchronous
    /// `setActive(_:)` blocks on the main thread and can make the app
    /// unresponsive.
    private var isSessionActive = false
    private var isActivatingSession = false
    /// Sound waiting for activation so the first tap is not silent.
    private var pendingTone: (frequency: Double, duration: Double)?
    #endif

    private init() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        #endif

        engine.attach(player)
        // Since iOS 27 `connectNode(_:to:format:)` replaces the deprecated `connect(_:to:format:)`.
        try? engine.connectNode(player, to: engine.mainMixerNode, format: format)

        #if os(iOS)
        activateSession()
        #endif
    }

    // MARK: - Sounds

    /// Bright sound when counting up.
    func playIncrement() {
        play(frequency: 880)
    }

    /// Lower variant when counting down.
    func playDecrement() {
        play(frequency: 587.33)
    }

    /// Slightly longer sound when resetting.
    func playReset() {
        play(frequency: 440, duration: 0.18)
    }

    // MARK: - Wiedergabe

    private func play(frequency: Double, duration: Double = 0.09) {
        guard isSoundEnabled else { return }

        #if os(iOS)
        guard isSessionActive else {
            // Activation still running: remember the sound and play it afterwards.
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
            // Fallback: system sound, which also respects the mute switch.
            AudioServicesPlaySystemSound(1104)
            return
        }

        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        // Since iOS 27 `playAudio()` replaces the deprecated `play()`.
        try? player.playAudio()
    }

    #if os(iOS)
    /// Activates the audio session asynchronously without blocking the main thread.
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
                // Activation failed: play the waiting sound as a system sound.
                if pendingTone != nil {
                    pendingTone = nil
                    AudioServicesPlaySystemSound(1104)
                }
            }
        }
    }
    #endif

    /// Short sine tone with a soft fade in and out (no click).
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
