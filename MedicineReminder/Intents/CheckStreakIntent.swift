import AppIntents
import Foundation

/// "What's my streak?" — speaks the current adherence streak.
@MainActor
struct CheckStreakIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Streak"

    static let description = IntentDescription(
        "Tells you your current medicine-taking streak.",
        categoryName: "Status",
        searchKeywords: ["streak", "adherence", "days", "progress", "consistency"]
    )

    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let medicines = try IntentSupport.activeMedicines()
        let logs = try IntentSupport.allLogs()

        let current = StreakCalculator.currentStreak(medicines: medicines, logs: logs, asOf: Date())

        let dialog: IntentDialog
        switch current {
        case 0:
            dialog = "You don't have a streak going yet — take today's doses to start one."
        case 1:
            dialog = "You're on a 1-day streak. Keep it up!"
        default:
            dialog = "You're on a \(current)-day streak. Great work!"
        }

        return .result(dialog: dialog)
    }
}
