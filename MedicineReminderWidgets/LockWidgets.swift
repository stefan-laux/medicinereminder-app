//
//  LockWidgets.swift
//  MedicineReminderWidgets
//
//  Lock-screen / StandBy accessory widgets:
//   • accessoryCircular   — CircularCountdown ring to the next dose.
//   • accessoryInline     — one-line "Next: Metformin in 1h".
//   • accessoryRectangular — next dose name, dosage and relative time.
//
//  Accessory widgets render in a monochrome rendering mode, so we rely on
//  symbols + the system's vibrant tint rather than the medicine accent color.
//

import SwiftUI
import WidgetKit

// MARK: - Circular countdown widget

struct LockCircularWidget: Widget {
    static let kind = "LockCircularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            LockCircularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Next Dose Countdown")
        .description("A ring counting down to your next dose.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct LockCircularView: View {
    let entry: DoseEntry

    var body: some View {
        if let event = entry.snapshot.nextEvent {
            ZStack {
                AccessoryWidgetBackground()
                CircularCountdown(
                    target: event.time,
                    start: countdownStart(for: event),
                    gradient: tintGradient,
                    lineWidth: 6,
                    diameter: 52
                )
            }
            .accessibilityLabel("Next dose")
            .accessibilityValue(relativeValue(for: event.time))
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22, weight: .semibold))
            }
            .accessibilityLabel("All doses done")
        }
    }

    private func countdownStart(for event: DoseEventSnapshot) -> Date {
        entry.snapshot.previousSlotTime ?? event.time.addingTimeInterval(-2 * 3600)
    }

    /// In accessory contexts color is tinted by the system; a neutral gradient
    /// keeps the ring crisp in monochrome rendering.
    private var tintGradient: LinearGradient {
        LinearGradient(colors: [.white, .white.opacity(0.7)], startPoint: .top, endPoint: .bottom)
    }

    private func relativeValue(for time: Date) -> String {
        if time <= entry.date { return "Due now" }
        return "Due " + time.formatted(.relative(presentation: .named))
    }
}

// MARK: - Inline widget

struct LockInlineWidget: Widget {
    static let kind = "LockInlineWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            LockInlineView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Next Dose (Inline)")
        .description("A one-line reminder of your next dose.")
        .supportedFamilies([.accessoryInline])
    }
}

struct LockInlineView: View {
    let entry: DoseEntry

    var body: some View {
        if let event = entry.snapshot.nextEvent, let lead = event.pendingItems.first ?? event.items.first {
            // Inline widgets show one image + text run.
            Label {
                Text("\(lead.name) \(phrase(for: event.time))")
            } icon: {
                Image(systemName: "pills.fill")
            }
            .accessibilityLabel("Next dose: \(lead.name), \(longPhrase(for: event.time))")
        } else {
            Label("All doses done", systemImage: "checkmark.seal.fill")
                .accessibilityLabel("All doses done")
        }
    }

    private func phrase(for time: Date) -> String {
        if time <= entry.date { return "now" }
        return time.formatted(.relative(presentation: .named))
    }

    private func longPhrase(for time: Date) -> String {
        if time <= entry.date { return "due now" }
        return "due " + time.formatted(.relative(presentation: .named))
    }
}

// MARK: - Rectangular widget

struct LockRectangularWidget: Widget {
    static let kind = "LockRectangularWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            LockRectangularView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Next Dose (Rectangular)")
        .description("Your next dose with name, dosage and time.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct LockRectangularView: View {
    let entry: DoseEntry

    var body: some View {
        if let event = entry.snapshot.nextEvent, let lead = event.pendingItems.first ?? event.items.first {
            let extra = max(0, event.pendingItems.count - 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "pills.fill")
                        .font(.caption)
                        .widgetAccentable()
                    Text("Next dose")
                        .font(.caption)
                        .widgetAccentable()
                }
                Text(lead.name)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(detailLine(for: event, lead: lead, extra: extra))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Next dose")
            .accessibilityValue("\(lead.name), \(lead.dosageDescription), \(longPhrase(for: event.time))\(extra > 0 ? ", plus \(extra) more" : "")")
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Label("All caught up", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .widgetAccentable()
                Text(entry.snapshot.takenTodayCount > 0 ? "\(entry.snapshot.takenTodayCount) taken today" : "No doses pending")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private func detailLine(for event: DoseEventSnapshot, lead: DoseItemSnapshot, extra: Int) -> String {
        var line = "\(lead.dosageDescription) · \(longPhrase(for: event.time))"
        if extra > 0 { line += " · +\(extra)" }
        return line
    }

    private func longPhrase(for time: Date) -> String {
        if time <= entry.date { return "due now" }
        return "in " + time.formatted(.relative(presentation: .named))
    }
}

// MARK: - Previews

#if DEBUG
#Preview("Lock Circular", as: .accessoryCircular) {
    LockCircularWidget()
} timeline: {
    DoseEntry(date: .now, snapshot: WidgetPreviewData.sampleSnapshot())
}

#Preview("Lock Inline", as: .accessoryInline) {
    LockInlineWidget()
} timeline: {
    DoseEntry(date: .now, snapshot: WidgetPreviewData.sampleSnapshot())
}

#Preview("Lock Rectangular", as: .accessoryRectangular) {
    LockRectangularWidget()
} timeline: {
    DoseEntry(date: .now, snapshot: WidgetPreviewData.sampleSnapshot())
    DoseEntry(date: .now, snapshot: WidgetPreviewData.emptySnapshot())
}
#endif
