//
//  MonthlyHeatmapSection.swift
//  MedicineReminder — Analytics
//
//  A calendar-style heatmap of the last ~30 days. Each cell is one day; its
//  fill intensity tracks that day's adherence (empty for days with no
//  scheduled doses). Cells are laid out in weekday columns (leading blanks
//  pad the first row) with a legend. Every populated cell is an accessibility
//  element describing its date and adherence.
//

import SwiftUI

/// Monthly adherence heatmap card. Lays the supplied daily stats into a
/// weekday-aligned grid and colors each cell by its rate.
struct MonthlyHeatmapSection: View {
    let days: [DailyAdherence]
    let calendar: Calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Spacing.xs), count: 7)
    private let baseColor = MedicineColor.emerald

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(
                    "Last 30 days",
                    systemImage: "calendar",
                    tint: baseColor.color
                )

                weekdayHeader

                LazyVGrid(columns: columns, spacing: Spacing.xs) {
                    ForEach(0..<leadingBlanks, id: \.self) { index in
                        Color.clear
                            .frame(height: cellHeight)
                            .accessibilityHidden(true)
                            .id("blank-\(index)")
                    }
                    ForEach(days) { day in
                        HeatCell(day: day, baseColor: baseColor, height: cellHeight)
                    }
                }

                legend
            }
        }
    }

    private let cellHeight: CGFloat = 30

    /// Empty leading cells so the first day sits under its real weekday column.
    private var leadingBlanks: Int {
        guard let first = days.first?.day else { return 0 }
        // weekday: 1 = Sunday ... 7 = Saturday. Normalize to the calendar's first weekday.
        let weekday = calendar.component(.weekday, from: first)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekdayHeader: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    /// Single-letter weekday headers, rotated to the calendar's first weekday.
    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var legend: some View {
        HStack(spacing: Spacing.sm) {
            Text("Less")
                .font(AppFont.caption2)
                .foregroundStyle(.secondary)
            ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .fill(fill(for: level, hasDoses: level > 0))
                    .frame(width: 16, height: 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                    )
            }
            Text("More")
                .font(AppFont.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Legend: cell color intensity increases with daily adherence")
    }

    private func fill(for rate: Double, hasDoses: Bool) -> Color {
        guard hasDoses else { return Color.primary.opacity(0.06) }
        // Map 0...1 onto a visible opacity band so even low days are legible.
        let opacity = 0.18 + min(max(rate, 0), 1) * 0.82
        return baseColor.color.opacity(opacity)
    }
}

// MARK: - Heat cell

private struct HeatCell: View {
    let day: DailyAdherence
    let baseColor: MedicineColor
    let height: CGFloat

    private var hasDoses: Bool { day.stat.scheduled > 0 }

    var body: some View {
        RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
            .fill(fill)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.sm, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .overlay(
                Text(dayNumber)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(textColor)
                    .accessibilityHidden(true)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(dateLabel)
            .accessibilityValue(valueLabel)
    }

    private var fill: Color {
        guard hasDoses else { return Color.primary.opacity(0.06) }
        let opacity = 0.18 + min(max(day.rate, 0), 1) * 0.82
        return baseColor.color.opacity(opacity)
    }

    /// Keep the day number readable against denser fills.
    private var textColor: Color {
        guard hasDoses else { return .secondary }
        return day.rate >= 0.55 ? .white : .primary
    }

    private var dayNumber: String {
        "\(Calendar.current.component(.day, from: day.day))"
    }

    private var dateLabel: Text {
        Text(day.day.formatted(.dateTime.weekday(.wide).month().day()))
    }

    private var valueLabel: Text {
        guard hasDoses else { return Text("No scheduled doses") }
        let pct = Int((day.rate * 100).rounded())
        return Text("\(pct) percent, \(day.stat.taken) of \(day.stat.scheduled) doses taken")
    }
}

// MARK: - Preview

#if DEBUG
private struct HeatmapPreview: View {
    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sample: [DailyAdherence] = (0..<30).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let scheduled = offset % 6 == 0 ? 0 : 3
            let taken = scheduled == 0 ? 0 : max(0, scheduled - (offset % 4))
            return DailyAdherence(day: day, stat: AdherenceStat(taken: taken, scheduled: scheduled))
        }
        return MonthlyHeatmapSection(days: sample, calendar: calendar)
            .padding()
            .background(Color(.systemGroupedBackground))
    }
}

#Preview("MonthlyHeatmapSection") {
    HeatmapPreview()
}
#endif
