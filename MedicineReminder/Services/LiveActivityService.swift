import ActivityKit
import Foundation

/// Manages the Dynamic Island / Lock Screen Live Activity that tracks the
/// progress of the current dose slot. Maps `DoseEvent` -> `DoseActivityAttributes`.
@MainActor
public final class LiveActivityService {

    public static let shared = LiveActivityService()

    /// Tracks the currently-running activity keyed by event (slot) id so we can
    /// update or end it without re-querying ActivityKit's generic store.
    private var activities: [String: Activity<DoseActivityAttributes>] = [:]

    /// Pending auto-dismiss tasks keyed by slot id. Each waits until the dose
    /// window passes, then ends a still-unresolved activity so it never lingers
    /// on the Lock Screen.
    private var dismissTasks: [String: Task<Void, Never>] = [:]

    /// How long after the slot time an unacted activity is auto-dismissed.
    /// Matches the `staleDate` used for the content state.
    private let window: TimeInterval = 2 * 60 * 60

    private init() {}

    /// Start a Live Activity for the given dose event, or update it if one is
    /// already running for that slot. No-op if Live Activities are disabled.
    public func startOrUpdate(for event: DoseEvent, title: String) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // If we already track this slot, just push a new content state.
        if activities[event.id] != nil {
            await update(for: event)
            return
        }

        // Reconcile with any system-side activity that survived a relaunch.
        if let existing = Activity<DoseActivityAttributes>.activities.first(where: { $0.attributes.eventID == event.id }) {
            activities[event.id] = existing
            await update(for: event)
            return
        }

        let attributes = DoseActivityAttributes(
            eventID: event.id,
            slotTime: event.time,
            title: title
        )
        let state = Self.contentState(from: event)
        let staleDate = event.time.addingTimeInterval(window)

        do {
            let activity = try Self.requestActivity(attributes: attributes, state: state, staleDate: staleDate)
            activities[event.id] = activity
            scheduleAutoDismiss(for: event)
        } catch {
            // Starting a Live Activity can fail (budget, disabled). Fail quietly.
        }
    }

    /// Push an updated content state for an already-running activity.
    public func update(for event: DoseEvent) async {
        guard let activity = activity(for: event.id) else { return }
        let state = Self.contentState(from: event)
        await Self.pushUpdate(to: activity, state: state, staleDate: event.time.addingTimeInterval(window))

        // Once every item is resolved (nothing pending), retire the activity.
        if state.takenCount + skippedCount(in: event) >= state.totalCount, state.totalCount > 0 {
            await end(eventID: event.id)
        } else {
            // Still unresolved — make sure an auto-dismiss is armed so the
            // activity clears once its dose window passes.
            scheduleAutoDismiss(for: event)
        }
    }

    /// End the activity for a specific slot immediately.
    public func end(eventID: String) async {
        cancelAutoDismiss(for: eventID)
        guard let activity = activity(for: eventID) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        activities[eventID] = nil
    }

    /// End every running dose activity (e.g. on log-out or data reset).
    public func endAll() async {
        for task in dismissTasks.values { task.cancel() }
        dismissTasks.removeAll()
        for activity in Activity<DoseActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activities.removeAll()
    }

    // MARK: Auto-dismiss

    /// Arm (or re-arm) a task that ends a still-unresolved activity once its dose
    /// window passes, removing it from the Lock Screen with an `.after` policy.
    /// Replaces any prior task for the same slot so repeated updates don't
    /// accumulate timers.
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
        guard let activity = activity(for: eventID) else { return }
        await activity.end(nil, dismissalPolicy: .after(date))
        activities[eventID] = nil
    }

    private func cancelAutoDismiss(for eventID: String) {
        dismissTasks[eventID]?.cancel()
        dismissTasks[eventID] = nil
    }

    // MARK: ActivityKit requests (nonisolated)

    /// Create and consume the non-Sendable `ActivityContent` entirely off the
    /// main actor so it never crosses an isolation boundary (Swift 6 region
    /// isolation). Inputs and the returned `Activity` handle are all Sendable.
    private nonisolated static func requestActivity(
        attributes: DoseActivityAttributes,
        state: DoseActivityAttributes.ContentState,
        staleDate: Date
    ) throws -> Activity<DoseActivityAttributes> {
        let content = ActivityContent(state: state, staleDate: staleDate)
        return try Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    private nonisolated static func pushUpdate(
        to activity: Activity<DoseActivityAttributes>,
        state: DoseActivityAttributes.ContentState,
        staleDate: Date
    ) async {
        let content = ActivityContent(state: state, staleDate: staleDate)
        await activity.update(content)
    }

    // MARK: Mapping

    private func activity(for eventID: String) -> Activity<DoseActivityAttributes>? {
        if let tracked = activities[eventID] { return tracked }
        if let found = Activity<DoseActivityAttributes>.activities.first(where: { $0.attributes.eventID == eventID }) {
            activities[eventID] = found
            return found
        }
        return nil
    }

    private func skippedCount(in event: DoseEvent) -> Int {
        event.items.filter { $0.status == .skipped }.count
    }

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
