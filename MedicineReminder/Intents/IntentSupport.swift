import AppIntents
import Foundation
import SwiftData
import WidgetKit

/// Shared, file-local helpers for the App Intents layer.
///
/// Everything here is `internal` to the app target but only consumed by the
/// intent files in this folder. It centralizes ModelContext access, medicine
/// lookup, slot resolution, and the post-mutation side effects (notification
/// rescheduling + Live Activity refresh) so each intent stays focused on its
/// own dialog. All work is `@MainActor` because it touches SwiftData models.
enum IntentSupport {

    /// The shared App-Group main context — the same store the UI and widgets use.
    @MainActor
    static var context: ModelContext { SharedModelContainer.shared.mainContext }

    /// Default snooze duration (minutes) — mirrors the notification action default
    /// so Siri, notifications, and the in-app control all behave consistently.
    static let defaultSnoozeMinutes = NotificationIDs.snoozeMinutes

    // MARK: Medicine lookup

    /// Fetch the live `Medicine` model for an entity, throwing a user-facing
    /// error if it has since been deleted or archived.
    @MainActor
    static func medicine(for entity: MedicineEntity) throws -> Medicine {
        let id = entity.id
        let descriptor = FetchDescriptor<Medicine>(predicate: #Predicate { $0.id == id })
        guard let medicine = try context.fetch(descriptor).first, !medicine.isArchived else {
            throw IntentError.medicineUnavailable(entity.name)
        }
        return medicine
    }

    /// All active medicines, in display order.
    @MainActor
    static func activeMedicines() throws -> [Medicine] {
        let descriptor = FetchDescriptor<Medicine>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.createdAt)]
        )
        return try context.fetch(descriptor)
    }

    /// Every dose log (used for status resolution by the pure engines).
    @MainActor
    static func allLogs() throws -> [DoseLog] {
        try context.fetch(FetchDescriptor<DoseLog>())
    }

    // MARK: Slot resolution

    /// The next scheduled, still-pending slot time for a single medicine after
    /// `date`, or `nil` if there is no upcoming scheduled dose (PRN / nothing left
    /// today). Callers treat `nil` as an ad-hoc action at "now".
    @MainActor
    static func nextScheduledTime(for medicine: Medicine, after date: Date = Date()) throws -> Date? {
        let logs = try allLogs()
        guard let event = ScheduleEngine.nextEvent(for: [medicine], logs: logs, after: date) else {
            return nil
        }
        return event.time
    }

    // MARK: Side effects (run after a mutation)

    /// Refresh the widgets and reconcile the Live Activity from freshly mutated
    /// data. Notifications are not used.
    @MainActor
    static func refreshAfterMutation() async {
        let medicines = (try? activeMedicines()) ?? []
        let logs = (try? allLogs()) ?? []
        let events = ScheduleEngine.events(for: medicines, logs: logs, on: Date())

        WidgetCenter.shared.reloadAllTimelines()
        await LiveActivityService.shared.sync(events: events)
    }

    // MARK: Spoken formatting

    /// "8:00 AM" style time for spoken dialog.
    static func spokenTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// A relative phrase like "in 15 minutes" for snooze confirmation.
    static func relativeMinutes(_ minutes: Int) -> String {
        let unit = minutes == 1 ? String(localized: "minute") : String(localized: "minutes")
        return "\(minutes) \(unit)"
    }
}

/// User-facing errors surfaced by the App Intents layer.
enum IntentError: LocalizedError {
    case medicineUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .medicineUnavailable(let name):
            return String(localized: "\(name) is no longer available.")
        }
    }
}
