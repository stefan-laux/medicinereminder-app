import ActivityKit
import Foundation

/// Manages the Dynamic Island / Lock Screen Live Activity that tracks the
/// progress of the current dose slot. Maps `DoseEvent` -> `DoseActivityAttributes`.
///
/// `Activity` is not `Sendable`. Calling its async `update`/`end` methods from a
/// `@MainActor` context would *send* the non-Sendable handle across the actor
/// boundary ("sending 'activity' risks causing data races"). So every ActivityKit
/// call lives in a `nonisolated` helper that resolves the handle locally from
/// `Activity.activities`, uses it, and discards it — the `Activity` is never
/// passed between the main actor and nonisolated code. The `@MainActor` surface
/// only ever moves `Sendable` values (ids, content state, dates).
@MainActor
public final class LiveActivityService {

    public static let shared = LiveActivityService()

    /// Pending auto-dismiss tasks keyed by slot id. `Task` is Sendable, so this
    /// is safe to hold in main-actor state.
    private var dismissTasks: [String: Task<Void, Never>] = [:]

    /// How long after the slot time an unacted activity is auto-dismissed.
    private let window: TimeInterval = 2 * 60 * 60

    private init() {}

    // MARK: Public surface (main actor)

    /// Start a Live Activity for the given dose event, or update it if one is
    /// already running for that slot. No-op if Live Activities are disabled.
    public func startOrUpdate(for event: DoseEvent, title: String) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if Self.hasActivity(eventID: event.id) {
            await update(for: event)
            return
        }

        let attributes = DoseActivityAttributes(eventID: event.id, slotTime: event.time, title: title)
        let started = Self.requestActivity(
            attributes: attributes,
            state: Self.contentState(from: event),
            staleDate: event.time.addingTimeInterval(window)
        )
        if started { scheduleAutoDismiss(for: event) }
    }

    /// Push an updated content state for the running activity of this slot.
    public func update(for event: DoseEvent) async {
        guard Self.hasActivity(eventID: event.id) else { return }
        let state = Self.contentState(from: event)
        await Self.updateActivity(
            eventID: event.id,
            state: state,
            staleDate: event.time.addingTimeInterval(window)
        )

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
        await Self.endActivityImmediately(eventID: eventID)
    }

    /// End every running dose activity (e.g. on data reset).
    public func endAll() async {
        for task in dismissTasks.values { task.cancel() }
        dismissTasks.removeAll()
        await Self.endAllActivities()
    }

    // MARK: ActivityKit calls (nonisolated — the non-Sendable Activity never
    // crosses an isolation boundary because it is resolved and used right here)

    /// Whether the system currently has an activity for this slot id.
    private nonisolated static func hasActivity(eventID: String) -> Bool {
        Activity<DoseActivityAttributes>.activities.contains { $0.attributes.eventID == eventID }
    }

    /// Request a new activity. Returns whether it started.
    private nonisolated static func requestActivity(
        attributes: DoseActivityAttributes,
        state: DoseActivityAttributes.ContentState,
        staleDate: Date
    ) -> Bool {
        let content = ActivityContent(state: state, staleDate: staleDate)
        do {
            _ = try Activity.request(attributes: attributes, content: content, pushType: nil)
            return true
        } catch {
            // Starting a Live Activity can fail (budget, disabled). Fail quietly.
            return false
        }
    }

    /// Push new content to the activity for this slot, if one exists.
    private nonisolated static func updateActivity(
        eventID: String,
        state: DoseActivityAttributes.ContentState,
        staleDate: Date
    ) async {
        guard let activity = Activity<DoseActivityAttributes>.activities
            .first(where: { $0.attributes.eventID == eventID }) else { return }
        let content = ActivityContent(state: state, staleDate: staleDate)
        await activity.update(content)
    }

    private nonisolated static func endActivityImmediately(eventID: String) async {
        guard let activity = Activity<DoseActivityAttributes>.activities
            .first(where: { $0.attributes.eventID == eventID }) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
    }

    private nonisolated static func endActivity(eventID: String, after date: Date) async {
        guard let activity = Activity<DoseActivityAttributes>.activities
            .first(where: { $0.attributes.eventID == eventID }) else { return }
        await activity.end(nil, dismissalPolicy: .after(date))
    }

    private nonisolated static func endAllActivities() async {
        for activity in Activity<DoseActivityAttributes>.activities {
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

    private func autoDismiss(eventID: String, after date: Date) async {
        dismissTasks[eventID] = nil
        await Self.endActivity(eventID: eventID, after: date)
    }

    private func cancelAutoDismiss(for eventID: String) {
        dismissTasks[eventID]?.cancel()
        dismissTasks[eventID] = nil
    }

    // MARK: Helpers

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
