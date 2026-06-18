//
//  ColorChip.swift
//  MedicineReminder — DesignSystem
//
//  A selectable swatch for a `MedicineColor`, used in the color picker of the
//  add/edit flow. Shows a checkmark when selected. Widget-safe (SwiftUI only)
//  but primarily used in-app; exposes accessibility for interactive use.
//

import SwiftUI

public struct ColorChip: View {
    private let color: MedicineColor
    private let isSelected: Bool
    private let size: CGFloat

    public init(color: MedicineColor, isSelected: Bool, size: CGFloat = 36) {
        self.color = color
        self.isSelected = isSelected
        self.size = size
    }

    public var body: some View {
        Circle()
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
            )
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: size * 0.42, weight: .bold))
                        .foregroundStyle(.white)
                        .accessibilityHidden(true)
                }
            }
            .overlay {
                if isSelected {
                    Circle()
                        .strokeBorder(color.color, lineWidth: 2)
                        .padding(-4)
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text(color.displayName))
            .accessibilityValue(Text(isSelected ? "Selected" : "Not selected"))
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Preview

#Preview("ColorChip") {
    let columns = [GridItem(.adaptive(minimum: 44), spacing: Spacing.md)]
    ScrollView {
        LazyVGrid(columns: columns, spacing: Spacing.md) {
            ForEach(MedicineColor.allCases) { c in
                ColorChip(color: c, isSelected: c == .blue)
            }
        }
        .padding()
    }
}
