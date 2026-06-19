//
//  SettingsView.swift
//  MedicineReminder — Settings
//
//  A Liquid Glass grouped settings screen:
//   • Reminders — default snooze duration.
//   • Weekly summary — Sunday-evening adherence digest via NotificationService.
//   • Siri & Shortcuts — example phrases + a tappable Shortcuts link.
//   • Data — CSV export via ExportService + ShareLink.
//
//  Persisted preferences live in the App Group UserDefaults suite so the
//  widget extension can read them too.
//

import AppIntents
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings keys & defaults

/// Keys + helpers for settings persisted into the shared App Group suite.
/// Kept `enum`/`static` and `fileprivate` so they never collide with other files.
fileprivate enum SettingsKey {
    static let defaultSnoozeMinutes = "settings.defaultSnoozeMinutes"
    static let weeklySummaryEnabled = "settings.weeklySummaryEnabled"
    /// Whether the app's Siri / App Intents integration is enabled. Mirrored by
    /// the intents layer (which reads this key from the shared suite) so a
    /// disabled toggle short-circuits Siri-driven actions.
    static let siriEnabled = "settings.siriEnabled"

    /// Default snooze used when the user has not chosen one yet (matches
    /// `NotificationIDs.snoozeMinutes`).
    static let defaultSnoozeFallback = 10
    /// Weekly summary fires Sunday (Calendar weekday == 1) at 6 PM by default.
    static let summaryWeekday = 1
    static let summaryHour = 18
}

/// Common snooze durations offered in the picker (minutes).
fileprivate let snoozeOptions: [Int] = [5, 10, 15, 20, 30, 45, 60]

fileprivate func snoozeLabel(_ minutes: Int) -> String {
    if minutes >= 60, minutes % 60 == 0 {
        let hours = minutes / 60
        return hours == 1 ? String(localized: "1 hour") : String(localized: "\(hours) hours")
    }
    return String(localized: "\(minutes) minutes")
}

// MARK: - SettingsView

