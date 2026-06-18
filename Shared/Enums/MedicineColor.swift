import SwiftUI

// MedicineColor.swift  — programmatic palette (NO asset catalog dependency)
public enum MedicineColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case coral, tangerine, amber, lime, emerald, teal, sky, blue, indigo, violet, magenta, rose, slate
    public var id: String { rawValue }
    public static let `default`: MedicineColor = .blue
    public var displayName: String { rawValue.capitalized }
    /// Hex for light appearance. DesignSystem provides `Color(hex:)`.
    public var lightHex: UInt {
        switch self {
        case .coral: 0xFF6B6B; case .tangerine: 0xFF8C42; case .amber: 0xFFB400
        case .lime: 0x9BCF53; case .emerald: 0x2ECC71; case .teal: 0x1ABC9C
        case .sky: 0x4FC3F7; case .blue: 0x4D8AF0; case .indigo: 0x5B6CF0
        case .violet: 0x8E7CFF; case .magenta: 0xE056C1; case .rose: 0xF06292; case .slate: 0x7E8AA2
        }
    }
    /// Slightly brighter hex for dark appearance.
    public var darkHex: UInt {
        switch self {
        case .coral: 0xFF8585; case .tangerine: 0xFFA15C; case .amber: 0xFFC93C
        case .lime: 0xB5E06F; case .emerald: 0x4BE08C; case .teal: 0x37D7B6
        case .sky: 0x6FD0FF; case .blue: 0x6FA0FF; case .indigo: 0x7C8CFF
        case .violet: 0xA594FF; case .magenta: 0xF06FD6; case .rose: 0xFF7BA6; case .slate: 0x9AA6BE
        }
    }
    // `color` / `gradient` are provided by DesignSystem (MedicineColor+UI.swift) as a SwiftUI extension.
}
