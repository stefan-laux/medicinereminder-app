//
//  HomeView.swift
//  MedicineReminder
//
//  The home dose timeline. Today's `DoseEvent`s are rendered as floating Liquid
//  Glass cards (`DoseEventCard`) over a soft, subtly medicine-tinted blurred
//  gradient. An animated large title "Today" + date sits at the top, followed by
//  an "Upcoming" section (doses still actionable, including overdue ones) and a
//  "Earlier today" section (fully resolved or past doses).
//
//  • Pull-to-refresh re-runs `DoseManager.reload()`.
//  • The content lives in a `ScrollView` so the iOS 26 floating tab bar minimizes
//    as the user scrolls down (behavior configured on the parent `TabView`).
//  • A "+" toolbar button presents `AddEditMedicineView` as a sheet.
//  • All large animations are gated behind Reduce Motion; every control is
//    labeled for VoiceOver and the layout scales with Dynamic Type.
//

import SwiftUI

/// The main dose timeline screen. Reads the shared ``DoseManager`` from the
/// environment and presents today's grouped dose events.
public struct HomeView: View {
    @Environment(DoseManager.self) private var manager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Drives the one-shot title/cards entrance animation.
    @State private var didAppear = false
    /// Controls presentation of the add-medicine sheet.
    @State private var showingAdd = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                    hero

