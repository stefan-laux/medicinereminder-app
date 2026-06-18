import SwiftUI

// DoseStatus.swift
public enum DoseStatus: String, Codable, Sendable, CaseIterable {
    case pending, taken, skipped, snoozed
    public var label: String {
        switch self { case .pending: "Pending"; case .taken: "Taken"; case .skipped: "Skipped"; case .snoozed: "Snoozed" }
    }
    public var systemImage: String {
        switch self { case .pending: "circle"; case .taken: "checkmark.circle.fill"
        case .skipped: "xmark.circle.fill"; case .snoozed: "clock.badge.fill" }
    }
}
