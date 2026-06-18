//
//  MedicineColor+UI.swift
//  MedicineReminder — DesignSystem
//
//  SwiftUI presentation for the programmatic `MedicineColor` palette.
//  Uses the adaptive light/dark hex values so accents track appearance.
//  (MedicineColor itself is declared in Shared/Enums; we only add UI here.)
//

import SwiftUI

public extension MedicineColor {
    /// The accent color for this palette entry, adaptive to light/dark mode.
    var color: Color {
        Color(lightHex: lightHex, darkHex: darkHex)
    }

    /// A diagonal gradient from a slightly lighter to the base accent — used
    /// for pill icons, rings, and emphasis fills.
    var gradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(lightHex: lightHex, darkHex: darkHex).opacity(0.85),
                Color(lightHex: lightHex, darkHex: darkHex)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A soft, low-opacity tint of the accent for backgrounds and chips.
    var soft: Color {
        Color(lightHex: lightHex, darkHex: darkHex).opacity(0.18)
    }
}
