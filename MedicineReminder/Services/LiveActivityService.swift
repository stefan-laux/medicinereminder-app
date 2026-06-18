import ActivityKit
import Foundation

/// Manages the Dynamic Island / Lock Screen Live Activity that tracks the
/// progress of the current dose slot. Maps `DoseEvent` -> `DoseActivityAttributes`.
///
/// `Activity` is not `Sendable`, so it is never cached in main-actor state.
/// Each operation looks the activity up fresh from `Activity.activities`
/// (a disconnected value used once and not retained), so the non-Sendable
/// handle never crosses an isolation boundary while also being referenced by
/// the service — which is what trips Swift 6 region isolation
/// ("sending 'activity' risks causing data races").
@MainActor
public final class LiveActivityService {

    public static let shared = LiveActivityService()

    /// Pending auto-dismiss tasks keyed by slot id. `Task` is Sendable, so this
    /// is safe to hold in main-actor state.
    private var dismissTasks: [String: Task<Void, Never>] = [:]

    /// How long after the slot time an unacted activity is auto-dismissed.
    /// Matches the `staleDate` used for the content state.
    private let window: TimeInterval = 2 * 60 * 60

    private init() {}

    /// Start a Live Activity for the given dose event, or update it if one is
    /// already running for that slot. No-op if Live Activities are disabled.
    public func startOrUpdate(for event: DoseEvent, title: String) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Already running for this slot -> push an update instead.
        if currentActivity(for: event.id) != nil {
            await update(for: event)
            return
        }

        let attributes = DoseActivityAttributes(
            eventID: event.id,
            slotTime: event.time,
            title: title
        )
        let content = ActivityContent(
            state: Self.contentState(from: event),
            staleDate: event.time.addingTimeInterval(window)
        )

        do {
            // The returned handle is intentionally discarded; later operations
            // re-resolve it from `Activity.activities`.
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            scheduleAutoDismiss(for: event)
        } catch {
            // Starting a Live Activity can fail (budget, disabled). Fail quietly.
        }
    }

    /// Push an updated content state for the running activity of this slot.
    public func update(for event: DoseEvent) async {
        guard let activity = currentActivity(for: event.id) else { return }
        let state = Self.contentState(from: event)
        let content = ActivityContent(state: state, staleDate: event.time.addingTimeInterval(window))
        await activity.update(content)

        // Once every item is resolved (nothing pending), retire the activity;
        // otherwise make sure an auto-dismiss is armed.
        if state.takenCount + skippedCount(in: event) >= state.totalCount, state.totalCount > 0 {
            await end(eventID: event.id)
        } else {
            scheduleAutoDismiss(for: event)
        }
    }

    /// End the activity for a specific slot immediately.
    public func end(eventID: String) async {
        cancelAutoDismiss(for: eventID)
        guard let activity = currentActivity(for: eventID) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    /// End every running dose activity (e.g. on data reset).
    public func endAll() async {
        for task in dismissTasks.values { task.cancel() }
        dismissTasks.removeAll()

        // Resolve fresh handles one id at a time so no non-Sendable `Activity`
        // is held across the `await`.
        let ids = Activity<DoseActivityAttributes>.activities.map(\.attributes.eventID)
        for id in ids {
            guard let activity = currentActivity(for: id) else { continue }
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: Auto-dismiss

    /// Arm (or re-arm) a task that ends a still-unresolved activity once its dose
    /// window passes. Replaces any prior task for the same slot.
    private func scheduleAutoDismiss(for event: DoseEvent) {
        let eventID = event.id
        let dismissDate = event.time.addingTimeInterval(window)

        dismissTasks[eventID]?.cancel()
        let delay = dismissDate.timeIntervalSinceNow

        let task = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }
            if Task.isCancelled { return }
            guard let self else { return }
            await self.autoDismiss(eventID: eventID, after: dismissDate)
        }
        dismissTasks[eventID] = task
    }

    /// End the activity for `eventID` with an `.after(date)` dismissal so the
    /// system clears it from the Lock Screen once the window has elapsed.
    private func autoDismiss(eventID: String, after date: Date) async {
        dismissTasks[eventID] = nil
        guard let activity = currentActivity(for: eventID) else { return }
        await activity.end(nil, dismissalPolicy: .after(date))
    }

    private func cancelAutoDismiss(for eventID: String) {
        dismissTasks[eventID]?.cancel()
        dismissTasks[eventID] = nil
    }

    // MARK: Lookup

    /// Resolve the system's activity for a slot id as a fresh, disconnected
    /// value (never cached in `self`, so it can be sent into ActivityKit's
    /// async methods without a data-race diagnostic).
    private func currentActivity(for eventID: String) -> Activity<DoseActivityAttributes>? {
        Activity<DoseActivityAttributes>.activities.first { $0.attributes.eventID == eventID }
    }

    private func skippedCount(in event: DoseEvent) -> Int {
        event.items.filter { $0.status == .skipped }.count
    }

    // MARK: Mapping

    /// Build the ActivityKit content state from a dose event.
    static func contentState(from event: DoseEvent) -> DoseActivityAttributes.ContentState {
        let items = event.items.map { item in
            DoseActivityAttributes.ContentState.Item(
                id: item.medicineID.uuidString,
                name: item.name,
                dosage: item.dosageDescription,
                colorRaw: item.colorRaw,
                iconName: item.iconName,
                statusRaw: item.status.rawValue
            )
        }
        let taken = event.items.filter { $0.status == .taken }.count
        return DoseActivityAttributes.ContentState(
            medicines: items,
            takenCount: taken,
            totalCount: event.items.count
        )
    }
}
