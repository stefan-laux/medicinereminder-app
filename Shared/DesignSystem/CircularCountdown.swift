//
//  CircularCountdown.swift
//  MedicineReminder — DesignSystem
//
//  A circular countdown to the next dose. The ring depletes as the target
//  time approaches and shows a live relative-time label. Widget-safe
//  (SwiftUI only) and Reduce-Motion aware. Drives its own clock via
//  TimelineView so it updates without external state.
//

import SwiftUI

public struct CircularCountdown: View {
    /// The moment the dose is due.
    private let target: Date
    /// The start of the window used to compute progress (e.g. the previous
    /// dose time, or `target - window`). Progress = elapsed / total.
    private let start: Date
    private let gradient: LinearGradient
    private let lineWidth: CGFloat
    private let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        target: Date,
        start: Date,
        gradient: LinearGradient,
        lineWidth: CGFloat = 10,
        diameter: CGFloat = 110
    ) {
        self.target = target
        self.start = start
        self.gradient = gradient
        self.lineWidth = lineWidth
        self.diameter = diameter
    }

    public var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            let now = context.date
            let remaining = max(0, target.timeIntervalSince(now))
            let progress = remainingFraction(now: now)

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.10), lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .linear(duration: 1), value: progress)

                VStack(spacing: Spacing.xs) {
                    Image(systemName: remaining > 0 ? "clock.fill" : "bell.fill")
                        .font(.system(size: diameter * 0.16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text(label(remaining: remaining))
                        .font(AppFont.rounded(diameter * 0.16, .semibold))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .padding(lineWidth)
            }
            .frame(width: diameter, height: diameter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Time until next dose"))
            .accessibilityValue(Text(accessibilityValue(remaining: remaining)))
        }
    }

    /// Fraction of the window remaining, in 0...1.
    private func remainingFraction(now: Date) -> Double {
        let total = target.timeIntervalSince(start)
        guard total > 0 else { return target > now ? 1 : 0 }
        let remaining = target.timeIntervalSince(now)
        return min(max(remaining / total, 0), 1)
    }

    private func label(remaining: TimeInterval) -> String {
        guard remaining > 0 else { return "Now" }
        let totalMinutes = Int(remaining / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "<1m"
    }

    private func accessibilityValue(remaining: TimeInterval) -> String {
        guard remaining > 0 else { return "Due now" }
        let totalMinutes = Int(remaining / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        var parts: [String] = []
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if minutes > 0 { parts.append("\(minutes) minute\(minutes == 1 ? "" : "s")") }
        if parts.isEmpty { parts.append("less than a minute") }
        return parts.joined(separator: " ") + " remaining"
    }
}

// MARK: - Preview

#Preview("CircularCountdown") {
    CircularCountdown(
        target: Date().addingTimeInterval(60 * 95),
        start: Date().addingTimeInterval(-60 * 25),
        gradient: MedicineColor.sky.gradient
    )
    .padding()
}
