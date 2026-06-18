//
//  DoseLiveActivity.swift
//  MedicineReminderWidgets
//
//  The Live Activity for an in-progress dose slot. Renders:
//   • Lock Screen / banner — full layout with per-medicine Take/Skip buttons.
//   • Dynamic Island compact — pill icon (leading) + count and a live timer
//     (trailing).
//   • Dynamic Island minimal — a single progress glyph.
//   • Dynamic Island expanded — title, countdown, and per-medicine rows with
//     Take/Skip App Intent buttons.
//
//  Take/Skip use `TakeDoseIntent` / `SkipDoseIntent` (LiveActivityIntent) so
//  tapping updates the shared store in-process.
//

import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Configuration

struct DoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoseActivityAttributes.self) { context in
            // Lock Screen / banner presentation.
            DoseLiveActivityLockScreenView(
                attributes: context.attributes,
                state: context.state
            )
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [
                        leadColor(context.state).color.opacity(0.20),
                        leadColor(context.state).color.opacity(0.04)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded regions.
                DynamicIslandExpandedRegion(.leading) {
                    expandedLeading(context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    expandedTrailing(context.attributes, context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.title)
                        .font(AppFont.headline)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedMedicineList(
                        attributes: context.attributes,
                        state: context.state
                    )
                }
            } compactLeading: {
                Image(systemName: "pills.fill")
                    .foregroundStyle(leadColor(context.state).color)
                    .accessibilityLabel("Doses")
            } compactTrailing: {
                CompactTrailing(attributes: context.attributes, state: context.state)
            } minimal: {
                MinimalView(state: context.state)
            }
            .widgetURL(URL(string: "medicinereminder://dose/\(context.attributes.eventID)"))
            .keylineTint(leadColor(context.state).color)
        }
    }

    // MARK: Expanded helpers

    @ViewBuilder
    private func expandedLeading(_ state: DoseActivityAttributes.ContentState) -> some View {
        let lead = leadItem(state)
        HStack(spacing: Spacing.sm) {
            PillIcon(systemName: lead?.iconName ?? "pills.fill",
                     color: leadColor(state), size: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text("\(state.takenCount)/\(state.totalCount)")
                    .font(AppFont.headline)
                    .monospacedDigit()
                Text("taken")
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue("\(state.takenCount) of \(state.totalCount) taken")
    }

    @ViewBuilder
    private func expandedTrailing(_ attributes: DoseActivityAttributes,
                                  _ state: DoseActivityAttributes.ContentState) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            if attributes.slotTime > Date() {
                Text(attributes.slotTime, style: .timer)
                    .font(AppFont.title3)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 78, alignment: .trailing)
            } else {
                Text("Due now")
                    .font(AppFont.subheadline)
                    .foregroundStyle(leadColor(state).color)
            }
            Text(attributes.slotTime, style: .time)
                .font(AppFont.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Due")
        .accessibilityValue(attributes.slotTime > Date()
                            ? attributes.slotTime.formatted(.relative(presentation: .named))
                            : "now")
    }

    private func leadItem(_ state: DoseActivityAttributes.ContentState) -> DoseActivityAttributes.ContentState.Item? {
        state.medicines.first { $0.statusRaw == DoseStatus.pending.rawValue } ?? state.medicines.first
    }

    private func leadColor(_ state: DoseActivityAttributes.ContentState) -> MedicineColor {
        MedicineColor(rawValue: leadItem(state)?.colorRaw ?? "") ?? .default
    }
}

// MARK: - Lock Screen view

struct DoseLiveActivityLockScreenView: View {
    let attributes: DoseActivityAttributes
    let state: DoseActivityAttributes.ContentState

    private var pending: [DoseActivityAttributes.ContentState.Item] {
        state.medicines.filter { $0.statusRaw == DoseStatus.pending.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            header
            ForEach(state.medicines.prefix(3)) { item in
                MedicineActionRow(item: item, slotTime: attributes.slotTime, compact: false)
            }
            if state.medicines.count > 3 {
                Text("+\(state.medicines.count - 3) more")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.lg)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(attributes.title)
                    .font(AppFont.headline)
                    .accessibilityAddTraits(.isHeader)
                Text("\(state.takenCount) of \(state.totalCount) taken")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if attributes.slotTime > Date() {
                    Text(attributes.slotTime, style: .timer)
                        .font(AppFont.title3)
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 90, alignment: .trailing)
                } else {
                    Text("Due now")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.primary)
                }
                Text(attributes.slotTime, style: .time)
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Due")
            .accessibilityValue(attributes.slotTime > Date()
                                ? attributes.slotTime.formatted(.relative(presentation: .named))
                                : "now")
        }
    }
}

// MARK: - Expanded medicine list (Dynamic Island bottom)

