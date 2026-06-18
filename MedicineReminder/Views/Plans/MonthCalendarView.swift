//
//  MonthCalendarView.swift
//  MedicineReminder
//
//  A month calendar grid for the Plans screen. Renders a weekday header and a
//  6-row grid of day cells; each in-month cell shows its date number and a row
//  of dose-marker dots colored by the medicines due that day. Tapping a day
//  selects it (revealing its detail below in `PlansView`); chevrons page
//  between months. Wrapped in Liquid Glass via the DesignSystem.
//

import SwiftUI

/// Month calendar grid with per-day dose markers. File-private to the Plans
/// feature; driven by bindings from `PlansView`.
struct MonthCalendarView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var visibleMonth: Date
    @Binding var selectedDay: Date
    let plan: PlanData
    let calendar: Calendar

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        GlassCard(padding: Spacing.md) {
            VStack(spacing: Spacing.md) {
                header
                weekdayHeader
                grid
            }
        }
    }

    // MARK: Month header + paging

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                step(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous month")

            Spacer(minLength: Spacing.sm)

            Text(monthTitle)
                .font(AppFont.title3)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Spacing.sm)

            Button {
                step(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next month")
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(orderedWeekdaySymbols.indices, id: \.self) { index in
                Text(orderedWeekdaySymbols[index])
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(gridDays, id: \.self) { day in
                CalendarDayCell(
                    day: day,
                    isInMonth: calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month),
                    isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                    isToday: calendar.isDateInToday(day),
                    markers: plan.markers(for: day),
                    calendar: calendar
                ) {
                    select(day)
                }
            }
        }
    }

    // MARK: Data

    /// The 42 days (6 weeks) covering the visible month, including leading and
    /// trailing days from adjacent months to fill the grid.
    private var gridDays: [Date] {
        let monthStart = PlanCalendar.startOfMonth(for: visibleMonth, calendar: calendar)
        let start = PlanCalendar.startOfWeek(for: monthStart, calendar: calendar)
        return (0..<42).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    /// Weekday symbols rotated to begin at the calendar's `firstWeekday`.
    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    private var monthTitle: String {
        visibleMonth.formatted(.dateTime.month(.wide).year())
    }

    // MARK: Actions

    private func select(_ day: Date) {
        HapticEngine.selection()
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            selectedDay = calendar.startOfDay(for: day)
            // Follow the user into an adjacent month if they tapped a spill-over day.
            if !calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month) {
                visibleMonth = PlanCalendar.startOfMonth(for: day, calendar: calendar)
            }
        }
    }

    private func step(by months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: visibleMonth) else { return }
        HapticEngine.selection()
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.3)) {
            visibleMonth = PlanCalendar.startOfMonth(for: next, calendar: calendar)
        }
    }
}

#if DEBUG
#Preview("Month Calendar") {
    let container = SharedModelContainer.preview()
    let manager = DoseManager(context: container.mainContext)
    let calendar = Calendar.current
    let monthStart = PlanCalendar.startOfMonth(for: Date(), calendar: calendar)
    let gridStart = PlanCalendar.startOfWeek(for: monthStart, calendar: calendar)
    let range = gridStart...(calendar.date(byAdding: .day, value: 41, to: gridStart) ?? monthStart)

    return MonthCalendarPreviewHost(
        manager: manager,
        plan: PlanData(medicines: manager.medicines, logs: [], range: range, calendar: calendar),
        calendar: calendar
    )
    .padding()
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}

/// Hosts the calendar with mutable bindings for the interactive preview.
private struct MonthCalendarPreviewHost: View {
    let manager: DoseManager
    let plan: PlanData
    let calendar: Calendar

    @State private var month = PlanCalendar.startOfMonth(for: Date(), calendar: .current)
    @State private var selected = Calendar.current.startOfDay(for: Date())

    var body: some View {
        MonthCalendarView(
            visibleMonth: $month,
            selectedDay: $selected,
            plan: plan,
            calendar: calendar
        )
    }
}
#endif
