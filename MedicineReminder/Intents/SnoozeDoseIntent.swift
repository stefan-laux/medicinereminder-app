import AppIntents
import Foundation

/// "Snooze my Aspirin" — snoozes the next scheduled dose of a medicine by the
/// app's default snooze interval so it nudges you again shortly.
@MainActor
struct SnoozeDoseIntent: AppIntent {

    static let title: LocalizedStringResource = "Snooze Dose"

    static let description = IntentDescription(
        "Snoozes the next dose of a medicine so you're reminded again soon.",
        categoryName: "Logging",
        searchKeywords: ["snooze", "later", "remind", "delay", "dose", "medicine"]
    )

    static let openAppWhenRun = false

    @Parameter(
        title: "Medicine",
        description: "The medicine whose next dose you want to snooze.",
        requestValueDialog: "Which medicine do you want to snooze?"
    )
    var medicine: MedicineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Snooze \(\.$medicine)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try IntentSupport.medicine(for: medicine)
        let name = model.name
        let minutes = IntentSupport.defaultSnoozeMinutes

        let slot = try IntentSupport.nextScheduledTime(for: model)
        try DoseActions.snooze(
            medicineID: model.id,
            scheduledTime: slot,
            minutes: minutes,
            source: .siri,
            in: IntentSupport.context
        )

        await IntentSupport.refreshAfterMutation()
        HapticEngine.selection()

        return .result(dialog: "Okay — I'll remind you about \(name) in \(IntentSupport.relativeMinutes(minutes)).")
    }
}
