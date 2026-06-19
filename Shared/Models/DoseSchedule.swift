import Foundation
import SwiftData

// DoseSchedule.swift
@Model
public final class DoseSchedule {
    public var id: UUID = UUID()
    public var medicine: Medicine?
    public var frequencyRaw: String = ScheduleFrequencyType.once.rawValue
    public var timeSlots: [TimeOfDay] = []   // sorted; the times of day reminders fire
    public var intervalHours: Int = 8        // used when frequency == .everyNHours
    public var weekdays: [Int] = []          // 1...7 (Calendar weekday); .specificDays; empty == every day
    public var startDate: Date = Date()
    public var endDate: Date?
    public var isActive: Bool = true

    public init(id: UUID = UUID(), frequency: ScheduleFrequencyType, timeSlots: [TimeOfDay] = [],
                intervalHours: Int = 8, weekdays: [Int] = [], startDate: Date = Date(),
                endDate: Date? = nil, isActive: Bool = true) {
        self.id = id; self.frequencyRaw = frequency.rawValue
        self.timeSlots = timeSlots.sorted(); self.intervalHours = intervalHours
        self.weekdays = weekdays; self.startDate = startDate; self.endDate = endDate; self.isActive = isActive
    }
    public var frequency: ScheduleFrequencyType { ScheduleFrequencyType(rawValue: frequencyRaw) ?? .once }
}
