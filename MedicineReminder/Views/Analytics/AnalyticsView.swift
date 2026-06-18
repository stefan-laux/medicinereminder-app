//
//  AnalyticsView.swift
//  MedicineReminder
//
//  The analytics dashboard: streaks (animated flame + StreakRing with a
//  confetti burst on milestone days), a weekly adherence bar chart, a
//  per-medicine adherence breakdown, a monthly calendar heatmap, and
//  all-time totals. All numbers are derived from the pure
//  `StreakCalculator` / `AdherenceCalculator` over the shared SwiftData
//  store. Charts carry accessibility labels/values and axis labels, fonts
//  scale with Dynamic Type, and motion is gated behind Reduce Motion.
//

import SwiftUI
import SwiftData

/// Root analytics screen. Reads medicines + dose logs from the model context,
/// computes streak / adherence statistics, and presents them as a scrolling
/// set of Liquid Glass sections.
public struct AnalyticsView: View {
    // Active (non-archived) medicines, stable ordering for per-medicine lists.
    @Query(
        filter: #Predicate<Medicine> { !$0.isArchived },
        sort: [SortDescriptor(\Medicine.sortIndex), SortDescriptor(\Medicine.createdAt)]
    )
    private var medicines: [Medicine]

    // All dose logs; the calculators decide which fall in range.
    @Query(sort: [SortDescriptor(\DoseLog.scheduledTime, order: .reverse)])
    private var logs: [DoseLog]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fires the confetti burst when the current streak lands on a milestone.
    @State private var celebrate = false
    /// The milestone we last celebrated, so re-renders don't re-fire it.
    @State private var lastCelebratedMilestone = 0

    private let calendar = Calendar.current

    public init() {}

    public var body: some View {
        NavigationStack {
            Group {
                if !hasAnyData {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Insights")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            GlassContainer(spacing: Spacing.lg) {
                VStack(spacing: Spacing.xl) {
                    StreakSection(
                        currentStreak: currentStreak,
                        longestStreak: longestStreak,
                        celebrate: $celebrate
                    )

                    WeeklyAdherenceChart(days: weeklyAdherence)

                    PerMedicineAdherenceList(rows: perMedicineRows)

                    MonthlyHeatmapSection(days: monthlyAdherence, calendar: calendar)

                    AllTimeTotalsSection(totals: allTimeTotals)
                }
                .padding(Spacing.lg)
            }
        }
        .scrollIndicators(.automatic)
        .onAppear { evaluateMilestone() }
        .onChange(of: currentStreak) { _, _ in evaluateMilestone() }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No insights yet", systemImage: "chart.bar.xaxis")
        } description: {
            Text("Add a medicine and start logging doses to see your streaks and adherence here.")
        }
    }

    // MARK: - Milestone celebration

    /// Trigger the confetti burst once per newly-reached 7-day milestone.
    private func evaluateMilestone() {
        let streak = currentStreak
        guard streak > 0, streak % 7 == 0 else { return }
        guard streak != lastCelebratedMilestone else { return }
        lastCelebratedMilestone = streak
        celebrate = true
    }

    // MARK: - Derived data

    private var hasAnyData: Bool {
        !medicines.isEmpty
    }

    private var currentStreak: Int {
        StreakCalculator.currentStreak(medicines: medicines, logs: logs, asOf: Date(), calendar: calendar)
    }

    private var longestStreak: Int {
        StreakCalculator.longestStreak(medicines: medicines, logs: logs, asOf: Date(), calendar: calendar)
    }

    /// The trailing 7 days (oldest → today) of adherence for the bar chart.
    private var weeklyAdherence: [DailyAdherence] {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -6, to: today) else { return [] }
        return AdherenceCalculator
            .daily(medicines: medicines, logs: logs, from: start, to: today, calendar: calendar)
            .map { DailyAdherence(day: $0.day, stat: $0.stat) }
    }

    /// The trailing 30 days of adherence for the calendar heatmap.
    private var monthlyAdherence: [DailyAdherence] {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -29, to: today) else { return [] }
        return AdherenceCalculator
            .daily(medicines: medicines, logs: logs, from: start, to: today, calendar: calendar)
            .map { DailyAdherence(day: $0.day, stat: $0.stat) }
    }

    /// Per-medicine adherence over the trailing 30 days, sorted by rate then name.
    private var perMedicineRows: [MedicineAdherenceRow] {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -29, to: today) else { return [] }
        let stats = AdherenceCalculator.perMedicine(
            medicines: medicines, logs: logs, from: start, to: today, calendar: calendar
        )
        let rows: [MedicineAdherenceRow] = medicines.compactMap { medicine in
            guard let stat = stats[medicine.id], stat.scheduled > 0 else { return nil }
            return MedicineAdherenceRow(
                id: medicine.id,
                name: medicine.name,
                colorRaw: medicine.colorRaw,
                iconName: medicine.iconName,
                stat: stat
            )
        }
        return rows.sorted {
            if $0.stat.rate != $1.stat.rate { return $0.stat.rate > $1.stat.rate }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// All-time taken / skipped / snoozed / pending counts across every log,
    /// plus an all-time overall adherence rate from the earliest log to today.
    private var allTimeTotals: AllTimeTotals {
        var taken = 0, skipped = 0, snoozed = 0, pending = 0
        for log in logs {
            switch log.status {
            case .taken: taken += 1
            case .skipped: skipped += 1
            case .snoozed: snoozed += 1
            case .pending: pending += 1
            }
        }
        let rate: Double
        if let earliest = logs.map(\.scheduledTime).min() {
            let stat = AdherenceCalculator.overall(
                medicines: medicines, logs: logs,
                from: earliest, to: Date(), calendar: calendar
            )
            rate = stat.rate
        } else {
            rate = 0
        }
        return AllTimeTotals(taken: taken, skipped: skipped, snoozed: snoozed, pending: pending, adherenceRate: rate)
    }
}

// MARK: - View-model value types (file-private to the Analytics module surface)

/// One day's adherence stat, made `Identifiable` for charts.
struct DailyAdherence: Identifiable, Hashable {
    let day: Date
    let stat: AdherenceStat
    var id: Date { day }
    var rate: Double { stat.rate }
}

/// A single medicine's adherence over the analytics window.
struct MedicineAdherenceRow: Identifiable, Hashable {
    let id: UUID
    let name: String
    let colorRaw: String
    let iconName: String
    let stat: AdherenceStat

    var medicineColor: MedicineColor { MedicineColor(rawValue: colorRaw) ?? .default }
    var percentText: String { "\(Int((stat.rate * 100).rounded()))%" }
}

/// All-time aggregate counts shown in the totals grid.
struct AllTimeTotals: Hashable {
    let taken: Int
    let skipped: Int
    let snoozed: Int
    let pending: Int
    let adherenceRate: Double
    var logged: Int { taken + skipped + snoozed }
}

// MARK: - Preview

#if DEBUG
#Preview("Analytics") {
    AnalyticsView()
        .modelContainer(SharedModelContainer.preview())
}
#endif
