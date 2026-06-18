//
//  MarkerDots.swift
//  MedicineReminder
//
//  A tiny row of colored dots representing the distinct medicines due on a
//  given day, used by both the weekly strip and the month calendar cells.
//  When more medicines are due than fit, the final dot becomes a neutral
//  "overflow" dot. Decorative only — callers provide the accessible summary.
//

import SwiftUI

/// A compact row of medicine-colored marker dots. Internal to the Plans
/// feature so both the week strip and month grid can share it.
struct MarkerDots: View {
    /// Distinct medicine colors for the day, in display order.
    let colors: [MedicineColor]
    /// Maximum dots to draw before collapsing the remainder into an overflow dot.
    let maxDots: Int
    /// Diameter of each dot.
    var dotSize: CGFloat = 5

    var body: some View {
        HStack(spacing: 3) {
            ForEach(visibleColors.indices, id: \.self) { index in
                Circle()
                    .fill(visibleColors[index].color)
                    .frame(width: dotSize, height: dotSize)
            }
            if hasOverflow {
                Circle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: dotSize, height: dotSize)
            }
        }
        .accessibilityHidden(true)
    }

    /// The colors actually drawn as distinct dots (reserving one slot for the
    /// overflow indicator when needed).
    private var visibleColors: [MedicineColor] {
        guard colors.count > maxDots else { return colors }
        return Array(colors.prefix(max(0, maxDots - 1)))
    }

    private var hasOverflow: Bool {
        colors.count > maxDots
    }
}

#if DEBUG
#Preview("Marker Dots") {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        MarkerDots(colors: [], maxDots: 3)
        MarkerDots(colors: [.blue], maxDots: 3)
        MarkerDots(colors: [.blue, .emerald], maxDots: 3)
        MarkerDots(colors: [.blue, .emerald, .amber], maxDots: 3)
        MarkerDots(colors: [.blue, .emerald, .amber, .coral, .violet], maxDots: 3)
        MarkerDots(colors: [.blue, .emerald, .amber, .coral, .violet], maxDots: 4, dotSize: 7)
    }
    .padding()
}
#endif
