//
//  MedicineRow.swift
//  MedicineReminder
//
//  A medicine list row: pill icon, name (SF Pro Rounded), dosage description,
//  a color chip, and a "Custom" tag badge for user-created (non-FDA) medicines.
//  Used by the medicine list in Settings / Plans and anywhere a medicine is
//  shown as a list item.
//

import SwiftUI

/// A single medicine list row. Renders the medicine's icon, name, dosage and
/// color, plus a "Custom" badge when the medicine has no FDA match.
///
/// ```swift
/// MedicineRow(medicine: medicine)
/// MedicineRow(medicine: medicine, showsChevron: true)
/// ```
public struct MedicineRow: View {
    private let medicine: Medicine
    private let showsChevron: Bool

    /// - Parameters:
    ///   - medicine: The medicine to display.
    ///   - showsChevron: When `true`, draws a trailing disclosure chevron
    ///     (use inside `NavigationLink`-free tap rows). Defaults to `false`.
    public init(medicine: Medicine, showsChevron: Bool = false) {
        self.medicine = medicine
        self.showsChevron = showsChevron
    }

    public var body: some View {
        HStack(spacing: Spacing.md) {
            PillIcon(systemName: medicine.iconName, color: medicine.color)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xs) {
                    Text(medicine.name)
                        .font(AppFont.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if medicine.isCustom {
                        TagBadge("Custom")
                    }
                }

                Text(medicine.dosageDescription)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            ColorChip(color: medicine.color, isSelected: false, size: 18)
                .accessibilityHidden(true)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Spacing.xs)
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(medicine.dosageDescription)
    }

    private var accessibilityLabel: String {
        medicine.isCustom ? "\(medicine.name), custom medicine" : medicine.name
    }
}

#if DEBUG
import SwiftData

#Preview("Medicine Rows") {
    let container = SharedModelContainer.preview()
    let medicines = (try? container.mainContext.fetch(FetchDescriptor<Medicine>())) ?? []

    return List {
        ForEach(medicines) { medicine in
            MedicineRow(medicine: medicine, showsChevron: true)
        }
    }
    .modelContainer(container)
}
#endif
