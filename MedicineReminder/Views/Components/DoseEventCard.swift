//
//  DoseEventCard.swift
//  MedicineReminder
//
//  A Liquid Glass card representing one dose slot (a `DoseEvent`): a rounded
//  slot-time header followed by one row per medicine due at that time. Each
//  row offers per-medicine Take / Skip / Snooze, tinted by the medicine's
//  color, with:
//    • Take  → success haptic + a green fill that radiates from the tap point
//    • Skip  → warning haptic + dimmed, struck-through styling
//    • Swipe right = Take (green), swipe left = Skip (orange)
//  All large animations are gated behind Reduce Motion. Mutations route
//  through `DoseManager.markTaken/skip/snooze`.
//

import SwiftUI

/// A card for a single dose slot. Hand it the slot's ``DoseEvent`` and the
/// shared ``DoseManager``; it renders a header and a row per medicine and
/// performs the logging actions itself.
///
/// ```swift
/// DoseEventCard(event: event, manager: doseManager)
/// ```
public struct DoseEventCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let event: DoseEvent
    private let manager: DoseManager

    /// - Parameters:
    ///   - event: The dose slot to render.
    ///   - manager: The shared dose store that performs the mutations.
    public init(event: DoseEvent, manager: DoseManager) {
        self.event = event
        self.manager = manager
    }

    public var body: some View {
        GlassCard(tint: tint) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header

                VStack(spacing: Spacing.sm) {
                    ForEach(event.items) { item in
                        DoseItemRow(item: item,
                                    onTake: { manager.markTaken(item, amount: nil) },
                                    onSkip: { manager.skip(item) },
                                    onSnooze: { manager.snooze(item) })
                        if item.id != event.items.last?.id {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
        }
    }

    private var tint: Color? {
        // Tint the card with the first medicine's color, softly.
        guard let first = event.items.first,
              let color = MedicineColor(rawValue: first.colorRaw) else { return nil }
        return color.color
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

/// One medicine within a ``DoseEventCard``. Owns its own transient animation
/// state (radiating fill on take) and gesture handling. File-private.
private struct DoseItemRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: DoseEventItem
    let onTake: () -> Void
    let onSkip: () -> Void
    let onSnooze: () -> Void

    /// Tap point (in this row's local space) from which the green fill radiates.
    @State private var fillOrigin: CGPoint?
    /// Drives the radiating-circle mask from 0 → 1.
    @State private var fillProgress: CGFloat = 0
    /// Horizontal swipe offset for the take/skip swipe affordance.
    @State private var dragOffset: CGFloat = 0
    /// Center of the Take button (in the row's coordinate space) so the fill
    /// radiates from the control the user pressed.
    @State private var takeButtonCenter: CGPoint = .zero

    private var isTaken: Bool { item.status == .taken }
    private var isSkipped: Bool { item.status == .skipped }
    private var isSnoozed: Bool { item.status == .snoozed }
    private var isResolved: Bool { isTaken || isSkipped }

    var body: some View {
        ZStack {
            swipeBackground
            rowContent
                .background(takeFillOverlay)
                .offset(x: dragOffset)
                .gesture(swipeGesture)
        }
        .coordinateSpace(.named(rowSpace))
        .clipShape(.rect(cornerRadius: Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(item.status.label)
        .accessibilityActions {
            Button("Take") { performTake(from: nil) }
            Button("Skip") { performSkip() }
            Button("Snooze") { performSnooze() }
        }
    }

    /// Named coordinate space so the Take button can report its center for the
    /// radiating fill origin.
    private var rowSpace: String { "doseRow-\(item.id.uuidString)" }

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

    private var medicineColor: MedicineColor {
        MedicineColor(rawValue: item.colorRaw) ?? .default
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: Spacing.sm) {
            DoseStatusButton(.take, tint: .green, isActive: isTaken) {
                performTake(from: takeButtonCenter == .zero ? nil : takeButtonCenter)
            }
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { updateTakeCenter(proxy) }
                        .onChange(of: proxy.size) { _, _ in updateTakeCenter(proxy) }
                }
            }

            DoseStatusButton(.skip, tint: .orange, isActive: isSkipped) {
                performSkip()
            }
            if !isResolved {
                DoseStatusButton(.snooze, isActive: isSnoozed) {
                    performSnooze()
                }
            }
        }
    }

    private func updateTakeCenter(_ proxy: GeometryProxy) {
        let frame = proxy.frame(in: .named(rowSpace))
        takeButtonCenter = CGPoint(x: frame.midX, y: frame.midY)
    }

    // MARK: Radiating green take-fill

    /// A green circle that grows from `fillOrigin`, clipped to the row, when
    /// the dose is taken. Suppressed under Reduce Motion.
    @ViewBuilder
    private var takeFillOverlay: some View {
        GeometryReader { proxy in
            if let origin = fillOrigin, !reduceMotion {
                let maxRadius = maxFillRadius(in: proxy.size, from: origin)
                Circle()
                    .fill(Color.green.opacity(0.22))
                    .frame(width: maxRadius * 2, height: maxRadius * 2)
                    .scaleEffect(fillProgress)
                    .position(origin)
            } else if isTaken {
                // Reduce Motion / persisted-taken: a calm static green wash.
                Color.green.opacity(0.12)
            }
        }
        .allowsHitTesting(false)
    }

    private func maxFillRadius(in size: CGSize, from origin: CGPoint) -> CGFloat {
        let dx = max(origin.x, size.width - origin.x)
        let dy = max(origin.y, size.height - origin.y)
        return (dx * dx + dy * dy).squareRoot()
    }

    // MARK: Swipe affordance

    private var swipeBackground: some View {
        HStack {
            swipeBadge(symbol: "checkmark", tint: .green)
                .opacity(dragOffset > 0 ? swipeOpacity : 0)
            Spacer()
            swipeBadge(symbol: "xmark", tint: .orange)
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
                // Horizontal-dominant drags only; clamp the visual travel.
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
                    performTake(from: nil)
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

    // MARK: Actions

    private func performTake(from point: CGPoint?) {
        // Haptics are owned by `DoseManager.markTaken` (which also handles the
        // streak-milestone haptic), so the row only drives the visual fill.
        if reduceMotion {
            onTake()
        } else {
            // Radiate from the supplied point, else from the Take button's
            // measured center as a sensible fallback.
            fillOrigin = point ?? (takeButtonCenter == .zero ? nil : takeButtonCenter)
            fillProgress = 0
            withAnimation(.easeOut(duration: 0.45)) {
                fillProgress = 1
            }
            onTake()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                fillProgress = 0
                fillOrigin = nil
            }
        }
    }

    private func performSkip() {
        // Haptics owned by `DoseManager.skip`.
        if reduceMotion {
            onSkip()
        } else {
            withAnimation(.snappy(duration: 0.3)) { onSkip() }
        }
    }

    private func performSnooze() {
        // Haptics owned by `DoseManager.snooze`.
        onSnooze()
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

    return ScrollView {
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
