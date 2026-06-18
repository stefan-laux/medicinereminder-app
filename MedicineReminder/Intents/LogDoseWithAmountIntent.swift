import AppIntents
import Foundation

/// "Log 2 tablets of Aspirin" — logs a dose as taken with a quantity override
/// that differs from the medicine's default dosage amount.
struct LogDoseWithAmountIntent: AppIntent {

    static let title: LocalizedStringResource = "Log Dose with Amount"

    static let description = IntentDescription(
        "Records a taken dose with a specific amount, overriding the default dosage.",
        categoryName: "Logging",
        searchKeywords: ["log", "amount", "quantity", "dose", "tablets", "medicine"]
    )

    static let openAppWhenRun = false

    @Parameter(
        title: "Amount",
        description: "How much you took (in the medicine's unit).",
        requestValueDialog: "How much did you take?"
    )
    var amount: Double

    @Parameter(
        title: "Medicine",
        description: "The medicine you took.",
        requestValueDialog: "Which medicine did you take?"
    )
    var medicine: MedicineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$amount) of \(\.$medicine)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try IntentSupport.medicine(for: medicine)
        let name = model.name
        let unit = model.unit
        // Round to whole units when the unit doesn't allow decimals (e.g. tablets).
        let resolved = unit.allowsDecimal ? amount : amount.rounded()
        let spokenAmount = unit.formatted(resolved)

        let slot = try IntentSupport.nextScheduledTime(for: model)
        try DoseActions.logTaken(
            medicineID: model.id,
            scheduledTime: slot,
            amount: resolved,
            source: .siri,
            in: IntentSupport.context
        )

        await IntentSupport.refreshAfterMutation()
        HapticEngine.taken()

        return .result(dialog: "Logged \(spokenAmount) of \(name) as taken.")
    }
}
