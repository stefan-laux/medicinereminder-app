import ActivityKit
import Foundation

/// Drives the Dynamic Island / Lock Screen Live Activity for the current dose.
///
/// Design: there is at most ONE running activity at a time — for the soonest dose
/// today that still has a pending item. It is (re)started whenever the app is
/// foregrounded or data changes, counts down to the slot time, shows per-medicine
/// Take/Skip, and is dismissed as soon as the dose is resolved (taken, skipped,
/// or snoozed). Notifications are not used.
///
/// `Activity` is not `Sendable`, so every ActivityKit call lives in a
/// `nonisolated` helper that resolves the handle locally from `Activity.activities`
/// — the non-Sendable handle never crosses an isolation boundary.
@MainActor
public final class LiveActivityService {

    public static let shared = LiveActivityService()

    /// Pending auto-dismiss tasks keyed by slot id (`Task` is Sendable).
    private var dismissTasks: [String: Task<Void, Never>] = [:]

    /// How long after the slot time an unacted activity auto-dismisses.
    private let window: TimeInterval = 2 * 60 * 60

    /// A dose's Live Activity only appears within this lead time before its slot
    /// (so an 8:00 dose won't show at 6:00). Doses further out are left to
    /// notifications.
    public static let leadTime: TimeInterval = 5 * 60

    private init() {}

    // MARK: Public surface (main actor)

    /// Reconcile Live Activities with today's events: keep exactly one running
    /// activity — for the soonest dose that still has a pending item — and end
    /// every other or already-resolved activity. Call on launch, when the app
    /// becomes active, and after any dose mutation.
    /// Returns the slot id of the dose the Live Activity is now covering (or
    /// `nil` if none / activities are unavailable) so the caller can skip a
    /// redundant fallback notification for that slot.
    @discardableResult
    public func sync(events: [DoseEvent]) async -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }
        let now = Date()
        let active = events
            .filter { event in
                event.items.contains { $0.status == .pending }
                    && event.time <= now.addingTimeInterval(Self.leadTime)  // at most 5 min before the slot
                    && event.time.addingTimeInterval(window) > now           // not yet auto-dismissed
            }
            .min(by: { $0.time < $1.time })

        // Clear out everything that is no longer the active dose.
        await Self.endActivitiesExcept(keepEventID: active?.id)

        if let active {
            await startOrUpdate(for: active, title: title(for: active))
            return active.id
        }
        return nil
    }

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
        await Self.updateActivity(eventID: event.id, state: state, staleDate: event.time.addingTimeInterval(window))

        // Retire the activity once nothing in the slot is still pending (taken,
        // skipped, or snoozed all count as resolved); otherwise keep an
        // auto-dismiss armed for when the dose window passes.
        if !event.items.contains(where: { $0.status == .pending }) {
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

    /// End every running dose activity.
    public func endAll() async {
        for task in dismissTasks.values { task.cancel() }
        dismissTasks.removeAll()
        await Self.endAllActivities()
    }

    // MARK: ActivityKit calls (nonisolated — the non-Sendable Activity never
    // crosses an isolation boundary because it is resolved and used right here)

    private nonisolated static func hasActivity(eventID: String) -> Bool {
        Activity<DoseActivityAttributes>.activities.contains { $0.attributes.eventID == eventID }
    }

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
            return false
        }
    }

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

    /// End every running dose activity except the one for `keepEventID`.
    private nonisolated static func endActivitiesExcept(keepEventID: String?) async {
        for activity in Activity<DoseActivityAttributes>.activities
        where activity.attributes.eventID != keepEventID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    // MARK: Auto-dismiss

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

    // MARK: Mapping

    private func title(for event: DoseEvent) -> String {
        let hour = Calendar.current.component(.hour, from: event.time)
        switch hour {
        case 5..<12: return String(localized: "Morning dose")
        case 12..<17: return String(localized: "Afternoon dose")
        case 17..<22: return String(localized: "Evening dose")
        default: return String(localized: "Night dose")
        }
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