                    if manager.todaysEvents.isEmpty {
                        emptyState
                    } else {
                        timeline
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xxl)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollContentBackground(.hidden)
            .background(background)
            .refreshable { manager.reload() }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add medicine")
                    .accessibilityHint("Create a new medicine and dose schedule")
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddEditMedicineView()
            }
        }
        .onAppear {
            guard !didAppear else { return }
            if reduceMotion {
                didAppear = true
            } else {
                withAnimation(.smooth(duration: 0.5)) { didAppear = true }
            }
        }
    }

    // MARK: - Hero header

    /// Animated large title + today's date. The title uses SF Pro Rounded and
    /// scales with Dynamic Type.
    private var hero: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Today")
                .font(AppFont.largeTitle)
                .foregroundStyle(.primary)

            Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                .font(AppFont.subheadline)
                .foregroundStyle(.secondary)

            if let progress = doseProgress {
                Text(progress.summary)
                    .font(AppFont.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, Spacing.xs)
                    .accessibilityLabel(progress.accessibility)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Spacing.sm)
        .opacity(didAppear ? 1 : 0)
        .offset(y: didAppear ? 0 : (reduceMotion ? 0 : 12))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Timeline sections

    @ViewBuilder
    private var timeline: some View {
        let split = splitEvents(manager.todaysEvents)

        GlassContainer(spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                if !split.upcoming.isEmpty {
                    section(
                        title: "Upcoming",
                        subtitle: countLabel(events: split.upcoming),
                        systemImage: "clock.fill",
                        tint: sectionTint(for: split.upcoming),
                        events: split.upcoming
                    )
                }

                if !split.past.isEmpty {
                    section(
                        title: "Earlier Today",
                        subtitle: countLabel(events: split.past),
                        systemImage: "checkmark.circle.fill",
                        tint: .secondary,
                        events: split.past
                    )
                } else if split.upcoming.isEmpty {
                    // Doses exist for today but every slot is resolved.
                    allDoneState
                }
            }
        }
    }

    private func section(title: String,
                         subtitle: String,
                         systemImage: String,
                         tint: Color,
                         events: [DoseEvent]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(
                title,
                subtitle: subtitle,
                systemImage: systemImage,
                tint: tint
            )

            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                DoseEventCard(event: event, manager: manager)
                    .opacity(didAppear ? 1 : 0)
                    .offset(y: didAppear ? 0 : (reduceMotion ? 0 : 16))
                    .animation(
                        reduceMotion ? nil : .smooth(duration: 0.5).delay(Double(index) * 0.05),
                        value: didAppear
                    )
            }
        }
    }

    // MARK: - Empty / all-done states

    private var emptyState: some View {
        EmptyStateView(
            "No Doses Today",
            systemImage: "pills.fill",
            description: "Add a medicine with a schedule and your daily doses will appear here.",
            tint: MedicineColor.default.color,
            actionTitle: "Add Medicine"
        ) {
            showingAdd = true
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.xxl)
    }

    private var allDoneState: some View {
        EmptyStateView(
            "All Caught Up",
            systemImage: "checkmark.seal.fill",
            description: "You've logged every dose for today. Nice work!",
            tint: .green
        )
        .frame(maxWidth: .infinity)
        .padding(.top, Spacing.lg)
    }

    // MARK: - Background

    /// A soft, subtly medicine-tinted gradient that adapts to light/dark and is
    /// gently blurred so the glass cards read as floating above it.
    private var background: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: backgroundTints,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(0.5)
            .blur(radius: 60)
            .ignoresSafeArea()
        }
    }

    /// Up to three accent tints pulled from today's medicines (falls back to the
    /// default palette accent), kept low-opacity so content stays legible.
    private var backgroundTints: [Color] {
        let colors = distinctTodayColors()
        let base: [Color]
        if colors.isEmpty {
            base = [MedicineColor.default.color, MedicineColor.violet.color]
        } else if colors.count == 1 {
            base = [colors[0], colors[0].opacity(0.4)]
        } else {
            base = Array(colors.prefix(3))
        }
        return base.map { $0.opacity(0.35) }
    }

    private func distinctTodayColors() -> [Color] {
        var seen = Set<String>()
        var result: [MedicineColor] = []
        for event in manager.todaysEvents {
            for item in event.items {
                guard let color = MedicineColor(rawValue: item.colorRaw),
                      !seen.contains(color.rawValue) else { continue }
                seen.insert(color.rawValue)
                result.append(color)
            }
        }
        return result.map(\.color)
    }

    private func sectionTint(for events: [DoseEvent]) -> Color {
        guard let first = events.first?.items.first,
              let color = MedicineColor(rawValue: first.colorRaw) else {
            return MedicineColor.default.color
        }
        return color.color
    }

    // MARK: - Event classification

    /// Partition today's events into actionable "upcoming" (anything still
    /// pending or snoozed, including overdue slots) and resolved "past".
    private func splitEvents(_ events: [DoseEvent]) -> (upcoming: [DoseEvent], past: [DoseEvent]) {
        let now = Date.now
        var upcoming: [DoseEvent] = []
        var past: [DoseEvent] = []
        for event in events {
            if isResolved(event) && event.time <= now {
                past.append(event)
            } else {
                upcoming.append(event)
            }
        }
        return (upcoming, past)
    }

    /// An event is resolved when none of its items are still actionable.
    private func isResolved(_ event: DoseEvent) -> Bool {
        !event.items.contains { $0.status == .pending || $0.status == .snoozed }
    }

    // MARK: - Counts / progress

    private func countLabel(events: [DoseEvent]) -> String {
        let doses = events.reduce(0) { $0 + $1.items.count }
        return doses == 1 ? "1 dose" : "\(doses) doses"
    }

    /// Today's overall taken / total summary for the hero subtitle.
    private var doseProgress: (summary: String, accessibility: String)? {
        let items = manager.todaysEvents.flatMap(\.items)
        guard !items.isEmpty else { return nil }
        let total = items.count
        let taken = items.filter { $0.status == .taken }.count
        let summary = "\(taken) of \(total) doses taken"
        let remaining = total - taken
        let accessibility = remaining == 0
            ? "All \(total) doses taken today"
            : "\(taken) of \(total) doses taken, \(remaining) remaining"
        return (summary, accessibility)
    }
}

#if DEBUG
import SwiftData

#Preview("Home — With Doses") {
    let container = SharedModelContainer.preview()
    HomeView()
        .modelContainer(container)
        .environment(DoseManager(context: container.mainContext))
}

#Preview("Home — Empty") {
    // An empty in-memory store (no SampleData) to exercise the empty state.
    let config = ModelConfiguration(schema: SharedModelContainer.schema, isStoredInMemoryOnly: true)
    let container = (try? ModelContainer(for: SharedModelContainer.schema, configurations: config))
        ?? SharedModelContainer.preview()
    HomeView()
        .modelContainer(container)
        .environment(DoseManager(context: container.mainContext))
}
#endif
