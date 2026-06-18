//
//  AllTimeTotalsSection.swift
//  MedicineReminder — Analytics
//
//  All-time totals: a donut breakdown (Swift Charts `SectorMark`) of logged
//  doses by outcome, an overall adherence percentage, and a grid of the raw
//  taken / skipped / snoozed / pending counts. The donut and each stat tile
//  carry accessibility labels and values.
//

import SwiftUI
import Charts

/// Displays lifetime dose outcome totals and an overall adherence rate.
struct AllTimeTotalsSection: View {
    let totals: AllTimeTotals

    private var slices: [OutcomeSlice] {
        [
            OutcomeSlice(outcome: .taken, count: totals.taken, color: MedicineColor.emerald.color),
            OutcomeSlice(outcome: .skipped, count: totals.skipped, color: MedicineColor.coral.color),
            OutcomeSlice(outcome: .snoozed, count: totals.snoozed, color: MedicineColor.amber.color)
        ].filter { $0.count > 0 }
    }

    private var adherenceText: String {
        "\(Int((totals.adherenceRate * 100).rounded()))%"
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                SectionHeader(
                    "All time",
                    systemImage: "sum",
                    tint: MedicineColor.violet.color
                )

                if totals.logged == 0 {
                    Text("No doses logged yet.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    donut
                }

                statGrid
            }
        }
    }

    // MARK: - Donut

    private var donut: some View {
        HStack(spacing: Spacing.xl) {
            ZStack {
                Chart(slices) { slice in
                    SectorMark(
                        angle: .value("Count", slice.count),
                        innerRadius: .ratio(0.62),
                        angularInset: 1.5
                    )
                    .cornerRadius(Radius.sm)
                    .foregroundStyle(slice.color)
                    .accessibilityLabel(slice.outcome.label)
                    .accessibilityValue("\(slice.count) doses")
                }
                .frame(width: 130, height: 130)
                .accessibilityLabel("Dose outcomes")
                .accessibilityValue(donutAccessibilityValue)

                VStack(spacing: 0) {
                    Text(adherenceText)
                        .font(AppFont.title2)
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text("adherence")
                        .font(AppFont.caption2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Overall adherence")
                .accessibilityValue(adherenceText)
            }

            legend
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(slices) { slice in
                HStack(spacing: Spacing.sm) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 10, height: 10)
                        .accessibilityHidden(true)
                    Text(slice.outcome.label)
                        .font(AppFont.subheadline)
                    Spacer(minLength: Spacing.sm)
                    Text("\(slice.count)")
                        .font(AppFont.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(slice.outcome.label)
                .accessibilityValue("\(slice.count) doses")
            }
        }
    }

    private var donutAccessibilityValue: Text {
        Text("\(totals.taken) taken, \(totals.skipped) skipped, \(totals.snoozed) snoozed")
    }

    // MARK: - Stat grid

    private var statGrid: some View {
        let items: [StatTileModel] = [
            StatTileModel(title: "Taken", value: totals.taken, systemImage: DoseStatus.taken.systemImage, color: MedicineColor.emerald.color),
            StatTileModel(title: "Skipped", value: totals.skipped, systemImage: DoseStatus.skipped.systemImage, color: MedicineColor.coral.color),
            StatTileModel(title: "Snoozed", value: totals.snoozed, systemImage: DoseStatus.snoozed.systemImage, color: MedicineColor.amber.color),
            StatTileModel(title: "Pending", value: totals.pending, systemImage: DoseStatus.pending.systemImage, color: MedicineColor.slate.color)
        ]
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: Spacing.md), GridItem(.flexible(), spacing: Spacing.md)],
            spacing: Spacing.md
        ) {
            ForEach(items) { item in
                StatTile(model: item)
            }
        }
    }
}

// MARK: - Stat tile

private struct StatTileModel: Identifiable {
    let title: String
    let value: Int
    let systemImage: String
    let color: Color
    var id: String { title }
}

private struct StatTile: View {
    let model: StatTileModel

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: model.systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(model.color)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(model.value)")
                    .font(AppFont.title3)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(model.title)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(model.color.opacity(0.10), in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.title)
        .accessibilityValue("\(model.value)")
    }
}

// MARK: - Slice model

private struct OutcomeSlice: Identifiable {
    let outcome: DoseStatus
    let count: Int
    let color: Color
    var id: String { outcome.rawValue }
}

// MARK: - Preview

#if DEBUG
#Preview("AllTimeTotalsSection") {
    AllTimeTotalsSection(
        totals: AllTimeTotals(taken: 182, skipped: 14, snoozed: 9, pending: 5, adherenceRate: 0.89)
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
#endif
