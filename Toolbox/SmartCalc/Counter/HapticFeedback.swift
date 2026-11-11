//
//  HapticFeedback.swift
//  counter
//

import SwiftUI
import UIKit

/// Haptic feedback manager for the app
final class HapticManager {
    static let shared = HapticManager()
    private init() {}

    var isHapticsEnabled = true

    func impactOccurred() {
        guard isHapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func heavyImpactOccurred() {
        guard isHapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}
