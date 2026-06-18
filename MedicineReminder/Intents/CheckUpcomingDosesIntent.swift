import AppIntents
import Foundation

/// "What medicine do I still need to take today?" — speaks the list of doses
/// still pending for the rest of today.
struct CheckUpcomingDosesIntent: AppIntent {

    static let title: LocalizedStringResource = "Check Upcoming Doses"

    static let description = IntentDescription(
        "Tells you which doses you still have left today.",
        categoryName: "Status",
        searchKeywords: ["upcoming", "today", "remaining", "next", "doses", "schedule"]
    )

    static let openAppWhenRun = false

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let medicines = try IntentSupport.activeMedicines()
        let logs = try IntentSupport.allLogs()

        let now = Date()
        let todaysEvents = ScheduleEngine.events(for: medicines, logs: logs, on: now)

        // Pending items whose slot time is now or later today.
        let remaining: [(time: Date, name: String, dosage: String)] = todaysEvents
            .filter { $0.time >= startOfMinute(now) }
            .flatMap { event in
                event.items
                    .filter { $0.status == .pending }
                    .map { (time: event.time, name: $0.name, dosage: $0.dosageDescription) }
            }
            .sorted { $0.time < $1.time }

        guard !remaining.isEmpty else {
            return .result(dialog: "You're all caught up — no more doses scheduled for today.")
        }

        let phrases = remaining.map { entry in
            "\(entry.name) \(entry.dosage) at \(IntentSupport.spokenTime(entry.time))"
        }
        let list = phrases.formatted(.list(type: .and))
        let lead = remaining.count == 1
            ? String(localized: "You have 1 dose left today: ")
            : String(localized: "You have \(remaining.count) doses left today: ")

        return .result(dialog: "\(lead)\(list).")
    }

    /// Truncate to the start of the current minute so a dose due "now" still counts.
    private func startOfMinute(_ date: Date) -> Date {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: comps) ?? date
    }
}
