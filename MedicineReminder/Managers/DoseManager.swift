import Foundation
import Observation
import SwiftData
import WidgetKit

/// The app's primary observable store. Owns the working set of medicines and
/// today's grouped dose events, and centralizes the side effects that run after
/// a dose mutation: persistence, widget refresh, Live Activity reconciliation,
/// and haptics.
///
/// Notifications are intentionally not used — reminders surface only via the
/// Live Activity (see ``LiveActivityService``).
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

    /// Re-fetch medicines + logs, recompute derived state, and refresh the
    /// widgets + Live Activity.
    public func reload() {
        let activeMedicines = fetchMedicines()
        let logs = fetchLogs()

        medicines = activeMedicines
        todaysEvents = ScheduleEngine.events(for: activeMedicines, logs: logs, on: Date(), calendar: calendar)
        currentStreak = StreakCalculator.currentStreak(medicines: activeMedicines, logs: logs, asOf: Date(), calendar: calendar)
        longestStreak = StreakCalculator.longestStreak(medicines: activeMedicines, logs: logs, asOf: Date(), calendar: calendar)

        syncExternal()
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
        if currentStreak > previousStreak, currentStreak > 0, currentStreak % 7 == 0 {
            HapticEngine.milestone()
        } else {
            HapticEngine.taken()
        }
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
    }

    public func snooze(_ item: DoseEventItem) {
        perform {
            try DoseActions.snooze(
                medicineID: item.medicineID,
                scheduledTime: scheduledTime(for: item),
                minutes: defaultSnoozeMinutes,
                source: .manual,
                in: context
            )
        }
        HapticEngine.selection()
    }

    // MARK: Medicine lifecycle

    public func addMedicine(_ medicine: Medicine) {
        context.insert(medicine)
        save()
        reload()
        HapticEngine.added()
    }

    public func update(_ medicine: Medicine) {
        save()
        reload()
    }

    public func archive(_ medicine: Medicine) {
        medicine.isArchived = true
        save()
        reload()
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

    // MARK: Private — external sync (widgets + Live Activity)

    /// Reload home/lock widgets and reconcile the Live Activity from freshly
    /// computed state. Called at the end of every `reload()`.
    private func syncExternal() {
        WidgetCenter.shared.reloadAllTimelines()
        let events = todaysEvents
        Task { await LiveActivityService.shared.sync(events: events) }
    }

    /// Default snooze interval (minutes), shared with the App Intents layer.
    private var defaultSnoozeMinutes: Int { NotificationIDs.snoozeMinutes }

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

    private func scheduledTime(for item: DoseEventItem) -> Date? {
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
