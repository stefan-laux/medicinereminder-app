//
//  StreakRing.swift
//  MedicineReminder — DesignSystem
//
//  A circular progress ring with a centered value, used for streaks and
//  adherence. Widget-safe (SwiftUI only). Honors Reduce Motion for the
//  fill animation.
//

import SwiftUI

public struct StreakRing: View {
    /// Progress in 0...1 (clamped).
    private let progress: Double
    /// Ring stroke gradient tint.
    private let gradient: LinearGradient
    /// Large centered value (e.g. "12").
    private let value: String
    /// Caption under the value (e.g. "days").
    private let caption: String?
    private let lineWidth: CGFloat
    private let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        progress: Double,
        gradient: LinearGradient,
        value: String,
        caption: String? = nil,
        lineWidth: CGFloat = 12,
        diameter: CGFloat = 120
    ) {
        self.progress = min(max(progress, 0), 1)
        self.gradient = gradient
        self.value = value
        self.caption = caption
        self.lineWidth = lineWidth
        self.diameter = diameter
    }

    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    gradient,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? nil : .smooth(duration: 0.6), value: progress)

            VStack(spacing: Spacing.xs) {
                Text(value)
                    .font(AppFont.rounded(diameter * 0.28, .bold))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                if let caption {
                    Text(caption)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(lineWidth)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(Text("\(Int((progress * 100).rounded())) percent"))
    }

    private var accessibilityLabel: Text {
        if let caption {
            return Text("\(value) \(caption)")
        }
        return Text(value)
    }
}

// MARK: - Preview

#Preview("StreakRing") {
    HStack(spacing: Spacing.xl) {
        StreakRing(
            progress: 0.72,
            gradient: MedicineColor.emerald.gradient,
            value: "12",
            caption: "days"
        )
        StreakRing(
            progress: 0.4,
            gradient: MedicineColor.violet.gradient,
            value: "85%",
            caption: "adherence",
            lineWidth: 8,
            diameter: 90
        )
    }
    .padding()
}
