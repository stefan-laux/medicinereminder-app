//
//  PlansView.swift
//  MedicineReminder
//
//  Weekly + monthly plan overview. A horizontally-paged month calendar grid
//  shows per-day dose markers (small dots colored by the medicines due that
//  day); a weekly strip across the top gives quick day selection for the
//  visible week. Tapping any day reveals that day's `DoseEvent`s rendered with
//  the shared `DoseEventCard`, so users can review — and log — past, present,
//  and upcoming doses from one place.
//
//  All schedule expansion goes through `ScheduleEngine.events(...,from:,to:)`
//  so slot identities match the rest of the app. Liquid Glass styling comes
//  exclusively from the DesignSystem wrappers.
//

import SwiftData
import SwiftUI

/// The Plans tab: a month calendar with dose markers, a weekly strip, and a
/// tap-to-reveal day detail. Reads the shared ``DoseManager`` for the active
/// medicines and queries ``DoseLog`` directly so it can render adherence
/// markers across the whole visible range (not just today).
public struct PlansView: View {

    @Environment(DoseManager.self) private var manager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// All logged doses, used to resolve each day's per-slot status.
    @Query(sort: \DoseLog.scheduledTime, order: .reverse) private var logs: [DoseLog]

    /// The day the user has tapped to inspect. Defaults to today.
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())

    /// The first day of the month currently shown in the calendar grid.
    @State private var visibleMonth: Date = PlanCalendar.startOfMonth(for: Date(), calendar: .current)

    private let calendar = Calendar.current

    public init() {}

    public var body: some View {
        // Compute the marker buckets once per render and share across sections.
        let plan = self.plan

        return NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    WeekStripView(
                        selectedDay: $selectedDay,
                        plan: plan,
                        calendar: calendar
                    )

                    MonthCalendarView(
                        visibleMonth: $visibleMonth,
                        selectedDay: $selectedDay,
                        plan: plan,
                        calendar: calendar
                    )

                    DayDetailView(
                        day: selectedDay,
                        events: events(on: selectedDay),
                        manager: manager
                    )
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxl)
            }
            .scrollIndicators(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plans")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        goToToday()
                    } label: {
                        Text("Today")
                            .font(AppFont.subheadline)
                    }
                    .disabled(isShowingToday)
                    .accessibilityLabel("Go to today")
                }
            }
        }
    }

    // MARK: - Derived plan data

    /// A precomputed bucket of dose markers per calendar day for the days that
    /// can currently be on screen (the visible month plus the visible week).
    /// Computing once and bucketing avoids re-expanding schedules per cell.
    private var plan: PlanData {
        PlanData(
            medicines: manager.medicines,
            logs: logs,
            range: planRange,
            calendar: calendar
        )
    }

    /// Inclusive day range covering the visible month grid (6 weeks) and the
    /// week strip around the selected day, so every visible cell has markers.
    private var planRange: ClosedRange<Date> {
        let gridStart = PlanCalendar.startOfWeek(for: visibleMonth, calendar: calendar)
        let monthEnd = PlanCalendar.endOfMonth(for: visibleMonth, calendar: calendar)
        let gridEnd = calendar.date(byAdding: .day, value: 41, to: gridStart) ?? monthEnd

        let weekStart = PlanCalendar.startOfWeek(for: selectedDay, calendar: calendar)
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? selectedDay

        let lower = min(gridStart, weekStart)
        let upper = max(gridEnd, weekEnd)
        return lower...upper
    }

    /// Resolve the dose events for a single day from the active medicines.
    private func events(on day: Date) -> [DoseEvent] {
        ScheduleEngine.events(for: manager.medicines, logs: logs, on: day, calendar: calendar)
    }

    // MARK: - Actions

    private var isShowingToday: Bool {
        let today = calendar.startOfDay(for: Date())
        return calendar.isDate(selectedDay, inSameDayAs: today)
            && calendar.isDate(visibleMonth, equalTo: today, toGranularity: .month)
    }

    private func goToToday() {
        let today = calendar.startOfDay(for: Date())
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
            selectedDay = today
            visibleMonth = PlanCalendar.startOfMonth(for: today, calendar: calendar)
        }
    }
}

// MARK: - Plan data model

/// Per-day aggregated dose markers used by the calendar cells and week strip.
/// Pure value type computed off the main schedule engine. File-private to the
/// Plans feature.
struct PlanData {
    /// Markers keyed by `startOfDay`.
    private let byDay: [Date: DayMarkers]
    private let calendar: Calendar

    init(medicines: [Medicine], logs: [DoseLog], range: ClosedRange<Date>, calendar: Calendar) {
        self.calendar = calendar

        let events = ScheduleEngine.events(
            for: medicines,
            logs: logs,
            from: range.lowerBound,
            to: range.upperBound,
            calendar: calendar
        )

        var buckets: [Date: DayMarkers.Builder] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.time)
            var builder = buckets[day] ?? DayMarkers.Builder()
            for item in event.items {
                builder.add(item)
            }
            buckets[day] = builder
        }

        self.byDay = buckets.mapValues { $0.build() }
    }

    /// Markers for the given day (empty when nothing is scheduled).
    func markers(for day: Date) -> DayMarkers {
        byDay[calendar.startOfDay(for: day)] ?? .empty
    }
}

/// Aggregated dose information for a single day: the distinct medicine colors
/// (for dot rendering), the total dose count, and how many were taken — enough
/// to drive both the dots and an accessible summary.
struct DayMarkers: Equatable {
    /// Distinct medicine colors due that day, in first-seen order, capped for layout.
    let colors: [MedicineColor]
    /// Total scheduled doses that day.
    let total: Int
    /// Doses marked taken that day.
    let taken: Int

    static let empty = DayMarkers(colors: [], total: 0, taken: 0)

    var hasDoses: Bool { total > 0 }

    /// Accumulates items as a day's events are scanned, preserving color order
    /// and de-duplicating colors for the dot row.
    struct Builder {
        private var seenColors: [MedicineColor] = []
        private var colorSet: Set<MedicineColor> = []
        private var total = 0
        private var taken = 0

        mutating func add(_ item: DoseEventItem) {
            total += 1
            if item.status == .taken { taken += 1 }
            if let color = MedicineColor(rawValue: item.colorRaw), !colorSet.contains(color) {
                colorSet.insert(color)
                seenColors.append(color)
            }
        }

        func build() -> DayMarkers {
            DayMarkers(colors: seenColors, total: total, taken: taken)
        }
    }
}

// MARK: - Calendar helpers

/// Calendar math used across the Plans feature. Namespaced (rather than an
/// `extension Calendar`) so it never collides with helpers another feature
/// might add to `Calendar`.
enum PlanCalendar {
    /// First moment of the month containing `date`.
    static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    /// Last day (start-of-day) of the month containing `date`.
    static func endOfMonth(for date: Date, calendar: Calendar) -> Date {
        let start = startOfMonth(for: date, calendar: calendar)
        guard let next = calendar.date(byAdding: .month, value: 1, to: start),
              let last = calendar.date(byAdding: .day, value: -1, to: next) else {
            return start
        }
        return calendar.startOfDay(for: last)
    }

    /// Start-of-day for the first weekday of the week containing `date`,
    /// honoring the calendar's `firstWeekday`.
    static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }
}

#if DEBUG
#Preview("Plans") {
    let container = SharedModelContainer.preview()
    PlansView()
        .modelContainer(container)
        .environment(DoseManager(context: container.mainContext))
}
#endif
