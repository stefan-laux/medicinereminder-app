import Foundation
import UserNotifications

/// Stable identifiers for the notification category and its actions.
/// Kept in one place so the AppDelegate handlers and the scheduler agree.
public enum NotificationIDs {
    /// Category attached to every dose reminder (drives the action buttons).
    public static let doseCategory = "DOSE_REMINDER"
    /// Category for the weekly adherence summary.
    public static let summaryCategory = "WEEKLY_SUMMARY"

    /// Action identifiers handled in `AppDelegate`.
    public static let take = "TAKE"
    public static let skip = "SKIP"
    public static let snooze = "SNOOZE"

    /// Identifier prefix for scheduled dose requests so we can wipe them en masse.
    public static let doseRequestPrefix = "dose."
    /// Identifier for the recurring weekly summary request.
    public static let weeklySummaryRequest = "weekly.summary"

    /// userInfo keys carried by each dose notification.
    public static let medicineIDKey = "medicineID"
    public static let scheduledTimeKey = "scheduledTime"
    public static let slotIDKey = "slotID"

    /// How many days ahead we look when filling the 64-notification budget.
    static let lookaheadDays = 30
    /// iOS caps pending local notifications at 64; stay safely under it.
    static let maxScheduled = 60
    /// Minutes added when the user snoozes from a notification action.
    public static let snoozeMinutes = 10

    /// App Group suite key for the "Reminder sound" toggle, mirrored from
    /// `SettingsView` (whose keys are file-private there). Read here so the
    /// toggle actually gates whether dose reminders play a sound.
    static let soundEnabledKey = "settings.notificationSoundEnabled"
}

/// Schedules and manages local notifications for dose reminders + weekly summary.
@MainActor
public final class NotificationService {

    public static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current

    /// App Group-backed defaults suite that holds the user's reminder-sound
    /// preferences (written by `SettingsView`). Falls back to `.standard` if the
    /// suite is unavailable so scheduling never crashes.
    private let settingsStore = UserDefaults(suiteName: AppGroup.identifier) ?? .standard

    private init() {}

    // MARK: Sound preference

    /// Resolve the user's chosen reminder sound, honoring the "Reminder sound"
    /// toggle. Returns `nil` when sound is disabled so reminders stay silent.
    ///
    /// The sound choices are stable identifiers (no bundled custom audio), so
    /// every enabled choice maps to the system default tone; disabling the
    /// toggle suppresses it entirely.
    private func resolvedSound() -> UNNotificationSound? {
        // Default to enabled when the user has never touched the toggle.
        let enabled = settingsStore.object(forKey: NotificationIDs.soundEnabledKey) as? Bool ?? true
        guard enabled else { return nil }
        return .default
    }

    // MARK: Authorization & categories

    /// Request alert/sound/badge authorization. Returns whether it was granted.
    public func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    /// Register the dose category with TAKE / SKIP / SNOOZE actions.
    public func registerCategories() {
        let take = UNNotificationAction(
            identifier: NotificationIDs.take,
            title: String(localized: "Take"),
            options: [.authenticationRequired]
        )
        let skip = UNNotificationAction(
            identifier: NotificationIDs.skip,
            title: String(localized: "Skip"),
            options: []
        )
        let snooze = UNNotificationAction(
            identifier: NotificationIDs.snooze,
            title: String(localized: "Snooze 10 min"),
            options: []
        )
        let doseCategory = UNNotificationCategory(
            identifier: NotificationIDs.doseCategory,
            actions: [take, snooze, skip],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let summaryCategory = UNNotificationCategory(
            identifier: NotificationIDs.summaryCategory,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([doseCategory, summaryCategory])
    }

    // MARK: Scheduling

    /// Wipe all pending dose notifications and schedule the next batch (≤60)
    /// computed from each medicine's schedules via `ScheduleEngine`.
    public func rescheduleAll(medicines: [Medicine], logs: [DoseLog], excludingSlot excludedSlotID: String?) async {
        await cancelAllDoseRequests()

        let active = medicines.filter { !$0.isArchived }
        guard !active.isEmpty else { return }

        let now = Date()
        let to = calendar.date(byAdding: .day, value: NotificationIDs.lookaheadDays, to: now) ?? now

        // Group occurrences into events so co-due medicines share one reminder.
        let events = ScheduleEngine.events(for: active, logs: logs, from: now, to: to, calendar: calendar)

        // Only remind for upcoming slots that still have a pending dose, and skip
        // the slot the Live Activity is already handling.
        let upcoming = events
            .filter { event in
                event.time > now
                    && event.id != excludedSlotID
                    && event.items.contains { $0.status == .pending }
            }
            .sorted { $0.time < $1.time }
            .prefix(NotificationIDs.maxScheduled)

        for event in upcoming {
            let request = makeRequest(for: event)
            do {
                try await center.add(request)
            } catch {
                // Skip individual failures; one bad request shouldn't abort the batch.
                continue
            }
        }
    }

    /// Cancel every pending and delivered dose notification belonging to a medicine.
    public func cancel(for medicineID: UUID) async {
        let target = medicineID.uuidString
        let pending = await center.pendingNotificationRequests()
        let toRemove = pending
            .filter { $0.content.userInfo[NotificationIDs.medicineIDKey] as? String == target }
            .map(\.identifier)
        if !toRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
    }

    /// Schedule (or remove) the recurring weekly adherence summary.
    public func scheduleWeeklySummary(enabled: Bool, weekday: Int, hour: Int) async {
        center.removePendingNotificationRequests(withIdentifiers: [NotificationIDs.weeklySummaryRequest])
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Your weekly summary")
        content.body = String(localized: "See how your adherence looked this week.")
        content.sound = resolvedSound()
        content.categoryIdentifier = NotificationIDs.summaryCategory

        var components = DateComponents()
        components.weekday = max(1, min(7, weekday))
        components.hour = max(0, min(23, hour))
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: NotificationIDs.weeklySummaryRequest,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            // Non-fatal: the summary is a convenience reminder.
        }
    }

    // MARK: Helpers

    private func cancelAllDoseRequests() async {
        let pending = await center.pendingNotificationRequests()
        let toRemove = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(NotificationIDs.doseRequestPrefix) }
        if !toRemove.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
    }

    private func makeRequest(for event: DoseEvent) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()

        let names = event.items.map(\.name)
        if event.items.count == 1, let item = event.items.first {
            content.title = item.name
            content.body = String(localized: "Time to take \(item.dosageDescription).")
        } else {
            content.title = String(localized: "Time for your dose")
            content.body = names.formatted(.list(type: .and))
        }
        content.sound = resolvedSound()
        content.categoryIdentifier = NotificationIDs.doseCategory
        content.interruptionLevel = .timeSensitive
        content.threadIdentifier = event.id

        // Carry the first/primary medicine so single-item actions resolve directly;
        // also carry the slot id so multi-item events can be re-resolved.
        if let primary = event.items.first {
            content.userInfo[NotificationIDs.medicineIDKey] = primary.medicineID.uuidString
        }
        content.userInfo[NotificationIDs.slotIDKey] = event.id
        content.userInfo[NotificationIDs.scheduledTimeKey] = event.time.timeIntervalSince1970

        let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: event.time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        // The slot id makes the request identifier unique and lets the whole
        // dose batch be wiped by prefix in `cancelAllDoseRequests()`.
        let identifier = NotificationIDs.doseRequestPrefix + event.id

        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