/// Root settings screen. Must be named `SettingsView` (referenced by `MainTabView`).
struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext

    /// Preferences persisted into the App Group suite so the widget can read them.
    @AppStorage(SettingsKey.defaultSnoozeMinutes, store: Self.store)
    private var defaultSnoozeMinutes: Int = SettingsKey.defaultSnoozeFallback

    @AppStorage(SettingsKey.weeklySummaryEnabled, store: Self.store)
    private var weeklySummaryEnabled: Bool = false

    /// Master switch for the app's Siri / Shortcuts integration. The intents
    /// layer reads this same key from the shared suite and declines when off.
    @AppStorage(SettingsKey.siriEnabled, store: Self.store)
    private var siriEnabled: Bool = true

    /// Cached export payload so the `ShareLink` always has a ready document.
    @State private var exportDocument = CSVDocument(text: "")

    /// The App Group-backed defaults suite. Falls back to `.standard` only if the
    /// suite is unavailable (e.g. mis-provisioned), so the screen never crashes.
    fileprivate static let store: UserDefaults =
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard

    var body: some View {
        NavigationStack {
            Form {
                remindersSection
                weeklySummarySection
                siriSection
                dataSection
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(settingsBackground)
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.large)
            .task { refreshExport() }
        }
    }

    // MARK: Background

    private var settingsBackground: some View {
        // Soft accent wash that adapts to light/dark; sits under the glass form.
        LinearGradient(
            colors: [
                MedicineColor.blue.color.opacity(0.10),
                Color(.systemGroupedBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: Reminders

    private var remindersSection: some View {
        Section {
            Picker(selection: $defaultSnoozeMinutes) {
                ForEach(snoozeOptions, id: \.self) { minutes in
                    Text(snoozeLabel(minutes)).tag(minutes)
                }
            } label: {
                Label {
                    Text("Default snooze")
                } icon: {
                    Image(systemName: "clock.badge.fill")
                        .foregroundStyle(MedicineColor.amber.color)
                }
            }
            .accessibilityLabel(Text("Default snooze duration"))
            .accessibilityValue(Text(snoozeLabel(defaultSnoozeMinutes)))
        } header: {
            Text("Reminders")
        } footer: {
            Text("How long the Snooze action delays a dose. Reminders play the system's default notification sound.")
        }
    }

    // MARK: Weekly summary

    private var weeklySummarySection: some View {
        Section {
            Toggle(isOn: weeklySummaryBinding) {
                Label {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Weekly summary")
                        Text("Sunday evening adherence recap")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(MedicineColor.emerald.color)
                }
            }
            .accessibilityLabel(Text("Weekly summary"))
            .accessibilityValue(Text(weeklySummaryEnabled ? "On" : "Off"))
            .accessibilityHint(Text("Sends an adherence recap every Sunday evening"))
        } header: {
            Text("Summary")
        } footer: {
            Text("Get a notification each Sunday evening summarizing how your week went.")
        }
    }

    /// Toggling persists the flag and (re)schedules the recurring summary.
    private var weeklySummaryBinding: Binding<Bool> {
        Binding(
            get: { weeklySummaryEnabled },
            set: { newValue in
                weeklySummaryEnabled = newValue
                Task {
                    await NotificationService.shared.scheduleWeeklySummary(
                        enabled: newValue,
                        weekday: SettingsKey.summaryWeekday,
                        hour: SettingsKey.summaryHour
                    )
                }
            }
        )
    }

    // MARK: Siri & Shortcuts

    @ViewBuilder
    private var siriSection: some View {
        Section {
            Toggle(isOn: $siriEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Use Siri & Shortcuts")
                        Text("Log and check doses with your voice")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: siriEnabled ? "mic.fill" : "mic.slash.fill")
                        .foregroundStyle(MedicineColor.indigo.color)
                }
            }
            .accessibilityLabel(Text("Use Siri and Shortcuts"))
            .accessibilityValue(Text(siriEnabled ? "On" : "Off"))
            .accessibilityHint(Text("Lets Siri log doses and check what's coming up"))

            if siriEnabled {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Try saying:")
                        .font(AppFont.caption)
                        .foregroundStyle(.secondary)
                    Text("“Hey Siri, log my medicine in MedicineReminder”")
                        .font(AppFont.subheadline)
                    Text("“Hey Siri, what do I need to take in MedicineReminder?”")
                        .font(AppFont.subheadline)
                }
                .padding(.vertical, Spacing.xs)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Example Siri phrases"))

                // The one genuinely-tappable control: opens the Shortcuts app.
                ShortcutsLink()
                    .accessibilityLabel(Text("Open in Shortcuts"))
                    .accessibilityHint(Text("Opens the Shortcuts app to add or run these shortcuts"))
            }
        } header: {
            Text("Siri & Shortcuts")
        } footer: {
            Text(siriEnabled
                 ? "Say these to Siri on your device. Tap Shortcuts to add or run them by hand. (Siri voice needs a real device — it can't be tested in the Simulator.)"
                 : "Siri voice commands for logging and checking doses are turned off.")
        }
    }

    // MARK: Data

    private var dataSection: some View {
        Section {
            ShareLink(
                item: exportDocument,
                preview: SharePreview(
                    Text("Medicine history"),
                    image: Image(systemName: "doc.text")
                )
            ) {
                Label {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Export history (CSV)")
                        Text("Share or back up every logged dose")
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "square.and.arrow.up.fill")
                        .foregroundStyle(MedicineColor.sky.color)
                }
            }
            .accessibilityLabel(Text("Export dose history as a CSV file"))
            .accessibilityHint(Text("Opens the share sheet"))
            .simultaneousGesture(TapGesture().onEnded { refreshExport() })
        } header: {
            Text("Data")
        } footer: {
            Text("Your dose log is exported as a spreadsheet-friendly CSV file you can share or save.")
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(Self.appVersion)
                    .foregroundStyle(.secondary)
            } label: {
                Label {
                    Text("Version")
                } icon: {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(MedicineColor.slate.color)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("App version"))
            .accessibilityValue(Text(Self.appVersion))
        } header: {
            Text("About")
        }
    }

    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: Export

    /// Rebuild the CSV document from the current store so `ShareLink` is ready.
    private func refreshExport() {
        let medicines = (try? modelContext.fetch(FetchDescriptor<Medicine>())) ?? []
        let logs = (try? modelContext.fetch(FetchDescriptor<DoseLog>())) ?? []
        exportDocument = CSVDocument(text: ExportService.csv(medicines: medicines, logs: logs))
    }
}

// MARK: - CSVDocument (transferable export payload)

/// A lightweight CSV payload that `ShareLink` can hand to the share sheet as a
/// `.csv` file with a friendly name.
fileprivate struct CSVDocument: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { document in
            Data(document.text.utf8)
        }
        .suggestedFileName { _ in
            let date = Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))
            return "MedicineHistory-\(date).csv"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    let container = SharedModelContainer.preview()
    SettingsView()
        .modelContainer(container)
        .environment(DoseManager(context: container.mainContext))
}
#endif