private struct ExpandedMedicineList: View {
    let attributes: DoseActivityAttributes
    let state: DoseActivityAttributes.ContentState

    var body: some View {
        VStack(spacing: Spacing.sm) {
            ForEach(state.medicines.prefix(2)) { item in
                MedicineActionRow(item: item, slotTime: attributes.slotTime, compact: true)
            }
            if state.medicines.count > 2 {
                Text("+\(state.medicines.count - 2) more in app")
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Per-medicine row with Take/Skip

/// One medicine row showing the pill icon, name + dosage, and Take/Skip App
/// Intent buttons (when pending) or a resolved status chip.
private struct MedicineActionRow: View {
    let item: DoseActivityAttributes.ContentState.Item
    let slotTime: Date
    let compact: Bool

    private var color: MedicineColor { MedicineColor(rawValue: item.colorRaw) ?? .default }
    private var status: DoseStatus { DoseStatus(rawValue: item.statusRaw) ?? .pending }
    private var medicineID: UUID? { UUID(uuidString: item.id) }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            PillIcon(systemName: item.iconName, color: color, size: compact ? 26 : 34)

            VStack(alignment: .leading, spacing: 0) {
                Text(item.name)
                    .font(compact ? AppFont.subheadline : AppFont.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(item.dosage)
                    .font(AppFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            if status == .pending, let medicineID {
                actionButtons(medicineID: medicineID)
            } else {
                statusChip
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(item.name), \(item.dosage)")
    }

    @ViewBuilder
    private func actionButtons(medicineID: UUID) -> some View {
        HStack(spacing: Spacing.sm) {
            Button(intent: SkipDoseIntent(medicineID: medicineID, scheduledTime: slotTime)) {
                Image(systemName: "xmark")
                    .font(.system(size: compact ? 13 : 15, weight: .bold))
                    .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
            }
            .buttonStyle(.plain)
            .tint(.orange)
            .accessibilityLabel("Skip \(item.name)")

            Button(intent: TakeDoseIntent(medicineID: medicineID, scheduledTime: slotTime)) {
                Image(systemName: "checkmark")
                    .font(.system(size: compact ? 13 : 15, weight: .bold))
                    .frame(width: compact ? 30 : 36, height: compact ? 30 : 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .accessibilityLabel("Take \(item.name)")
        }
    }

    private var statusChip: some View {
        Label(status.label, systemImage: status.systemImage)
            .labelStyle(.iconOnly)
            .font(.system(size: compact ? 16 : 20, weight: .semibold))
            .foregroundStyle(status == .taken ? Color.green : (status == .skipped ? Color.orange : color.color))
            .accessibilityLabel("\(item.name) \(status.label)")
    }
}

// MARK: - Dynamic Island compact / minimal helpers

private struct CompactTrailing: View {
    let attributes: DoseActivityAttributes
    let state: DoseActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 2) {
            Text("\(state.takenCount)/\(state.totalCount)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if attributes.slotTime > Date() {
                Text(attributes.slotTime, style: .timer)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .frame(maxWidth: 44)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Doses")
        .accessibilityValue("\(state.takenCount) of \(state.totalCount) taken")
    }
}

private struct MinimalView: View {
    let state: DoseActivityAttributes.ContentState

    private var color: MedicineColor {
        MedicineColor(rawValue: state.medicines.first { $0.statusRaw == DoseStatus.pending.rawValue }?.colorRaw
                      ?? state.medicines.first?.colorRaw ?? "") ?? .default
    }

    var body: some View {
        let allDone = state.takenCount >= state.totalCount && state.totalCount > 0
        Image(systemName: allDone ? "checkmark.circle.fill" : "pills.fill")
            .foregroundStyle(allDone ? Color.green : color.color)
            .accessibilityLabel(allDone ? "All doses taken" : "Doses pending")
            .accessibilityValue("\(state.takenCount) of \(state.totalCount) taken")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Dose Live Activity", as: .content, using: DoseActivityAttributes(
    eventID: ScheduleEngine.slotID(Date().addingTimeInterval(60 * 45)),
    slotTime: Date().addingTimeInterval(60 * 45),
    title: "Evening dose"
)) {
    DoseLiveActivity()
} contentStates: {
    WidgetPreviewData.sampleEvent()
    DoseActivityAttributes.ContentState(
        medicines: [
            .init(id: UUID().uuidString, name: "Metformin", dosage: "500 mg",
                  colorRaw: MedicineColor.emerald.rawValue, iconName: "pills.fill",
                  statusRaw: DoseStatus.taken.rawValue),
            .init(id: UUID().uuidString, name: "Vitamin D3", dosage: "1 capsule",
                  colorRaw: MedicineColor.amber.rawValue, iconName: "sun.max.fill",
                  statusRaw: DoseStatus.taken.rawValue)
        ],
        takenCount: 2,
        totalCount: 2
    )
}
#endif
