import Foundation
import Observation
import SwiftData

/// The app's primary observable store. Owns the working set of medicines and
/// today's grouped dose events, and centralizes the side effects that must run
/// after a dose mutation: persistence, notification rescheduling, Live Activity
/// updates, and haptics.
@MainActor
@Observable
public final class DoseManager {

    // MARK: Observable state

    public private(set) var medicines: [Medicine] = []
    public private(set) var todaysEvents: [DoseEvent] = []
    public private(set) var currentStreak: Int = 0
    public private(set) var longestStreak: Int = 0

    // MARK: Dependencies

    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private let calendar = Calendar.current

    public init(context: ModelContext) {
        self.context = context
        reload()
    }

    // MARK: Loading

    /// Re-fetch medicines + logs and recompute derived state.
    public func reload() {
        let activeMedicines = fetchMedicines()
        let logs = fetchLogs()

        medicines = activeMedicines
        todaysEvents = ScheduleEngine.events(for: activeMedicines, logs: logs, on: Date(), calendar: calendar)
        currentStreak = StreakCalculator.currentStreak(medicines: activeMedicines, logs: logs, asOf: Date(), calendar: calendar)
        longestStreak = StreakCalculator.longestStreak(medicines: activeMedicines, logs: logs, asOf: Date(), calendar: calendar)
    }

    // MARK: Dose mutations

    public func markTaken(_ item: DoseEventItem, amount: Double?) {
        let previousStreak = currentStreak
        perform {
            try DoseActions.logTaken(
                medicineID: item.medicineID,
                scheduledTime: scheduledTime(for: item),
                amount: amount,
                source: .manual,
                in: context
            )
        }
        // Celebrate a brand-new streak milestone, otherwise a plain success.
        if currentStreak > previousStreak, currentStreak > 0, currentStreak % 7 == 0 {
            HapticEngine.milestone()
        } else {
            HapticEngine.taken()
        }
        refreshSideEffects()
    }

    public func skip(_ item: DoseEventItem) {
        perform {
            try DoseActions.skip(
                medicineID: item.medicineID,
                scheduledTime: scheduledTime(for: item),
                source: .manual,
                in: context
            )
        }
        HapticEngine.skipped()
        refreshSideEffects()
    }

    public func snooze(_ item: DoseEventItem) {
        perform {
            try DoseActions.snooze(
                medicineID: item.medicineID,
                scheduledTime: scheduledTime(for: item),
                minutes: NotificationIDs.snoozeMinutes,
                source: .manual,
                in: context
            )
        }
        HapticEngine.selection()
        refreshSideEffects()
    }

    // MARK: Medicine lifecycle

    public func addMedicine(_ medicine: Medicine) {
        context.insert(medicine)
        save()
        reload()
        HapticEngine.added()
        Task { await NotificationService.shared.rescheduleAll(medicines: medicines) }
    }

    public func update(_ medicine: Medicine) {
        save()
        reload()
        Task { await NotificationService.shared.rescheduleAll(medicines: medicines) }
    }

    public func archive(_ medicine: Medicine) {
        medicine.isArchived = true
        let archivedID = medicine.id
        save()
        reload()
        Task {
            await NotificationService.shared.cancel(for: archivedID)
            await NotificationService.shared.rescheduleAll(medicines: medicines)
        }
    }

    // MARK: Private — fetching

    private func fetchMedicines() -> [Medicine] {
        let descriptor = FetchDescriptor<Medicine>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchLogs() -> [DoseLog] {
        let descriptor = FetchDescriptor<DoseLog>(
            sortBy: [SortDescriptor(\.scheduledTime, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: Private — side effects

    /// Run a throwing mutation then reload derived state. Swallows errors so a
    /// failed mutation never crashes the UI; the next reload reflects reality.
    private func perform(_ mutation: () throws -> Void) {
        do {
            try mutation()
        } catch {
            // Mutation failed (e.g. medicine deleted mid-flight); reload to resync.
        }
        reload()
    }

    private func refreshSideEffects() {
        let events = todaysEvents
        Task {
            await NotificationService.shared.rescheduleAll(medicines: medicines)
            await updateLiveActivity(events: events)
        }
    }

    /// Drive the Live Activity for the currently-relevant dose slot.
    private func updateLiveActivity(events: [DoseEvent]) async {
        // The "current" event is the soonest one today that still has pending items.
        let current = events.first { event in
            event.items.contains { $0.status == .pending || $0.status == .snoozed }
        }
        if let current {
            await LiveActivityService.shared.startOrUpdate(for: current, title: title(for: current))
        }
    }

    private func title(for event: DoseEvent) -> String {
        let hour = calendar.component(.hour, from: event.time)
        switch hour {
        case 5..<12: return String(localized: "Morning dose")
        case 12..<17: return String(localized: "Afternoon dose")
        case 17..<22: return String(localized: "Evening dose")
        default: return String(localized: "Night dose")
        }
    }

    private func scheduledTime(for item: DoseEventItem) -> Date? {
        // Find the slot time of the event this item belongs to.
        for event in todaysEvents where event.items.contains(where: { $0.id == item.id }) {
            return event.time
        }
        return nil
    }

    private func save() {
        do {
            try context.save()
        } catch {
            // Persisting failed; reload will resync visible state on next pass.
        }
    }
}
