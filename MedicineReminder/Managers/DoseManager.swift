import Foundation
import Observation
import SwiftData
import WidgetKit

/// The app's primary observable store. Owns the working set of medicines and
/// today's grouped dose events, and centralizes the side effects that run after
/// a dose mutation: persistence, widget refresh, Live Activity reconciliation,
/// and haptics.
///
/// Reminders use the Live Activity when the app can show one, with a local
/// notification as a fallback for the doses it isn't covering.
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
    /// Logs from the last reload, reused by the external sync (fallback notifications).
    @ObservationIgnored private var cachedLogs: [DoseLog] = []
    /// One-shot timer that re-syncs when the next dose crosses into the Live
    /// Activity lead window, so its activity can appear ~5 min before the slot.
    @ObservationIgnored private var leadTimer: Task<Void, Never>?

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
        cachedLogs = logs
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
        let meds = medicines
        let logs = cachedLogs
        Task {
            // Live Activity claims the soonest pending dose; schedule fallback
            // notifications for the rest (so a reminder still fires when the app
            // isn't open to show a Live Activity).
            let coveredSlot = await LiveActivityService.shared.sync(events: events)
            await NotificationService.shared.rescheduleAll(medicines: meds, logs: logs, excludingSlot: coveredSlot)
        }
        scheduleLeadRefresh()
    }

    /// While the app is running, wake up to re-sync exactly when the next dose
    /// crosses into the Live Activity lead window (so the activity appears ~5 min
    /// before the slot). If the app is suspended at that moment the timer won't
    /// fire — the dose's notification covers that case.
    private func scheduleLeadRefresh() {
        leadTimer?.cancel()
        let lead = LiveActivityService.leadTime
        let now = Date()
        let upcoming = todaysEvents
            .filter { event in
                event.items.contains { $0.status == .pending }
                    && event.time.addingTimeInterval(-lead) > now
            }
            .min(by: { $0.time < $1.time })
        guard let next = upcoming else { return }
        let delay = next.time.addingTimeInterval(-lead).timeIntervalSinceNow
        guard delay > 0 else { return }
        leadTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            if Task.isCancelled { return }
            self?.reload()
        }
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
