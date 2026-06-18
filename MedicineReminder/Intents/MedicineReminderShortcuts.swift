import AppIntents

/// Registers the app's Siri shortcuts. Every phrase includes
/// `\(.applicationName)` so Siri recognizes them and the system can offer them
/// in the Shortcuts app and Spotlight. `LogDoseTakenIntent` is listed first so
/// it is treated as the app's primary, most-suggested action.
struct MedicineReminderShortcuts: AppShortcutsProvider {

    static var shortcutTileColor: ShortcutTileColor { .teal }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogDoseTakenIntent(),
            phrases: [
                "Log my dose in \(.applicationName)",
                "Log \(\.$medicine) in \(.applicationName)",
                "I took my \(\.$medicine) with \(.applicationName)",
                "Mark \(\.$medicine) as taken in \(.applicationName)"
            ],
            shortTitle: "Log Dose",
            systemImageName: "checkmark.circle.fill"
        )

        AppShortcut(
            intent: LogDoseWithAmountIntent(),
            phrases: [
                "Log an amount in \(.applicationName)",
                "Log a dose of \(\.$medicine) in \(.applicationName)",
                "Log a custom dose in \(.applicationName)"
            ],
            shortTitle: "Log Amount",
            systemImageName: "plusminus.circle.fill"
        )

        AppShortcut(
            intent: SkipDoseIntent(),
            phrases: [
                "Skip a dose in \(.applicationName)",
                "Skip my \(\.$medicine) in \(.applicationName)",
                "Skip \(\.$medicine) with \(.applicationName)"
            ],
            shortTitle: "Skip Dose",
            systemImageName: "xmark.circle.fill"
        )

        AppShortcut(
            intent: SnoozeDoseIntent(),
            phrases: [
                "Snooze a dose in \(.applicationName)",
                "Snooze my \(\.$medicine) in \(.applicationName)",
                "Remind me about \(\.$medicine) later in \(.applicationName)"
            ],
            shortTitle: "Snooze Dose",
            systemImageName: "clock.badge.fill"
        )

        AppShortcut(
            intent: CheckUpcomingDosesIntent(),
            phrases: [
                "Check my doses in \(.applicationName)",
                "What's left today in \(.applicationName)",
                "What do I need to take in \(.applicationName)"
            ],
            shortTitle: "Upcoming Doses",
            systemImageName: "list.bullet.clipboard.fill"
        )

        AppShortcut(
            intent: CheckStreakIntent(),
            phrases: [
                "Check my streak in \(.applicationName)",
                "What's my streak in \(.applicationName)",
                "How many days in a row in \(.applicationName)"
            ],
            shortTitle: "Check Streak",
            systemImageName: "flame.fill"
        )
    }
}
