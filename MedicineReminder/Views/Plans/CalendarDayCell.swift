//
//  CalendarDayCell.swift
//  MedicineReminder
//
//  A single day cell within the month calendar grid: the date number, a
//  selection / today indicator, and a row of dose-marker dots. Carries a full
//  accessibility label combining the date and that day's dose count so the
//  grid is navigable by VoiceOver. File-private to the Plans feature.
//

import SwiftUI

/// One day in the month grid. Decorative dots are hidden from accessibility;
/// the cell itself exposes a combined date + dose-count label.
struct CalendarDayCell: View {
    let day: Date
    let isInMonth: Bool
    let isSelected: Bool
    let isToday: Bool
    let markers: DayMarkers
    let calendar: Calendar
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(dayNumber)
                    .font(.system(size: 16, weight: numberWeight, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(numberColor)
                    .frame(width: 32, height: 32)
                    .background(numberBackground)

                MarkerDots(colors: markers.colors, maxDots: 4)
                    .frame(height: 6)
                    .opacity(isInMonth ? 1 : 0.4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(accessibilityTraits)
    }

    // MARK: Styling

    private var dayNumber: String {
        String(calendar.component(.day, from: day))
    }

    private var numberWeight: Font.Weight {
        isSelected ? .bold : (isToday ? .semibold : .regular)
    }

    private var numberColor: Color {
        if isSelected { return .white }
        if !isInMonth { return .secondary.opacity(0.55) }
        if isToday { return .accentColor }
        return .primary
    }

    @ViewBuilder
    private var numberBackground: some View {
        if isSelected {
            Circle().fill(Color.accentColor)
        } else if isToday {
            Circle().strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1.5)
        }
    }

    // MARK: Accessibility

    private var accessibilityLabel: String {
        let dateText = day.formatted(.dateTime.weekday(.wide).month(.wide).day())
        return isToday ? "Today, \(dateText)" : dateText
    }

    private var accessibilityValue: String {
        guard markers.hasDoses else { return "No doses scheduled" }
        let doseWord = markers.total == 1 ? "dose" : "doses"
        return "\(markers.total) \(doseWord) scheduled, \(markers.taken) taken"
    }

    private var accessibilityTraits: AccessibilityTraits {
        isSelected ? [.isButton, .isSelected] : .isButton
    }
}

#if DEBUG
#Preview("Calendar Day Cell") {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    HStack(spacing: Spacing.md) {
        CalendarDayCell(
            day: today,
            isInMonth: true,
            isSelected: true,
            isToday: true,
            markers: DayMarkers(colors: [.blue, .emerald], total: 3, taken: 2),
            calendar: calendar
        ) {}

        CalendarDayCell(
            day: today,
            isInMonth: true,
            isSelected: false,
            isToday: false,
            markers: DayMarkers(colors: [.amber, .coral, .violet, .teal, .rose], total: 6, taken: 1),
            calendar: calendar
        ) {}

        CalendarDayCell(
            day: today,
            isInMonth: false,
            isSelected: false,
            isToday: false,
            markers: .empty,
            calendar: calendar
        ) {}
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
#endif
