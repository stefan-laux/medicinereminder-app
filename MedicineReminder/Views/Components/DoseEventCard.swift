//
//  DoseEventCard.swift
//  MedicineReminder
//
//  A Liquid Glass card for one dose slot (a `DoseEvent`): a slot-time header
//  followed by one row per medicine due at that time. Every card uses the same
//  neutral glass background; the medicine's chosen color is used only for its
//  pill icon. Taking a dose flashes the WHOLE card green; skipping dims + strikes
//  through the row. Swipe right = Take, swipe left = Skip. Mutations route through
//  `DoseManager`.
//

import SwiftUI

/// A card for a single dose slot. Hand it the slot's ``DoseEvent`` and the
/// shared ``DoseManager``.
public struct DoseEventCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let event: DoseEvent
    private let manager: DoseManager

    /// 0 = none, 1 = full green wash. Pulsed on take so the whole card flashes.
    @State private var takeFlash: CGFloat = 0

    public init(event: DoseEvent, manager: DoseManager) {
        self.event = event
        self.manager = manager
    }

    public var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header

                VStack(spacing: Spacing.sm) {
                    ForEach(event.items) { item in
                        DoseItemRow(item: item,
                                    onTake: { handleTake(item) },
                                    onSkip: { manager.skip(item) },
                                    onSnooze: { manager.snooze(item) })
                        if item.id != event.items.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
        }
        .overlay {
            // Whole-card green flash when a dose is taken.
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Color.green.opacity(0.24 * takeFlash))
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg, style: .continuous))
    }

    /// Log the dose and flash the entire card green.
    private func handleTake(_ item: DoseEventItem) {
        manager.markTaken(item, amount: nil)
        guard !reduceMotion else { return }
        takeFlash = 1
        withAnimation(.easeOut(duration: 0.55)) { takeFlash = 0 }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Image(systemName: slotSymbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(slotTitle)
                .font(AppFont.headline)
                .foregroundStyle(.primary)

            Spacer(minLength: Spacing.sm)

            Text(event.time.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(slotTitle), \(event.time.formatted(date: .omitted, time: .shortened))")
        .accessibilityAddTraits(.isHeader)
    }

    /// Friendly time-of-day name derived from the slot's hour.
    private var slotTitle: String {
        let hour = Calendar.current.component(.hour, from: event.time)
        switch hour {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }

    private var slotSymbol: String {
        let hour = Calendar.current.component(.hour, from: event.time)
        switch hour {
        case 5..<12: return "sunrise.fill"
        case 12..<17: return "sun.max.fill"
        case 17..<21: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }
}

// MARK: - Single medicine row within the card

/// One medicine within a ``DoseEventCard``. Owns its swipe state; the green
/// take animation is handled by the card. File-private.
private struct DoseItemRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: DoseEventItem
    let onTake: () -> Void
    let onSkip: () -> Void
    let onSnooze: () -> Void

    /// Horizontal swipe offset for the take/skip swipe affordance.
    @State private var dragOffset: CGFloat = 0

    private var isTaken: Bool { item.status == .taken }
    private var isSkipped: Bool { item.status == .skipped }
    private var isSnoozed: Bool { item.status == .snoozed }
    private var isResolved: Bool { isTaken || isSkipped }

    var body: some View {
        ZStack {
            swipeBackground
            rowContent
                .offset(x: dragOffset)
                .gesture(swipeGesture)
        }
        .clipShape(.rect(cornerRadius: Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(item.status.label)
        .accessibilityActions {
            Button("Take") { onTake() }
            Button("Skip") { performSkip() }
            Button("Snooze") { onSnooze() }
        }
    }

    // MARK: Row content

    private var rowContent: some View {
        HStack(spacing: Spacing.md) {
            PillIcon(systemName: item.iconName, color: medicineColor)
                .opacity(isSkipped ? 0.45 : 1)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(AppFont.headline)
                    .foregroundStyle(isResolved ? .secondary : .primary)
                    .strikethrough(isSkipped, color: .secondary)
                    .lineLimit(1)

                HStack(spacing: Spacing.xs) {
                    Text(item.dosageDescription)
                        .strikethrough(isSkipped, color: .secondary)
                    if isSnoozed {
                        Label("Snoozed", systemImage: "clock.badge.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.orange)
                    } else if isTaken {
                        Label("Taken", systemImage: "checkmark.circle.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.green)
                    }
                }
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: Spacing.sm)

            controls
        }
        .padding(.vertical, Spacing.xs)
        .padding(.horizontal, Spacing.xs)
        .opacity(isSkipped ? 0.7 : 1)
        .contentShape(.rect)
    }

    /// The medicine's accent color — used only for its pill icon.
    private var medicineColor: MedicineColor {
        MedicineColor(rawValue: item.colorRaw) ?? .default
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: Spacing.sm) {
            DoseStatusButton(.take, tint: .green, isActive: isTaken) {
                onTake()
            }
            DoseStatusButton(.skip, tint: .orange, isActive: isSkipped) {
                performSkip()
            }
            if !isResolved {
                DoseStatusButton(.snooze, isActive: isSnoozed) {
                    onSnooze()
                }
            }
        }
    }

    // MARK: Swipe affordance

    private var swipeBackground: some View {
        HStack {
            swipeBadge(symbol: "checkmark", tint: .green)
                .opacity(dragOffset > 0 ? swipeOpacity : 0)
            Spacer()
            swipeBadge(symbol: "forward.fill", tint: .orange)
                .opacity(dragOffset < 0 ? swipeOpacity : 0)
        }
        .padding(.horizontal, Spacing.md)
    }

    private var swipeOpacity: Double {
        min(1, abs(dragOffset) / swipeCommitThreshold)
    }

    private func swipeBadge(symbol: String, tint: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private var swipeCommitThreshold: CGFloat { 88 }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { value in
                guard !isResolved else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                let clamped = max(-120, min(120, value.translation.width))
                if reduceMotion {
                    dragOffset = clamped
                } else {
                    withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.85)) {
                        dragOffset = clamped
                    }
                }
            }
            .onEnded { value in
                guard !isResolved else { resetDrag(); return }
                let width = value.translation.width
                if width >= swipeCommitThreshold {
                    onTake()
                } else if width <= -swipeCommitThreshold {
                    performSkip()
                }
                resetDrag()
            }
    }

    private func resetDrag() {
        if reduceMotion {
            dragOffset = 0
        } else {
            withAnimation(.snappy(duration: 0.25)) { dragOffset = 0 }
        }
    }

    private func performSkip() {
        if reduceMotion {
            onSkip()
        } else {
            withAnimation(.snappy(duration: 0.3)) { onSkip() }
        }
    }

    private var accessibilityLabel: String {
        "\(item.name), \(item.dosageDescription)"
    }
}

#if DEBUG
import SwiftData

#Preview("Dose Event Card") {
    let container = SharedModelContainer.preview()
    let manager = DoseManager(context: container.mainContext)

    ScrollView {
        VStack(spacing: Spacing.lg) {
            ForEach(manager.todaysEvents) { event in
                DoseEventCard(event: event, manager: manager)
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
    .modelContainer(container)
}
#endif
