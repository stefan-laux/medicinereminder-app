import Foundation

// StreakCalculator.swift
public enum StreakCalculator {

    /// Outcome of evaluating a single day's scheduled doses.
    private enum DayResult {
        case allTaken      // had scheduled doses, every one taken
        case missed        // had scheduled doses, at least one not taken
        case noDoses       // no scheduled (non-PRN) doses that day — neutral
    }

    /// Consecutive days (ending at `asOf`) where every scheduled dose that day was taken. PRN ignored.
    public static func currentStreak(medicines: [Medicine], logs: [DoseLog], asOf: Date = Date(), calendar: Calendar = .current) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: asOf)
        let earliest = earliestDay(medicines: medicines, calendar: calendar)

        // Walk backward day by day until a missed day or we run past the earliest schedule start.
        var safety = 0
        let maxDays = 366 * 5
        while safety < maxDays {
            switch dayResult(for: cursor, medicines: medicines, logs: logs, calendar: calendar) {
            case .allTaken:
                streak += 1
            case .missed:
                return streak
            case .noDoses:
                break // neutral: streak unaffected, keep scanning earlier days
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
            if let earliest, cursor < earliest { break }
            safety += 1
        }
        return streak
    }

    /// Longest run of consecutive (non-missed) all-taken days across the medicines' active history.
    public static func longestStreak(medicines: [Medicine], logs: [DoseLog], asOf: Date = Date(), calendar: Calendar = .current) -> Int {
        guard let earliest = earliestDay(medicines: medicines, calendar: calendar) else { return 0 }
        let end = calendar.startOfDay(for: asOf)
        guard earliest <= end else { return 0 }

        var longest = 0
        var running = 0
        var cursor = earliest
        var safety = 0
        let maxDays = 366 * 5
        while cursor <= end && safety < maxDays {
            switch dayResult(for: cursor, medicines: medicines, logs: logs, calendar: calendar) {
            case .allTaken:
                running += 1
                longest = max(longest, running)
            case .missed:
                running = 0
            case .noDoses:
                break // neutral: does not extend or break the run
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            safety += 1
        }
        return longest
    }

    // MARK: - Private

    private static func dayResult(for day: Date, medicines: [Medicine], logs: [DoseLog], calendar: Calendar) -> DayResult {
        let events = ScheduleEngine.events(for: medicines, logs: logs, on: day, calendar: calendar)
        let items = events.flatMap { $0.items }
        if items.isEmpty { return .noDoses }
        let allTaken = items.allSatisfy { $0.status == .taken }
        return allTaken ? .allTaken : .missed
    }

    /// Earliest day any active schedule could have started — bounds the backward/forward scans.
    private static func earliestDay(medicines: [Medicine], calendar: Calendar) -> Date? {
        let starts = medicines
            .filter { !$0.isArchived }
            .flatMap { $0.schedules ?? [] }
            .filter { $0.isActive && $0.frequency != .asNeeded }
            .map { calendar.startOfDay(for: $0.startDate) }
        return starts.min()
    }
}
