import AppIntents
import Foundation

/// "Skip my Aspirin" — marks the next scheduled dose of a medicine as skipped.
@MainActor
struct SkipDoseIntent: AppIntent {

    static let title: LocalizedStringResource = "Skip Dose"

    static let description = IntentDescription(
        "Marks the next scheduled dose of a medicine as skipped.",
        categoryName: "Logging",
        searchKeywords: ["skip", "skipped", "miss", "dose", "medicine", "medication"]
    )

    static let openAppWhenRun = false

    @Parameter(
        title: "Medicine",
        description: "The medicine whose next dose you want to skip.",
        requestValueDialog: "Which medicine do you want to skip?"
    )
    var medicine: MedicineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Skip \(\.$medicine)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try IntentSupport.medicine(for: medicine)
        let name = model.name

        // Target the next scheduled slot; if there's nothing scheduled the skip
        // is recorded ad-hoc at "now" so the action still has an effect.
        let slot = try IntentSupport.nextScheduledTime(for: model)
        try DoseActions.skip(
            medicineID: model.id,
            scheduledTime: slot,
            source: .siri,
            in: IntentSupport.context
        )

        await IntentSupport.refreshAfterMutation()
        HapticEngine.skipped()

        if let slot {
            let when = IntentSupport.spokenTime(slot)
            return .result(dialog: "Okay — \(name) at \(when) marked as skipped.")
        } else {
            return .result(dialog: "Okay — \(name) marked as skipped.")
        }
    }
}
