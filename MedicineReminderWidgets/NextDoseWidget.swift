//
//  NextDoseWidget.swift
//  MedicineReminderWidgets
//
//  systemSmall home-screen widget: shows the next pending dose — its time,
//  the medicine name(s), and the accent color. Falls back to an "all done"
//  state when nothing is pending.
//

import SwiftUI
import WidgetKit

// MARK: - Widget

struct NextDoseWidget: Widget {
    static let kind = "NextDoseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: DoseTimelineProvider()) { entry in
            NextDoseWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    NextDoseBackground(entry: entry)
                }
        }
        .configurationDisplayName("Next Dose")
        .description("See your next medicine and when it's due.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - View

struct NextDoseWidgetView: View {
    let entry: DoseEntry

    private var event: DoseEventSnapshot? { entry.snapshot.nextEvent }

    var body: some View {
        if let event {
            content(for: event)
        } else {
            AllDoneSmallView(takenCount: entry.snapshot.takenTodayCount)
        }
    }

    @ViewBuilder
    private func content(for event: DoseEventSnapshot) -> some View {
        let lead = event.pendingItems.first ?? event.items.first
        let accent = lead?.color ?? .default
        let extraCount = max(0, event.pendingItems.count - 1)

        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                PillIcon(systemName: lead?.iconName ?? "pills.fill", color: accent, size: 36)
                Spacer(minLength: 0)
                Text(event.time, style: .time)
                    .font(AppFont.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(relativeLabel(for: event.time))
                    .font(AppFont.caption)
                    .foregroundStyle(accent.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(lead?.name ?? "Dose")
                    .font(AppFont.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)

                if let lead {
                    Text(extraCount > 0 ? "\(lead.dosageDescription) +\(extraCount) more" : lead.dosageDescription)
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Next dose")
        .accessibilityValue(accessibilityValue(for: event, lead: lead, extraCount: extraCount))
    }

    private func relativeLabel(for time: Date) -> String {
        if time <= entry.date { return "Due now" }
        return "Due " + time.formatted(.relative(presentation: .named))
    }

    private func accessibilityValue(for event: DoseEventSnapshot, lead: DoseItemSnapshot?, extraCount: Int) -> String {
        guard let lead else { return "No dose scheduled" }
        let timePhrase = event.time <= entry.date
            ? "due now"
            : "due " + event.time.formatted(.relative(presentation: .named))
        var value = "\(lead.name), \(lead.dosageDescription), \(timePhrase)"
        if extraCount > 0 { value += ", plus \(extraCount) more" }
        return value
    }
}

// MARK: - All done

struct AllDoneSmallView: View {
    let takenCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(MedicineColor.emerald.color)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            Text("All caught up")
                .font(AppFont.headline)
                .foregroundStyle(.primary)
            Text(takenCount > 0 ? "\(takenCount) taken today" : "No doses pending")
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("All caught up")
        .accessibilityValue(takenCount > 0 ? "\(takenCount) doses taken today" : "No doses pending")
    }
}

// MARK: - Background

/// Subtle accent-tinted background that adapts to the next dose's color and to
/// dark/light mode. Uses no hard-coded white/black.
struct NextDoseBackground: View {
    let entry: DoseEntry

    private var accent: MedicineColor {
        entry.snapshot.nextEvent?.pendingItems.first?.color
            ?? entry.snapshot.nextEvent?.items.first?.color
            ?? .emerald
    }

    var body: some View {
        LinearGradient(
            colors: [accent.color.opacity(0.22), accent.color.opacity(0.06)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Next Dose", as: .systemSmall) {
    NextDoseWidget()
} timeline: {
    let snapshot = WidgetPreviewData.sampleSnapshot()
    DoseEntry(date: snapshot.date, snapshot: snapshot)
    DoseEntry(date: .now, snapshot: WidgetPreviewData.emptySnapshot())
}
#endif
