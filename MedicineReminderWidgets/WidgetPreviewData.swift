//
//  WidgetPreviewData.swift
//  MedicineReminderWidgets
//
//  DEBUG-only synthetic snapshots for widget and Live Activity previews.
//  Builds value-type `DoseSnapshot`s directly (no SwiftData / async) so
//  Xcode previews render deterministically and offline.
//

#if DEBUG
import Foundation

enum WidgetPreviewData {

    /// A snapshot with a few of today's events and a clear "next" dose.
    static func sampleSnapshot(reference: Date = .now) -> DoseSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: reference)

        func at(_ hour: Int, _ minute: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
        }

        let morning = DoseEventSnapshot(
            id: ScheduleEngine.slotID(at(8, 0)),
            time: at(8, 0),
            items: [
                DoseItemSnapshot(id: UUID(), medicineID: UUID(), name: "Lisinopril",
                                 dosageDescription: "10 mg", colorRaw: MedicineColor.blue.rawValue,
                                 iconName: "heart.fill", statusRaw: DoseStatus.taken.rawValue),
                DoseItemSnapshot(id: UUID(), medicineID: UUID(), name: "Metformin",
                                 dosageDescription: "500 mg", colorRaw: MedicineColor.emerald.rawValue,
                                 iconName: "pills.fill", statusRaw: DoseStatus.taken.rawValue)
            ]
        )

        // Place the "next" event one hour ahead of the reference so the
        // countdown shows a believable remaining time in previews.
        let nextTime = reference.addingTimeInterval(60 * 62)
        let evening = DoseEventSnapshot(
            id: ScheduleEngine.slotID(nextTime),
            time: nextTime,
            items: [
                DoseItemSnapshot(id: UUID(), medicineID: UUID(), name: "Metformin",
                                 dosageDescription: "500 mg", colorRaw: MedicineColor.emerald.rawValue,
                                 iconName: "pills.fill", statusRaw: DoseStatus.pending.rawValue),
                DoseItemSnapshot(id: UUID(), medicineID: UUID(), name: "Vitamin D3",
                                 dosageDescription: "1 capsule", colorRaw: MedicineColor.amber.rawValue,
                                 iconName: "sun.max.fill", statusRaw: DoseStatus.pending.rawValue)
            ]
        )

        return DoseSnapshot(
            date: reference,
            todaysEvents: [morning, evening],
            nextEvent: evening,
            previousSlotTime: morning.time
        )
    }

    /// A snapshot where everything for the day is done.
    static func emptySnapshot(reference: Date = .now) -> DoseSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: reference)
        let morning = DoseEventSnapshot(
            id: ScheduleEngine.slotID(today.addingTimeInterval(8 * 3600)),
            time: today.addingTimeInterval(8 * 3600),
            items: [
                DoseItemSnapshot(id: UUID(), medicineID: UUID(), name: "Lisinopril",
                                 dosageDescription: "10 mg", colorRaw: MedicineColor.blue.rawValue,
                                 iconName: "heart.fill", statusRaw: DoseStatus.taken.rawValue)
            ]
        )
        return DoseSnapshot(date: reference, todaysEvents: [morning], nextEvent: nil, previousSlotTime: nil)
    }

    /// A single grouped event for Live Activity previews.
    static func sampleEvent(reference: Date = .now) -> DoseActivityAttributes.ContentState {
        DoseActivityAttributes.ContentState(
            medicines: [
                .init(id: UUID().uuidString, name: "Metformin", dosage: "500 mg",
                      colorRaw: MedicineColor.emerald.rawValue, iconName: "pills.fill",
                      statusRaw: DoseStatus.pending.rawValue),
                .init(id: UUID().uuidString, name: "Vitamin D3", dosage: "1 capsule",
                      colorRaw: MedicineColor.amber.rawValue, iconName: "sun.max.fill",
                      statusRaw: DoseStatus.taken.rawValue)
            ],
            takenCount: 1,
            totalCount: 2
        )
    }
}
#endif
