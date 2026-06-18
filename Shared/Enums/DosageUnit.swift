import SwiftUI

// DosageUnit.swift
public enum DosageUnit: String, CaseIterable, Codable, Identifiable, Sendable {
    case mg, mcg, g, ml, tablet, capsule, drops, puff, unit, patch, spray, suppository
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .mg: "milligrams"; case .mcg: "micrograms"; case .g: "grams"
        case .ml: "milliliters"; case .tablet: "tablet"; case .capsule: "capsule"
        case .drops: "drops"; case .puff: "puff"; case .unit: "unit"
        case .patch: "patch"; case .spray: "spray"; case .suppository: "suppository"
        }
    }
    public var abbreviation: String {
        switch self {
        case .mg: "mg"; case .mcg: "mcg"; case .g: "g"; case .ml: "ml"
        case .tablet: "tab"; case .capsule: "cap"; case .drops: "drops"
        case .puff: "puff"; case .unit: "unit"; case .patch: "patch"
        case .spray: "spray"; case .suppository: "supp"
        }
    }
    /// Whether the amount field should allow decimals.
    public var allowsDecimal: Bool {
        switch self { case .tablet, .capsule, .drops, .puff, .patch, .suppository: false; default: true }
    }
    /// Pluralize for spoken/written output, e.g. "2 tablets".
    public func formatted(_ amount: Double) -> String {
        let n = amount == amount.rounded() ? String(Int(amount)) : String(format: "%.2g", amount)
        switch self {
        case .mg, .mcg, .g, .ml: return "\(n) \(abbreviation)"
        case .tablet, .capsule, .drops, .puff, .unit, .patch, .spray, .suppository:
            let unit = amount == 1 ? displayName : displayName + "s"
            return "\(n) \(unit)"
        }
    }
}
