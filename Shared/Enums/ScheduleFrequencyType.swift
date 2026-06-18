import SwiftUI

// ScheduleFrequencyType.swift
public enum ScheduleFrequencyType: String, CaseIterable, Codable, Identifiable, Sendable {
    case once              // one time per day at a single time
    case twiceDaily        // two times per day
    case threeTimesDaily   // three times per day
    case everyNHours       // interval-based (use intervalHours)
    case specificDays      // chosen weekdays at the time slots
    case asNeeded          // PRN — no scheduled reminders, manual logging only
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .once: "Once daily"; case .twiceDaily: "Twice daily"
        case .threeTimesDaily: "3 times daily"; case .everyNHours: "Every N hours"
        case .specificDays: "Specific days"; case .asNeeded: "As needed"
        }
    }
}
