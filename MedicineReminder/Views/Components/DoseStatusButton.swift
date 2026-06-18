//
//  DoseStatusButton.swift
//  MedicineReminder
//
//  A small, reusable Take / Skip / Snooze control used by dose cards,
//  detail screens and notifications-mirroring UI. Each button is a single
//  tappable affordance with a tinted Liquid Glass background, an SF Symbol,
//  and full accessibility metadata.
//

import SwiftUI

/// The kind of action a ``DoseStatusButton`` performs. Drives the icon,
/// label, accent color and default accessibility text.
public enum DoseAction: String, CaseIterable, Identifiable, Sendable {
    case take
    case skip
    case snooze

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .take: "Take"
        case .skip: "Skip"
        case .snooze: "Snooze"
        }
    }

    public var systemImage: String {
        switch self {
        case .take: "checkmark"
        case .skip: "xmark"
        case .snooze: "clock.badge"
        }
    }

    /// Semantic accent for the action. Take is green, Skip is orange,
    /// Snooze is the app accent. All resolve correctly in dark & light.
    public var accent: Color {
        switch self {
        case .take: .green
        case .skip: .orange
        case .snooze: .accentColor
        }
    }

    var accessibilityHint: String {
        switch self {
        case .take: "Marks this dose as taken."
        case .skip: "Marks this dose as skipped."
        case .snooze: "Reminds you again later."
        }
    }
}

/// Visual layout style for a ``DoseStatusButton``.
public enum DoseStatusButtonStyle: Sendable {
    /// Compact, icon-only circular button (used inside dense rows).
    case icon
    /// Icon + title label, pill-shaped (used in detail / sheets).
    case labeled
}

/// A reusable Take / Skip / Snooze button. Screen and component agents can
/// drop this in anywhere a dose action is needed.
///
/// ```swift
/// DoseStatusButton(.take) { manager.markTaken(item, amount: nil) }
/// DoseStatusButton(.snooze, style: .labeled, tint: medicine.color.color) { ... }
/// ```
public struct DoseStatusButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let action: DoseAction
    private let style: DoseStatusButtonStyle
    private let tint: Color?
    private let isActive: Bool
    private let perform: () -> Void

    /// - Parameters:
    ///   - action: Which dose action this button performs.
    ///   - style: `.icon` (compact circle) or `.labeled` (icon + title pill).
    ///   - tint: Optional override accent. Defaults to the action's semantic accent.
    ///   - isActive: When `true` the button renders in its filled/selected state
    ///     (e.g. the currently-applied status). Defaults to `false`.
    ///   - perform: The closure to run on tap.
    public init(_ action: DoseAction,
                style: DoseStatusButtonStyle = .icon,
                tint: Color? = nil,
                isActive: Bool = false,
                perform: @escaping () -> Void) {
        self.action = action
        self.style = style
        self.tint = tint
        self.isActive = isActive
        self.perform = perform
    }

    private var accent: Color { tint ?? action.accent }

    public var body: some View {
        Button(action: tappedAction) {
            label
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
        .accessibilityLabel(action.title)
        .accessibilityHint(action.accessibilityHint)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }

    private func tappedAction() {
        perform()
    }

    @ViewBuilder
    private var label: some View {
        switch style {
        case .icon:
            iconLabel
        case .labeled:
            labeledLabel
        }
    }

    private var iconLabel: some View {
        Image(systemName: action.systemImage)
            .font(.system(size: 16, weight: .semibold))
            .symbolVariant(isActive ? .fill : .none)
            .foregroundStyle(isActive ? Color.white : accent)
            .frame(width: 40, height: 40)
            .background {
                Circle()
                    .fill(isActive ? AnyShapeStyle(accent) : AnyShapeStyle(accent.opacity(0.16)))
            }
            .overlay {
                Circle().strokeBorder(accent.opacity(isActive ? 0 : 0.28), lineWidth: 1)
            }
            .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: isActive)
    }

    private var labeledLabel: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: action.systemImage)
                .symbolVariant(isActive ? .fill : .none)
            Text(action.title)
        }
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(isActive ? Color.white : accent)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .frame(minHeight: 44)
        .background {
            Capsule(style: .continuous)
                .fill(isActive ? AnyShapeStyle(accent) : AnyShapeStyle(accent.opacity(0.16)))
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(accent.opacity(isActive ? 0 : 0.28), lineWidth: 1)
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.22), value: isActive)
    }
}

#if DEBUG
#Preview("Dose Status Buttons") {
    VStack(spacing: Spacing.lg) {
        HStack(spacing: Spacing.md) {
            DoseStatusButton(.take) {}
            DoseStatusButton(.skip) {}
            DoseStatusButton(.snooze) {}
        }
        HStack(spacing: Spacing.md) {
            DoseStatusButton(.take, isActive: true) {}
            DoseStatusButton(.skip, isActive: true) {}
        }
        VStack(spacing: Spacing.sm) {
            DoseStatusButton(.take, style: .labeled) {}
            DoseStatusButton(.skip, style: .labeled, isActive: true) {}
            DoseStatusButton(.snooze, style: .labeled, tint: MedicineColor.violet.color) {}
        }
    }
    .padding()
}
#endif
