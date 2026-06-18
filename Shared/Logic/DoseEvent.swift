import Foundation

// DoseEvent.swift — a time slot grouping one-or-more medicines due together
public struct DoseEvent: Identifiable, Hashable, Sendable {
    public let id: String              // stable: ISO slot time, e.g. "2026-06-18T08:00"
    public let time: Date
    public var items: [DoseEventItem]
    public init(id: String, time: Date, items: [DoseEventItem]) {
        self.id = id; self.time = time; self.items = items
    }
}

public struct DoseEventItem: Identifiable, Hashable, Sendable {
    public let id: UUID                // == medicine.id (a medicine appears once per slot)
    public let medicineID: UUID
    public let scheduleID: UUID
    public let name: String
    public let dosageDescription: String
    public let colorRaw: String
    public let iconName: String
    public var status: DoseStatus      // resolved from matching DoseLog, else .pending
    public var logID: UUID?
    public init(id: UUID, medicineID: UUID, scheduleID: UUID, name: String,
                dosageDescription: String, colorRaw: String, iconName: String,
                status: DoseStatus, logID: UUID? = nil) {
        self.id = id; self.medicineID = medicineID; self.scheduleID = scheduleID
        self.name = name; self.dosageDescription = dosageDescription
        self.colorRaw = colorRaw; self.iconName = iconName
        self.status = status; self.logID = logID
    }
}
