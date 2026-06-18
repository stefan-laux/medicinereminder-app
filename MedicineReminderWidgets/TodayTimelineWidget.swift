//
//  TodayTimelineWidget.swift
//  MedicineReminderWidgets
//
//  systemMedium home-screen widget: a compact horizontal timeline of today's
//  dose slots, distinguishing past (taken/skipped) from upcoming, with a
//  header summarizing remaining doses.
//

import SwiftUI
import WidgetKit

// MARK: - Widget

struct TodayTimelineWidget: Widget {
    static let kind = "TodayTimelineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            TodayTimelineWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Timeline")
        .description("Your day of doses at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - View

struct TodayTimelineWidgetView: View {
    let entry: DoseEntry

    private var events: [DoseEventSnapshot] { entry.snapshot.todaysEvents }

    var body: some View {
        if events.isEmpty {
            EmptyTimelineView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                header
                Divider().opacity(0.4)
                slots
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        let remaining = entry.snapshot.remainingTodayCount
        let scheduled = entry.snapshot.scheduledTodayCount
        let taken = entry.snapshot.takenTodayCount
        return HStack(alignment: .firstTextBaseline) {
            Text("Today")
                .font(AppFont.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text(remaining == 0 ? "All done" : "\(remaining) left")
                .font(AppFont.subheadline)
                .foregroundStyle(remaining == 0 ? MedicineColor.emerald.color : .secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's doses")
        .accessibilityValue("\(taken) of \(scheduled) taken, \(remaining) remaining")
    }

    private var slots: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            ForEach(displayedEvents) { event in
                SlotColumn(event: event, now: entry.date)
            }
            if events.count > maxSlots {
                MoreSlotsColumn(extra: events.count - maxSlots)
            }
            Spacer(minLength: 0)
        }
    }

    private let maxSlots = 4

    private var displayedEvents: [DoseEventSnapshot] {
        // Prefer to show the upcoming slots, but keep at least the current
        // context. Show the window centered on "now".
        let upcoming = events.filter { $0.time >= entry.date }
        if upcoming.count >= maxSlots {
            return Array(upcoming.prefix(maxSlots))
        }
        // Backfill with the most recent past slots so the column isn't sparse.
        let pastNeeded = maxSlots - upcoming.count
        let past = events.filter { $0.time < entry.date }.suffix(pastNeeded)
        return (Array(past) + upcoming).sorted { $0.time < $1.time }
    }
}

// MARK: - Slot column

private struct SlotColumn: View {
    let event: DoseEventSnapshot
    let now: Date

    private var isPast: Bool { event.time < now && event.pendingItems.isEmpty }
    private var isDue: Bool { event.time <= now && !event.pendingItems.isEmpty }
    private var lead: DoseItemSnapshot? { event.pendingItems.first ?? event.items.first }
    private var accent: MedicineColor { lead?.color ?? .default }

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(event.time, style: .time)
                .font(AppFont.caption2)
                .foregroundStyle(isDue ? accent.color : .secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            ZStack {
                Circle()
                    .fill(accent.color.opacity(isPast ? 0.12 : 0.20))
                    .frame(width: 38, height: 38)
                Image(systemName: glyph)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isPast ? Color.secondary : accent.color)
            }
            .overlay {
                if isDue {
                    Circle().strokeBorder(accent.color, lineWidth: 2)
                        .frame(width: 38, height: 38)
                }
            }

            Text(lead?.name ?? "")
                .font(AppFont.caption2)
                .foregroundStyle(isPast ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: 58)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var glyph: String {
        if event.pendingItems.isEmpty {
            // Resolved slot: reflect overall outcome.
            if event.takenCount > 0 { return "checkmark" }
            return "xmark"
        }
        return lead?.iconName ?? "pills.fill"
    }

    private var accessibilityLabel: String {
        let time = event.time.formatted(date: .omitted, time: .shortened)
        let names = event.items.map(\.name).joined(separator: ", ")
        if event.pendingItems.isEmpty {
            return "\(time), \(names), done"
        }
        return "\(time), \(names), \(isDue ? "due now" : "upcoming")"
    }
}

private struct MoreSlotsColumn: View {
    let extra: Int

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Text(" ")
                .font(AppFont.caption2)
            ZStack {
                Circle().fill(Color.secondary.opacity(0.14)).frame(width: 38, height: 38)
                Text("+\(extra)")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
            Text("more")
                .font(AppFont.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(extra) more doses today")
    }
}

// MARK: - Empty state

private struct EmptyTimelineView: View {
    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MedicineColor.teal.color)
                .accessibilityHidden(true)
            Text("Nothing scheduled today")
                .font(AppFont.headline)
                .foregroundStyle(.primary)
            Text("Add a medicine to see your timeline.")
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Today Timeline", as: .systemMedium) {
    TodayTimelineWidget()
} timeline: {
    let snapshot = WidgetPreviewData.sampleSnapshot()
    DoseEntry(date: snapshot.date, snapshot: snapshot)
    DoseEntry(date: .now, snapshot: WidgetPreviewData.emptySnapshot())
}
#endif
