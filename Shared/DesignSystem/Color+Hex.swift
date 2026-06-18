//
//  Color+Hex.swift
//  MedicineReminder — DesignSystem
//
//  Hex-based Color initializers, including an appearance-adaptive variant
//  backed by a UIColor dynamic provider so colors track light/dark mode.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public extension Color {
    /// Build a `Color` from a 24-bit RGB hex value (e.g. `0xFF6B6B`).
    /// - Parameters:
    ///   - hex: 0xRRGGBB packed integer.
    ///   - alpha: Opacity in 0...1.
    init(hex: UInt, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// Build an appearance-adaptive `Color` that resolves to `lightHex` in
    /// light mode and `darkHex` in dark mode. On platforms with UIKit this is
    /// backed by a dynamic `UIColor` provider; otherwise it falls back to the
    /// light value.
    init(lightHex: UInt, darkHex: UInt, alpha: Double = 1) {
        #if canImport(UIKit)
        let dynamic = UIColor { trait in
            let hex = trait.userInterfaceStyle == .dark ? darkHex : lightHex
            return UIColor(
                red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                blue: CGFloat(hex & 0xFF) / 255.0,
                alpha: CGFloat(alpha)
            )
        }
        self.init(uiColor: dynamic)
        #else
        self.init(hex: lightHex, alpha: alpha)
        #endif
    }
}
