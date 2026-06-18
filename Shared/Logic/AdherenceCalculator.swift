import Foundation

// AdherenceCalculator.swift
public struct AdherenceStat: Sendable, Hashable {
    public let taken: Int
    public let scheduled: Int
    public var rate: Double { scheduled == 0 ? 0 : Double(taken) / Double(scheduled) }
    public init(taken: Int, scheduled: Int) {
        self.taken = taken; self.scheduled = scheduled
    }
}

public enum AdherenceCalculator {

    /// Overall taken/scheduled across all medicines in the inclusive day range. PRN doses are not scheduled, so excluded.
    public static func overall(medicines: [Medicine], logs: [DoseLog], from: Date, to: Date, calendar: Calendar = .current) -> AdherenceStat {
        let events = ScheduleEngine.events(for: medicines, logs: logs, from: from, to: to, calendar: calendar)
        var taken = 0
        var scheduled = 0
        for event in events {
            for item in event.items {
                scheduled += 1
                if item.status == .taken { taken += 1 }
            }
        }
        return AdherenceStat(taken: taken, scheduled: scheduled)
    }

    /// Per-medicine taken/scheduled keyed by medicine id.
    public static func perMedicine(medicines: [Medicine], logs: [DoseLog], from: Date, to: Date, calendar: Calendar = .current) -> [UUID: AdherenceStat] {
        let events = ScheduleEngine.events(for: medicines, logs: logs, from: from, to: to, calendar: calendar)
        var taken: [UUID: Int] = [:]
        var scheduled: [UUID: Int] = [:]
        for event in events {
            for item in event.items {
                scheduled[item.medicineID, default: 0] += 1
                if item.status == .taken { taken[item.medicineID, default: 0] += 1 }
            }
        }
        var result: [UUID: AdherenceStat] = [:]
        for (id, sched) in scheduled {
            result[id] = AdherenceStat(taken: taken[id] ?? 0, scheduled: sched)
        }
        return result
    }

    /// Daily taken/scheduled for every day in the inclusive range (days with no scheduled doses report 0/0).
    public static func daily(medicines: [Medicine], logs: [DoseLog], from: Date, to: Date, calendar: Calendar = .current) -> [(day: Date, stat: AdherenceStat)] {
        let startDay = calendar.startOfDay(for: from)
        let endDay = calendar.startOfDay(for: to)
        guard startDay <= endDay else { return [] }

        var result: [(day: Date, stat: AdherenceStat)] = []
        var cursor = startDay
        var safety = 0
        let maxDays = 366 * 3
        while cursor <= endDay && safety < maxDays {
            let events = ScheduleEngine.events(for: medicines, logs: logs, on: cursor, calendar: calendar)
            var taken = 0
            var scheduled = 0
            for event in events {
                for item in event.items {
                    scheduled += 1
                    if item.status == .taken { taken += 1 }
                }
            }
            result.append((day: cursor, stat: AdherenceStat(taken: taken, scheduled: scheduled)))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            safety += 1
        }
        return result
    }
}
