//
//  WeeklyAdherenceChart.swift
//  MedicineReminder — Analytics
//
//  A seven-day adherence bar chart (Swift Charts `BarMark`). Each bar is one
//  day's taken/scheduled ratio, colored on a red→amber→green scale by how
//  complete the day was. Axes are labeled, the chart and every bar expose
//  accessibility labels/values, and an average summary sits above the plot.
//

import SwiftUI
import Charts

/// Weekly adherence bar chart card. Receives precomputed daily stats
/// (oldest → newest) from the parent.
struct WeeklyAdherenceChart: View {
    let days: [DailyAdherence]

    private let calendar = Calendar.current

    /// Average adherence across days that actually had scheduled doses.
    private var averageRate: Double {
        let active = days.filter { $0.stat.scheduled > 0 }
        guard !active.isEmpty else { return 0 }
        return active.map(\.rate).reduce(0, +) / Double(active.count)
    }

    private var averageText: String {
        "\(Int((averageRate * 100).rounded()))% average"
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(
                    "Last 7 days",
                    subtitle: hasScheduledDoses ? averageText : nil,
                    systemImage: "chart.bar.fill",
                    tint: MedicineColor.emerald.color
                )

                if hasScheduledDoses {
                    chart
                } else {
                    noDataRow
                }
            }
        }
    }

    private var hasScheduledDoses: Bool {
        days.contains { $0.stat.scheduled > 0 }
    }

    private var noDataRow: some View {
        Text("No scheduled doses in the last week.")
            .font(AppFont.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.sm)
    }

    private var chart: some View {
        Chart(days) { day in
            BarMark(
                x: .value("Day", day.day, unit: .day),
                y: .value("Adherence", day.rate)
            )
            .foregroundStyle(barColor(for: day.rate))
            .cornerRadius(Radius.sm)
            .accessibilityLabel(weekdayLabel(day.day))
            .accessibilityValue(barValue(for: day))
        }
        .chartYScale(domain: 0...1)
        .chartYAxis {
            AxisMarks(values: [0, 0.5, 1]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let rate = value.as(Double.self) {
                        Text("\(Int(rate * 100))%")
                            .font(AppFont.caption2)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(shortWeekday(date))
                            .font(AppFont.caption2)
                    }
                }
            }
        }
        .frame(height: 180)
        .accessibilityLabel("Weekly adherence chart")
        .accessibilityValue(averageText)
    }

    // MARK: - Helpers

    /// Red (low) → amber (mid) → green (high) by completeness.
    private func barColor(for rate: Double) -> Color {
        switch rate {
        case ..<0.5: return MedicineColor.coral.color
        case ..<0.85: return MedicineColor.amber.color
        default: return MedicineColor.emerald.color
        }
    }

    private func shortWeekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.narrow))
    }

    private func weekdayLabel(_ date: Date) -> Text {
        Text(date.formatted(.dateTime.weekday(.wide).month().day()))
    }

    private func barValue(for day: DailyAdherence) -> Text {
        let pct = Int((day.rate * 100).rounded())
        return Text("\(pct) percent, \(day.stat.taken) of \(day.stat.scheduled) doses taken")
    }
}

// MARK: - Preview

#if DEBUG
private struct WeeklyChartPreview: View {
    var body: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let sample: [DailyAdherence] = (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let scheduled = 3
            let taken = [3, 2, 3, 1, 3, 3, 2][offset % 7]
            return DailyAdherence(day: day, stat: AdherenceStat(taken: taken, scheduled: scheduled))
        }
        return WeeklyAdherenceChart(days: sample)
            .padding()
            .background(Color(.systemGroupedBackground))
    }
}

#Preview("WeeklyAdherenceChart") {
    WeeklyChartPreview()
}
#endif
