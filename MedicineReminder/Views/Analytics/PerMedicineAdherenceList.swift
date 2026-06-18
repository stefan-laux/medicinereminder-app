//
//  PerMedicineAdherenceList.swift
//  MedicineReminder — Analytics
//
//  A per-medicine adherence breakdown over the analytics window. Each row
//  shows the medicine's pill icon, name, taken/scheduled count, a mini
//  capsule progress bar tinted by the medicine's color, and its percentage.
//  Every row is a single accessibility element with a meaningful value.
//

import SwiftUI

/// Lists each medicine's adherence as a tinted mini bar + percentage.
struct PerMedicineAdherenceList: View {
    let rows: [MedicineAdherenceRow]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader(
                    "By medicine",
                    subtitle: rows.isEmpty ? nil : "Last 30 days",
                    systemImage: "list.bullet.rectangle.fill",
                    tint: MedicineColor.indigo.color
                )

                if rows.isEmpty {
                    Text("No scheduled doses to measure yet.")
                        .font(AppFont.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, Spacing.sm)
                } else {
                    VStack(spacing: Spacing.md) {
                        ForEach(rows) { row in
                            MedicineAdherenceRowView(row: row)
                            if row.id != rows.last?.id {
                                Divider().opacity(0.4)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Row

private struct MedicineAdherenceRowView: View {
    let row: MedicineAdherenceRow

    var body: some View {
        HStack(spacing: Spacing.md) {
            PillIcon(systemName: row.iconName, color: row.medicineColor, size: 38)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(row.name)
                        .font(AppFont.headline)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.sm)
                    Text(row.percentText)
                        .font(AppFont.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(row.medicineColor.color)
                }

                MiniBar(rate: row.stat.rate, color: row.medicineColor)
                    .accessibilityHidden(true)

                Text("\(row.stat.taken) of \(row.stat.scheduled) doses taken")
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Spacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.name)
        .accessibilityValue("\(row.percentText) adherence, \(row.stat.taken) of \(row.stat.scheduled) doses taken")
    }
}

// MARK: - Mini capsule bar

/// A thin rounded progress bar whose fill width tracks `rate` (0...1).
private struct MiniBar: View {
    let rate: Double
    let color: MedicineColor

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let clamped = min(max(rate, 0), 1)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.10))
                Capsule(style: .continuous)
                    .fill(color.gradient)
                    .frame(width: max(0, proxy.size.width * clamped))
                    .animation(reduceMotion ? nil : .smooth(duration: 0.5), value: clamped)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("PerMedicineAdherenceList") {
    let rows = [
        MedicineAdherenceRow(id: UUID(), name: "Lisinopril", colorRaw: MedicineColor.blue.rawValue,
                             iconName: "heart.fill", stat: AdherenceStat(taken: 28, scheduled: 30)),
        MedicineAdherenceRow(id: UUID(), name: "Metformin", colorRaw: MedicineColor.emerald.rawValue,
                             iconName: "pills.fill", stat: AdherenceStat(taken: 48, scheduled: 60)),
        MedicineAdherenceRow(id: UUID(), name: "Vitamin D3", colorRaw: MedicineColor.amber.rawValue,
                             iconName: "sun.max.fill", stat: AdherenceStat(taken: 6, scheduled: 13))
    ]
    return PerMedicineAdherenceList(rows: rows)
        .padding()
        .background(Color(.systemGroupedBackground))
}
#endif
