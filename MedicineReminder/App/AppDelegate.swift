import SwiftData
import UIKit
import UserNotifications

/// Handles notification action buttons (TAKE / SKIP / SNOOZE) and foreground
/// presentation. Mutations route through `DoseActions` against the shared
/// App-Group model context, then refresh scheduled notifications + Live Activity.
final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Show dose reminders as banners + sound even when the app is foregrounded.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Respond to action-button taps from a delivered notification.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let actionID = response.actionIdentifier

        guard let medicineID = medicineID(from: userInfo) else { return }
        let scheduledTime = scheduledTime(from: userInfo)

        // All SwiftData (non-Sendable model) work and the dependent side effects
        // run together on the main actor; nothing non-Sendable crosses a boundary.
        await handleAction(actionID, medicineID: medicineID, scheduledTime: scheduledTime)
    }

    // MARK: Main-actor work

    /// Apply the chosen action against the shared store, then refresh scheduled
    /// notifications and the Live Activity from the freshly mutated data.
    @MainActor
    private func handleAction(_ actionID: String,
                              medicineID: UUID,
                              scheduledTime: Date?) async {
        let context = SharedModelContainer.shared.mainContext

        switch actionID {
        case NotificationIDs.take:
            try? DoseActions.logTaken(
                medicineID: medicineID,
                scheduledTime: scheduledTime,
                amount: nil,
                source: .notification,
                in: context
            )
        case NotificationIDs.skip:
            try? DoseActions.skip(
                medicineID: medicineID,
                scheduledTime: scheduledTime,
                source: .notification,
                in: context
            )
        case NotificationIDs.snooze:
            try? DoseActions.snooze(
                medicineID: medicineID,
                scheduledTime: scheduledTime,
                minutes: NotificationIDs.snoozeMinutes,
                source: .notification,
                in: context
            )
        default:
            break // .defaultAction (tap body) / .dismissAction — just open the app.
        }

        let medicines = (try? context.fetch(
            FetchDescriptor<Medicine>(predicate: #Predicate { !$0.isArchived })
        )) ?? []
        let logs = (try? context.fetch(FetchDescriptor<DoseLog>())) ?? []
        let next = ScheduleEngine.nextEvent(for: medicines, logs: logs, after: Date())

        await NotificationService.shared.rescheduleAll(medicines: medicines)
        if let next {
            await LiveActivityService.shared.update(for: next)
        }
    }

    // MARK: Helpers

    private func medicineID(from userInfo: [AnyHashable: Any]) -> UUID? {
        guard let raw = userInfo[NotificationIDs.medicineIDKey] as? String else { return nil }
        return UUID(uuidString: raw)
    }

    private func scheduledTime(from userInfo: [AnyHashable: Any]) -> Date? {
        guard let interval = userInfo[NotificationIDs.scheduledTimeKey] as? TimeInterval else { return nil }
        return Date(timeIntervalSince1970: interval)
    }
}
