import ActivityKit
import Foundation

public struct DoseActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var medicines: [Item]
        public var takenCount: Int
        public var totalCount: Int
        public struct Item: Codable, Hashable, Identifiable, Sendable {
            public var id: String          // medicineID uuid string
            public var name: String
            public var dosage: String
            public var colorRaw: String
            public var iconName: String
            public var statusRaw: String   // DoseStatus.rawValue
            public init(id: String, name: String, dosage: String,
                        colorRaw: String, iconName: String, statusRaw: String) {
                self.id = id; self.name = name; self.dosage = dosage
                self.colorRaw = colorRaw; self.iconName = iconName; self.statusRaw = statusRaw
            }
        }
        public init(medicines: [Item], takenCount: Int, totalCount: Int) {
            self.medicines = medicines; self.takenCount = takenCount; self.totalCount = totalCount
        }
    }
    public var eventID: String             // == DoseEvent.id (slot id)
    public var slotTime: Date
    public var title: String               // e.g. "Morning dose"
    public init(eventID: String, slotTime: Date, title: String) {
        self.eventID = eventID; self.slotTime = slotTime; self.title = title
    }
}
