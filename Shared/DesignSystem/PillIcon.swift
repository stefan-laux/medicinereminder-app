//
//  PillIcon.swift
//  MedicineReminder — DesignSystem
//
//  A rounded, gradient-filled icon badge for a medicine, showing its SF
//  Symbol over its accent gradient. Widget-safe (SwiftUI only).
//

import SwiftUI

public struct PillIcon: View {
    private let systemName: String
    private let color: MedicineColor
    private let size: CGFloat

    public init(systemName: String, color: MedicineColor, size: CGFloat = 44) {
        self.systemName = systemName
        self.color = color
        self.size = size
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(color.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.5)
            )
            .shadow(color: color.color.opacity(0.35), radius: size * 0.12, x: 0, y: size * 0.06)
            .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("PillIcon") {
    HStack(spacing: Spacing.lg) {
        PillIcon(systemName: "pills.fill", color: .coral)
        PillIcon(systemName: "cross.vial.fill", color: .teal, size: 56)
        PillIcon(systemName: "drop.fill", color: .blue, size: 32)
        PillIcon(systemName: "bandage.fill", color: .amber)
    }
    .padding()
}
