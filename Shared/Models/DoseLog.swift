import Foundation
import SwiftData

// DoseLog.swift
@Model
public final class DoseLog {
    public var id: UUID = UUID()
    public var medicine: Medicine?
    public var scheduledTime: Date = Date()  // the slot this log belongs to (== loggedAt for PRN/ad-hoc)
    public var loggedAt: Date = Date()
    public var statusRaw: String = DoseStatus.pending.rawValue  // DoseStatus.rawValue
    public var amountTaken: Double?          // quantity override; nil == use medicine.dosageAmount
    public var sourceRaw: String = LogSource.manual.rawValue    // LogSource.rawValue
    public var snoozedUntil: Date?

    public init(id: UUID = UUID(), scheduledTime: Date, loggedAt: Date = Date(),
                status: DoseStatus, amountTaken: Double? = nil, source: LogSource = .manual,
                snoozedUntil: Date? = nil) {
        self.id = id; self.scheduledTime = scheduledTime; self.loggedAt = loggedAt
        self.statusRaw = status.rawValue; self.amountTaken = amountTaken
        self.sourceRaw = source.rawValue; self.snoozedUntil = snoozedUntil
    }
    public var status: DoseStatus { DoseStatus(rawValue: statusRaw) ?? .pending }
    public var source: LogSource { LogSource(rawValue: sourceRaw) ?? .manual }
}
