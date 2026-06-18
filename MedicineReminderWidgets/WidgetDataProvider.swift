//
//  WidgetDataProvider.swift
//  MedicineReminderWidgets
//
//  Read-only bridge between the shared App Group SwiftData store and the
//  widget timeline. All SwiftData access happens on the @MainActor; the
//  resulting `DoseSnapshot` is a pure `Sendable` value the widgets render.
//
//  The provider computes "today's" grouped events and the next pending event
//  via the shared `ScheduleEngine`, then emits a timeline whose entries are
//  anchored to dose boundaries so each widget refreshes right as a dose
//  becomes due (and periodically in between).
//

import Foundation
import SwiftData
import WidgetKit

// MARK: - Snapshot value types (Sendable — safe to cross into TimelineEntry)

/// A flattened, value-type description of a single medicine due at a slot.
/// Mirrors `DoseEventItem` but carries no SwiftData references so it can be
/// stored in a `TimelineEntry` and rendered off the main actor.
struct DoseItemSnapshot: Identifiable, Hashable, Sendable {
    let id: UUID
    let medicineID: UUID
    let name: String
    let dosageDescription: String
    let colorRaw: String
    let iconName: String
    let statusRaw: String

    var status: DoseStatus { DoseStatus(rawValue: statusRaw) ?? .pending }
    var color: MedicineColor { MedicineColor(rawValue: colorRaw) ?? .default }
}

/// A flattened dose event (one time slot, one-or-more medicines).
struct DoseEventSnapshot: Identifiable, Hashable, Sendable {
    let id: String
    let time: Date
    let items: [DoseItemSnapshot]

    var pendingItems: [DoseItemSnapshot] { items.filter { $0.status == .pending } }
    var takenCount: Int { items.filter { $0.status == .taken }.count }
    var totalCount: Int { items.count }

    /// A friendly slot title derived from the hour of day.
    var slotTitle: String {
        let hour = Calendar.current.component(.hour, from: time)
        switch hour {
        case 5..<12: return "Morning dose"
        case 12..<17: return "Afternoon dose"
        case 17..<21: return "Evening dose"
        default: return "Night dose"
        }
    }
}

/// The full set of data a widget needs to render at a given `date`.
struct DoseSnapshot: Sendable {
    /// The instant this snapshot represents (the TimelineEntry date).
    var date: Date
    /// Today's grouped events, sorted by time.
    var todaysEvents: [DoseEventSnapshot]
    /// The next upcoming/pending event after `date` (may be tomorrow+).
    var nextEvent: DoseEventSnapshot?
    /// The previous slot time before `nextEvent` (used as countdown window start).
    var previousSlotTime: Date?

    static let placeholder = DoseSnapshot(
        date: .now,
        todaysEvents: [],
        nextEvent: nil,
        previousSlotTime: nil
    )

    /// Count of doses still pending today (used by lock-screen summaries).
    var remainingTodayCount: Int {
        todaysEvents.reduce(0) { $0 + $1.pendingItems.count }
    }

    /// Count of doses already taken today.
    var takenTodayCount: Int {
        todaysEvents.reduce(0) { $0 + $1.takenCount }
    }

    /// Total scheduled doses today.
    var scheduledTodayCount: Int {
        todaysEvents.reduce(0) { $0 + $1.totalCount }
    }
}

// MARK: - Data loading (@MainActor — touches SwiftData)

/// Loads dose data from the shared App Group store. All methods are
/// `@MainActor` because they read a SwiftData `ModelContext`.
enum WidgetDataProvider {

