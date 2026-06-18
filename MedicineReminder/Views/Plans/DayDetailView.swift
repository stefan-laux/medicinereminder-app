//
//  DayDetailView.swift
//  MedicineReminder
//
//  The lower section of the Plans screen: the dose schedule for the currently
//  selected day. Renders one `DoseEventCard` per slot (reusing the Home
//  card so users can log doses straight from the calendar), plus a small
//  summary of how many doses were taken. Shows a friendly empty state on days
//  with nothing scheduled.
//

import SwiftUI

/// Detail list of a single day's dose events. File-private to the Plans
/// feature. Mutations route through the shared `DoseManager` via `DoseEventCard`.
struct DayDetailView: View {
    let day: Date
    let events: [DoseEvent]
    let manager: DoseManager

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(
                dayTitle,
                subtitle: summary,
                systemImage: "calendar",
                tint: .accentColor
            )

            if events.isEmpty {
                emptyState
            } else {
                ForEach(events) { event in
                    DoseEventCard(event: event, manager: manager)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Empty state

    private var emptyState: some View {
        GlassCard {
            EmptyStateView(
                "Nothing Scheduled",
                systemImage: "calendar.badge.checkmark",
                description: "No doses are planned for \(emptyStateDay). Enjoy the break.",
                tint: MedicineColor.teal.color
            )
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Text

    private var dayTitle: String {
        if Calendar.current.isDateInToday(day) {
            return String(localized: "Today")
        }
        if Calendar.current.isDateInTomorrow(day) {
            return String(localized: "Tomorrow")
        }
        if Calendar.current.isDateInYesterday(day) {
            return String(localized: "Yesterday")
        }
        return day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private var emptyStateDay: String {
        day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    /// "x of y doses taken" summary; nil-safe and pluralized.
    private var summary: String? {
        let total = events.reduce(0) { $0 + $1.items.count }
        guard total > 0 else { return nil }
        let taken = events.reduce(0) { partial, event in
            partial + event.items.filter { $0.status == .taken }.count
        }
        let doseWord = total == 1 ? "dose" : "doses"
        return "\(taken) of \(total) \(doseWord) taken"
    }
}

#if DEBUG
#Preview("Day Detail") {
    let container = SharedModelContainer.preview()
    let manager = DoseManager(context: container.mainContext)

    ScrollView {
        DayDetailView(
            day: Date(),
            events: manager.todaysEvents,
            manager: manager
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}

#Preview("Day Detail — Empty") {
    let container = SharedModelContainer.preview()
    let manager = DoseManager(context: container.mainContext)

    ScrollView {
        DayDetailView(
            day: Date(),
            events: [],
            manager: manager
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}
#endif
