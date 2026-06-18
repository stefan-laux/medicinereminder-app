import Foundation

// TimeOfDay.swift  — Codable struct stored in SwiftData arrays
public struct TimeOfDay: Codable, Hashable, Sendable, Comparable, Identifiable {
    public var hour: Int      // 0...23
    public var minute: Int    // 0...59
    public init(hour: Int, minute: Int) { self.hour = hour; self.minute = minute }
    public var id: Int { hour * 60 + minute }
    public static func < (l: TimeOfDay, r: TimeOfDay) -> Bool { l.id < r.id }
    /// Resolve to a concrete Date on the given day using the supplied calendar.
    public func date(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
    public var displayString: String {
        let c = DateComponents(hour: hour, minute: minute)
        let d = Calendar.current.date(from: c) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }
}