    /// Fetch all non-archived medicines and recent logs, then compute the
    /// snapshot relative to `date`. Returns an empty (but valid) snapshot on
    /// any read failure so widgets never crash.
    @MainActor
    static func snapshot(for date: Date, calendar: Calendar = .current) -> DoseSnapshot {
        let context = SharedModelContainer.shared.mainContext

        let medicines = fetchMedicines(in: context)
        guard !medicines.isEmpty else {
            return DoseSnapshot(date: date, todaysEvents: [], nextEvent: nil, previousSlotTime: nil)
        }

        // Logs from the start of today through a forward horizon cover both
        // today's status resolution and next-event lookahead without loading
        // the entire history.
        let logs = fetchRelevantLogs(in: context, around: date, calendar: calendar)

        let today = ScheduleEngine.events(
            for: medicines, logs: logs, on: date, calendar: calendar
        ).map(snapshot(from:))

        let nextEvent = ScheduleEngine.nextEvent(
            for: medicines, logs: logs, after: date, calendar: calendar
        ).map(snapshot(from:))

        // The countdown window starts at the most recent prior slot (or, if
        // none, one hour before the target) so the ring depletes sensibly.
        let previousSlot: Date? = nextEvent.flatMap { next in
            let allSlots = today.map(\.time).filter { $0 < next.time }
            return allSlots.max()
        }

        return DoseSnapshot(
            date: date,
            todaysEvents: today,
            nextEvent: nextEvent,
            previousSlotTime: previousSlot
        )
    }

    // MARK: Fetch helpers

    @MainActor
    private static func fetchMedicines(in context: ModelContext) -> [Medicine] {
        let descriptor = FetchDescriptor<Medicine>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.name)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @MainActor
    private static func fetchRelevantLogs(
        in context: ModelContext,
        around date: Date,
        calendar: Calendar
    ) -> [DoseLog] {
        let lower = calendar.startOfDay(for: date)
        // A small forward horizon catches logs already recorded for upcoming
        // slots (e.g. a dose taken early). Past history beyond today is not
        // needed for "today" or "next" computations.
        let upper = calendar.date(byAdding: .day, value: 32, to: lower) ?? date
        let descriptor = FetchDescriptor<DoseLog>(
            predicate: #Predicate { $0.scheduledTime >= lower && $0.scheduledTime <= upper }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: Mapping

    private static func snapshot(from event: DoseEvent) -> DoseEventSnapshot {
        DoseEventSnapshot(
            id: event.id,
            time: event.time,
            items: event.items.map { item in
                DoseItemSnapshot(
                    id: item.id,
                    medicineID: item.medicineID,
                    name: item.name,
                    dosageDescription: item.dosageDescription,
                    colorRaw: item.colorRaw,
                    iconName: item.iconName,
                    statusRaw: item.status.rawValue
                )
            }
        )
    }
}

// MARK: - Timeline entry

/// A single point on a widget timeline.
struct DoseEntry: TimelineEntry, Sendable {
    let date: Date
    let snapshot: DoseSnapshot

    static let placeholder = DoseEntry(date: .now, snapshot: .placeholder)
}

// MARK: - Timeline provider

/// Shared `TimelineProvider` for the home-screen and lock-screen widgets.
/// Builds a small set of entries anchored to dose boundaries so the UI stays
/// fresh as doses fall due, and asks WidgetKit to reload after the last entry.
struct DoseTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> DoseEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (DoseEntry) -> Void) {
        let now = Date()
        Task { @MainActor in
            let snapshot = WidgetDataProvider.snapshot(for: now)
            completion(DoseEntry(date: now, snapshot: snapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> Void) {
        let now = Date()
        Task { @MainActor in
            let calendar = Calendar.current
            var entries: [DoseEntry] = []

            // Always include "now".
            let nowSnapshot = WidgetDataProvider.snapshot(for: now, calendar: calendar)
            entries.append(DoseEntry(date: now, snapshot: nowSnapshot))

            // Add an entry at each upcoming dose time today so the widget flips
            // a dose from "upcoming" to "due/now" exactly on time. Cap the
            // count to stay within WidgetKit's per-refresh budget.
            let upcomingTimes = nowSnapshot.todaysEvents
                .map(\.time)
                .filter { $0 > now }
                .prefix(6)

            for time in upcomingTimes {
                entries.append(DoseEntry(date: time, snapshot: WidgetDataProvider.snapshot(for: time, calendar: calendar)))
            }

            // Refresh policy: reload at the next dose boundary if there is one,
            // otherwise in an hour to keep relative-time labels honest.
            let reloadDate: Date = upcomingTimes.first
                ?? calendar.date(byAdding: .hour, value: 1, to: now)
                ?? now.addingTimeInterval(3600)

            let timeline = Timeline(entries: entries.sorted { $0.date < $1.date }, policy: .after(reloadDate))
            completion(timeline)
        }
    }
}
