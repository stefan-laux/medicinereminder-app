import Foundation

// ScheduleEngine.swift
public enum ScheduleEngine {

    /// Slot identity helper — MUST be used everywhere a slot id is needed so ids match across modules.
    /// Format: "yyyy-MM-dd'T'HH:mm" in the supplied (or current) calendar's timezone.
    public static func slotID(_ time: Date) -> String {
        slotID(time, calendar: .current)
    }

    /// Slot identity using an explicit calendar (so the timezone matches occurrence generation).
    public static func slotID(_ time: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: time)
        let year = c.year ?? 0
        let month = c.month ?? 0
        let day = c.day ?? 0
        let hour = c.hour ?? 0
        let minute = c.minute ?? 0
        return String(format: "%04d-%02d-%02dT%02d:%02d", year, month, day, hour, minute)
    }

    /// Concrete dose times for a single schedule on a given calendar day (respects start/end/weekdays/freq).
    public static func occurrences(for schedule: DoseSchedule, on day: Date, calendar: Calendar = .current) -> [Date] {
        guard schedule.isActive else { return [] }

        let dayStart = calendar.startOfDay(for: day)

        // Honor start/end bounds at day granularity.
        let scheduleStartDay = calendar.startOfDay(for: schedule.startDate)
        if dayStart < scheduleStartDay { return [] }
        if let end = schedule.endDate {
            let scheduleEndDay = calendar.startOfDay(for: end)
            if dayStart > scheduleEndDay { return [] }
        }

        switch schedule.frequency {
        case .asNeeded:
            return []

        case .once, .twiceDaily, .threeTimesDaily:
            return schedule.timeSlots
                .map { $0.date(on: day, calendar: calendar) }
                .sorted()

        case .specificDays:
            // Empty weekdays == every day; otherwise gate by Calendar weekday (1...7).
            if !schedule.weekdays.isEmpty {
                let weekday = calendar.component(.weekday, from: day)
                guard schedule.weekdays.contains(weekday) else { return [] }
            }
            return schedule.timeSlots
                .map { $0.date(on: day, calendar: calendar) }
                .sorted()

        case .everyNHours:
            let interval = max(1, schedule.intervalHours)
            // Anchor the cadence on the time-of-day taken from startDate, then walk the day.
            let startComps = calendar.dateComponents([.hour, .minute], from: schedule.startDate)
            let anchorHour = startComps.hour ?? 0
            let anchorMinute = startComps.minute ?? 0
            guard let firstOfDay = calendar.date(bySettingHour: anchorHour, minute: anchorMinute, second: 0, of: day) else {
                return []
            }
            guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return [firstOfDay]
            }
            // On the schedule's first day, only include slots at/after the exact start instant;
            // on later days every slot in the day counts.
            let isStartDay = dayStart == scheduleStartDay
            var result: [Date] = []
            var current = firstOfDay
            // Guard against pathological intervals producing runaway loops.
            let maxOccurrences = (24 / interval) + 2
            while current < nextDayStart && result.count < maxOccurrences {
                let afterStart = isStartDay ? current >= schedule.startDate : true
                let beforeEnd = schedule.endDate.map { current <= $0 } ?? true
                if current >= dayStart && afterStart && beforeEnd {
                    result.append(current)
                }
                guard let advanced = calendar.date(byAdding: .hour, value: interval, to: current) else { break }
                current = advanced
            }
            return result.sorted()
        }
    }

    /// All grouped dose events for the medicines on a given day, sorted by time. Pending/looked-up status applied from `logs`.
    public static func events(for medicines: [Medicine], logs: [DoseLog], on day: Date, calendar: Calendar = .current) -> [DoseEvent] {
        // Index logs by (medicineID, slotID) for O(1) status resolution.
        let logIndex = buildLogIndex(logs, calendar: calendar)

        // slotID -> (time, [items]) preserving grouping of identical slot times.
        var grouped: [String: (time: Date, items: [DoseEventItem])] = [:]

        for medicine in medicines where !medicine.isArchived {
            for schedule in medicine.schedules {
                for time in occurrences(for: schedule, on: day, calendar: calendar) {
                    let sid = slotID(time, calendar: calendar)
                    let key = LogKey(medicineID: medicine.id, slotID: sid)
                    let matched = logIndex[key]
                    let item = DoseEventItem(
                        id: medicine.id,
                        medicineID: medicine.id,
                        scheduleID: schedule.id,
                        name: medicine.name,
                        dosageDescription: medicine.dosageDescription,
                        colorRaw: medicine.colorRaw,
                        iconName: medicine.iconName,
                        status: matched?.status ?? .pending,
                        logID: matched?.id
                    )
                    if var existing = grouped[sid] {
                        // A medicine appears once per slot; skip duplicate medicine entries.
                        if !existing.items.contains(where: { $0.medicineID == medicine.id }) {
                            existing.items.append(item)
                            grouped[sid] = existing
                        }
                    } else {
                        grouped[sid] = (time: time, items: [item])
                    }
                }
            }
        }

        return grouped
            .map { (sid, value) in
                DoseEvent(id: sid, time: value.time, items: value.items.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
            }
            .sorted { $0.time < $1.time }
    }

    /// Events across an inclusive day range (for Plans/timeline).
    public static func events(for medicines: [Medicine], logs: [DoseLog], from: Date, to: Date, calendar: Calendar = .current) -> [DoseEvent] {
        let startDay = calendar.startOfDay(for: from)
        let endDay = calendar.startOfDay(for: to)
        guard startDay <= endDay else { return [] }

        var result: [DoseEvent] = []
        var cursor = startDay
        // Bound the loop to a sane horizon to avoid runaway iteration.
        var safety = 0
        let maxDays = 366 * 3
        while cursor <= endDay && safety < maxDays {
            result.append(contentsOf: events(for: medicines, logs: logs, on: cursor, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            safety += 1
        }
        return result.sorted { $0.time < $1.time }
    }

    /// Next upcoming (or currently-due) event strictly relevant after `date`. Used by widgets/intents/Live Activity.
    public static func nextEvent(for medicines: [Medicine], logs: [DoseLog], after date: Date, calendar: Calendar = .current) -> DoseEvent? {
        // Search a bounded horizon forward (covers everyNHours and specificDays gaps).
        let horizonDays = 31
        let startDay = calendar.startOfDay(for: date)
        guard let endDay = calendar.date(byAdding: .day, value: horizonDays, to: startDay) else { return nil }

        let candidates = events(for: medicines, logs: logs, from: startDay, to: endDay, calendar: calendar)
        return candidates
            .filter { $0.time > date && $0.items.contains(where: { $0.status == .pending }) }
            .min(by: { $0.time < $1.time })
    }

    // MARK: - Private helpers

    private struct LogKey: Hashable {
        let medicineID: UUID
        let slotID: String
    }

    /// For each (medicine, slot) keep the most recent log so status reflects the latest action.
    private static func buildLogIndex(_ logs: [DoseLog], calendar: Calendar) -> [LogKey: DoseLog] {
        var index: [LogKey: DoseLog] = [:]
        for log in logs {
            guard let medID = log.medicine?.id else { continue }
            let key = LogKey(medicineID: medID, slotID: slotID(log.scheduledTime, calendar: calendar))
            if let existing = index[key] {
                if log.loggedAt >= existing.loggedAt { index[key] = log }
            } else {
                index[key] = log
            }
        }
        return index
    }
}
