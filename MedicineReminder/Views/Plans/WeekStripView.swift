//
//  WeekStripView.swift
//  MedicineReminder
//
//  A compact horizontal strip showing the seven days of the week containing
//  the selected day. Each day shows its weekday initial, its date number, and
//  a small dose-marker dot row. Tapping a day selects it; chevrons step a week
//  at a time. Used at the top of `PlansView` for fast day switching.
//

import SwiftUI

/// Weekly day selector for the Plans screen. File-private to the Plans feature.
struct WeekStripView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selectedDay: Date
    let plan: PlanData
    let calendar: Calendar

    var body: some View {
        GlassCard(padding: Spacing.md) {
            VStack(spacing: Spacing.md) {
                header
                days
            }
        }
    }

    // MARK: Header (week range + paging)

    private var header: some View {
        HStack(spacing: Spacing.sm) {
            Button {
                step(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous week")

            Spacer(minLength: Spacing.sm)

            Text(weekRangeTitle)
                .font(AppFont.subheadline)
                .foregroundStyle(.primary)
                .accessibilityLabel("Week of \(weekRangeAccessibility)")

            Spacer(minLength: Spacing.sm)

            Button {
                step(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next week")
        }
    }

    // MARK: Day cells

    private var days: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(weekDays, id: \.self) { day in
                dayButton(for: day)
            }
        }
    }

    private func dayButton(for day: Date) -> some View {
        let markers = plan.markers(for: day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDay)
        let isToday = calendar.isDateInToday(day)

        return Button {
            select(day)
        } label: {
            VStack(spacing: Spacing.xs) {
                Text(weekdayInitial(for: day))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(dayNumber(for: day))
                    .font(.system(size: 17, weight: isSelected ? .bold : .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(numberColor(isSelected: isSelected, isToday: isToday))
                    .frame(width: 34, height: 34)
                    .background(numberBackground(isSelected: isSelected, isToday: isToday))

                MarkerDots(colors: markers.colors, maxDots: 3)
                    .frame(height: 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.xs)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(for: day, markers: markers, isToday: isToday))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Styling helpers

    private func numberColor(isSelected: Bool, isToday: Bool) -> Color {
        if isSelected { return .white }
        if isToday { return .accentColor }
        return .primary
    }

    @ViewBuilder
    private func numberBackground(isSelected: Bool, isToday: Bool) -> some View {
        if isSelected {
            Circle().fill(Color.accentColor)
        } else if isToday {
            Circle().strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1.5)
        }
    }

    // MARK: Data

    private var weekDays: [Date] {
        let start = PlanCalendar.startOfWeek(for: selectedDay, calendar: calendar)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func weekdayInitial(for day: Date) -> String {
        let index = calendar.component(.weekday, from: day) - 1
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    private func dayNumber(for day: Date) -> String {
        String(calendar.component(.day, from: day))
    }

    private var weekRangeTitle: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let start = first.formatted(.dateTime.month(.abbreviated).day())
        // If the week spans two months show both, else just the end day number.
        if calendar.isDate(first, equalTo: last, toGranularity: .month) {
            let endDay = last.formatted(.dateTime.day())
            return "\(start) – \(endDay)"
        }
        let end = last.formatted(.dateTime.month(.abbreviated).day())
        return "\(start) – \(end)"
    }

    private var weekRangeAccessibility: String {
        guard let first = weekDays.first, let last = weekDays.last else { return "" }
        let start = first.formatted(.dateTime.month(.wide).day())
        let end = last.formatted(.dateTime.month(.wide).day())
        return "\(start) to \(end)"
    }

    private func accessibilityLabel(for day: Date, markers: DayMarkers, isToday: Bool) -> String {
        let dayText = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let prefix = isToday ? "Today, \(dayText)" : dayText
        if markers.hasDoses {
            let doseWord = markers.total == 1 ? "dose" : "doses"
            return "\(prefix), \(markers.total) \(doseWord), \(markers.taken) taken"
        }
        return "\(prefix), no doses"
    }

    // MARK: Actions

    private func select(_ day: Date) {
        HapticEngine.selection()
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            selectedDay = calendar.startOfDay(for: day)
        }
    }

    private func step(by weeks: Int) {
        guard let next = calendar.date(byAdding: .weekOfYear, value: weeks, to: selectedDay) else { return }
        HapticEngine.selection()
        withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
            selectedDay = calendar.startOfDay(for: next)
        }
    }
}

#if DEBUG
#Preview("Week Strip") {
    let container = SharedModelContainer.preview()
    let manager = DoseManager(context: container.mainContext)
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let range = (calendar.date(byAdding: .day, value: -7, to: today) ?? today)
        ...(calendar.date(byAdding: .day, value: 7, to: today) ?? today)

    return StatefulPreviewWrapper(today) { selection in
        WeekStripView(
            selectedDay: selection,
            plan: PlanData(medicines: manager.medicines, logs: [], range: range, calendar: calendar),
            calendar: calendar
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}

/// Minimal binding host so interactive previews can mutate `@State`.
private struct StatefulPreviewWrapper<Value, Content: View>: View {
    @State private var value: Value
    private let content: (Binding<Value>) -> Content

    init(_ initial: Value, @ViewBuilder content: @escaping (Binding<Value>) -> Content) {
        _value = State(initialValue: initial)
        self.content = content
    }

    var body: some View { content($value) }
}
#endif
