//
//  AppColors.swift
//  counter
//
//  Created by Noah H on 02.11.26.
//

import SwiftUI

struct AppColors {
    // Base theme colors - modern iOS palette
    static let primary = Color(red: 0.95, green: 0.8, blue: 0.3)
    static let secondary = Color(red: 0.4, green: 0.1, blue: 0.9)
    static let accent = Color(red: 0.5, green: 0.2, blue: 0.8)
    static let neutralLight = Color.white.opacity(0.08)
    static let neutralDark = Color.black.opacity(0.12)
    
    // Gradient colors for visual appeal
    struct Gradients {
        static let primaryToSecondary: [Color] = {
            [
                Color(red: 0.4, green: 0.8, blue: 1.0),
                Color(red: 0.7, green: 0.2, blue: 0.8),
                Color(red: 0.5, green: 0.9, blue: 0.3)
            ]
        }()
        
        static let glassEffect: [Color] = {
            [
                Color.white.opacity(0.1),
                Color.black.opacity(0.08)
            ]
        }()
    }
}

extension AppColors {
    // Light mode background variants
    static var lightBackground: Color { .white }
    static var lightSurface: Color { .white.opacity(0.95) }
    
    // Dark mode background variants
    static var darkBackground: Color { Color.black }
    static var darkSurface: Color { Color.black.opacity(0.12) }
}
