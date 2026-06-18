//
//  StreakSection.swift
//  MedicineReminder — Analytics
//
//  The streak hero: an animated flame next to a `StreakRing` showing the
//  current streak, with the longest streak alongside. When the current
//  streak is a multiple of seven a `ConfettiCanvas` burst fires (driven by
//  the parent through a binding). The flame pulse and confetti both honor
//  Reduce Motion.
//

import SwiftUI

/// The streak summary card. Pure presentation — it receives precomputed
/// streak values and a `celebrate` binding the parent flips on milestones.
struct StreakSection: View {
    let currentStreak: Int
    let longestStreak: Int
    @Binding var celebrate: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flamePulse = false

    /// Ring fills toward the next 7-day milestone so progress feels earned.
    private var ringProgress: Double {
        guard currentStreak > 0 else { return 0 }
        let intoMilestone = currentStreak % 7
        // A completed milestone shows a full ring rather than an empty one.
        return intoMilestone == 0 ? 1 : Double(intoMilestone) / 7.0
    }

    private var ringGradient: LinearGradient {
        currentStreak > 0 ? MedicineColor.tangerine.gradient : MedicineColor.slate.gradient
    }

    var body: some View {
        GlassCard(tint: currentStreak > 0 ? MedicineColor.tangerine.color : nil) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionHeader("Streak", systemImage: "flame.fill", tint: MedicineColor.tangerine.color)

                HStack(spacing: Spacing.xl) {
                    ZStack {
                        StreakRing(
                            progress: ringProgress,
                            gradient: ringGradient,
                            value: "\(currentStreak)",
                            caption: streakCaption,
                            diameter: 132
                        )
                        flame
                            .offset(y: -78)
                            .accessibilityHidden(true)
                    }

                    longestColumn
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Text(encouragement)
                    .font(AppFont.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .overlay {
            ConfettiCanvas(
                isActive: $celebrate,
                colors: [
                    MedicineColor.tangerine.color,
                    MedicineColor.amber.color,
                    MedicineColor.coral.color,
                    MedicineColor.emerald.color
                ]
            )
            .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Flame

    private var flame: some View {
        Image(systemName: "flame.fill")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(
                currentStreak > 0
                    ? LinearGradient(colors: [.yellow, .orange, .red],
                                     startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [.gray, .gray],
                                     startPoint: .top, endPoint: .bottom)
            )
            .scaleEffect(flamePulse && currentStreak > 0 && !reduceMotion ? 1.12 : 1)
            .shadow(color: .orange.opacity(currentStreak > 0 ? 0.5 : 0), radius: 8)
            .modifier(SymbolPulse(active: currentStreak > 0))
            .onAppear { startPulse() }
            .onChange(of: currentStreak) { _, _ in startPulse() }
    }

    private func startPulse() {
        guard currentStreak > 0, !reduceMotion else {
            flamePulse = false
            return
        }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            flamePulse = true
        }
    }

    // MARK: - Longest column

    private var longestColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Longest")
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text("\(longestStreak)")
                    .font(AppFont.largeTitle)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(longestStreak == 1 ? "day" : "days")
                    .font(AppFont.subheadline)
                    .foregroundStyle(.secondary)
            }
            if currentStreak >= longestStreak, longestStreak > 0 {
                Label("Personal best", systemImage: "trophy.fill")
                    .font(AppFont.caption)
                    .foregroundStyle(MedicineColor.amber.color)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Longest streak")
        .accessibilityValue("\(longestStreak) \(longestStreak == 1 ? "day" : "days")")
    }

    // MARK: - Copy

    private var streakCaption: String {
        currentStreak == 1 ? "day" : "days"
    }

    private var encouragement: String {
        switch currentStreak {
        case 0:
            return "Take every scheduled dose today to start a new streak."
        case 1...6:
            let remaining = 7 - currentStreak
            return "On a roll — \(remaining) more \(remaining == 1 ? "day" : "days") to a one-week streak."
        default:
            return "Amazing consistency. Keep it going!"
        }
    }
}

// MARK: - Symbol pulse (Reduce-Motion aware)

/// Applies a subtle `.symbolEffect` breathing pulse when active and motion is
/// allowed; otherwise renders the symbol statically.
private struct SymbolPulse: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if active && !reduceMotion {
            content.symbolEffect(.pulse, options: .repeating)
        } else {
            content
        }
    }
}

// MARK: - Preview

#if DEBUG
private struct StreakSectionPreview: View {
    @State private var celebrate = false
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                StreakSection(currentStreak: 7, longestStreak: 14, celebrate: $celebrate)
                StreakSection(currentStreak: 0, longestStreak: 9, celebrate: .constant(false))
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { celebrate = true }
    }
}

#Preview("StreakSection") {
    StreakSectionPreview()
}
#endif
