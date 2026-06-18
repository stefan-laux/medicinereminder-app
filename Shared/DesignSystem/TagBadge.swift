//
//  TagBadge.swift
//  MedicineReminder — DesignSystem
//
//  A small pill-shaped badge for metadata tags. The canonical use is the
//  "Custom" badge shown on medicines with no FDA match. Widget-safe.
//

import SwiftUI

public struct TagBadge: View {
    private let text: String
    private let systemImage: String?
    private let tint: Color

    public init(_ text: String, systemImage: String? = nil, tint: Color = .secondary) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    /// Convenience for the standard "Custom" badge.
    public static var custom: TagBadge {
        TagBadge("Custom", systemImage: "wand.and.stars", tint: .indigo)
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(AppFont.caption2.weight(.semibold))
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .foregroundStyle(tint)
        .background(tint.opacity(0.15), in: Capsule())
        .overlay(
            Capsule().strokeBorder(tint.opacity(0.25), lineWidth: 0.5)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
    }
}

// MARK: - Preview

#Preview("TagBadge") {
    VStack(spacing: Spacing.md) {
        TagBadge.custom
        TagBadge("As needed", systemImage: "hand.raised.fill", tint: MedicineColor.amber.color)
        TagBadge("FDA", systemImage: "checkmark.seal.fill", tint: MedicineColor.emerald.color)
        TagBadge("Archived")
    }
    .padding()
}
