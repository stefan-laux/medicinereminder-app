import Foundation
import SwiftData

// Medicine.swift
@Model
public final class Medicine {
    // CloudKit-compatible: no `.unique`, every attribute has a default value, and
    // the to-many relationships are optional.
    public var id: UUID = UUID()
    public var name: String = ""
    public var dosageAmount: Double = 0
    public var unitRaw: String = DosageUnit.mg.rawValue          // DosageUnit.rawValue
    public var colorRaw: String = MedicineColor.default.rawValue // MedicineColor.rawValue
    public var iconName: String = "pills.fill"                   // SF Symbol
    public var notes: String = ""
    public var isCustom: Bool = false                            // true when no FDA match
    public var fdaGenericName: String?
    public var createdAt: Date = Date()
    public var isArchived: Bool = false
    public var sortIndex: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \DoseSchedule.medicine)
    public var schedules: [DoseSchedule]?
    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medicine)
    public var logs: [DoseLog]?

    public init(id: UUID = UUID(), name: String, dosageAmount: Double, unit: DosageUnit,
                color: MedicineColor = .default, iconName: String = "pills.fill", notes: String = "",
                isCustom: Bool = false, fdaGenericName: String? = nil, createdAt: Date = Date(),
                isArchived: Bool = false, sortIndex: Int = 0) {
        self.id = id; self.name = name; self.dosageAmount = dosageAmount
        self.unitRaw = unit.rawValue; self.colorRaw = color.rawValue; self.iconName = iconName
        self.notes = notes; self.isCustom = isCustom; self.fdaGenericName = fdaGenericName
        self.createdAt = createdAt; self.isArchived = isArchived; self.sortIndex = sortIndex
        self.schedules = []; self.logs = []
    }

    // Computed convenience (non-stored)
    public var unit: DosageUnit { DosageUnit(rawValue: unitRaw) ?? .mg }
    public var color: MedicineColor { MedicineColor(rawValue: colorRaw) ?? .default }
    public var dosageDescription: String { unit.formatted(dosageAmount) }   // e.g. "50 mg"
}
