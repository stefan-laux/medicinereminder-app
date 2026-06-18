import AppIntents
import Foundation

/// Flagship Siri action: "Log my Aspirin" / "I took my Lisinopril".
///
/// Logs the medicine's next scheduled dose (or an ad-hoc dose if nothing is
/// scheduled) as taken, right now. Conforms to `PredictableIntent` so the system
/// can proactively surface it around dose times.
struct LogDoseTakenIntent: AppIntent, PredictableIntent {

    static let title: LocalizedStringResource = "Log Dose as Taken"

    static let description = IntentDescription(
        "Records that you've taken a medicine right now.",
        categoryName: "Logging",
        searchKeywords: ["log", "took", "taken", "dose", "medicine", "medication"]
    )

    /// Opening the app is unnecessary — confirm entirely through Siri.
    static let openAppWhenRun = false

    @Parameter(
        title: "Medicine",
        description: "The medicine you took.",
        requestValueDialog: "Which medicine did you take?"
    )
    var medicine: MedicineEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$medicine) as taken")
    }

    // MARK: PredictableIntent

    static var predictionConfiguration: some IntentPredictionConfiguration {
        IntentPrediction(parameters: \.$medicine) { medicine in
            DisplayRepresentation(
                title: "Log \(medicine.name) as taken",
                subtitle: "\(medicine.dosageDescription)"
            )
        }
    }

    // MARK: Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let model = try IntentSupport.medicine(for: medicine)
        let dosage = model.dosageDescription
        let name = model.name

        let slot = try IntentSupport.nextScheduledTime(for: model)
        try DoseActions.logTaken(
            medicineID: model.id,
            scheduledTime: slot,
            amount: nil,
            source: .siri,
            in: IntentSupport.context
        )

        await IntentSupport.refreshAfterMutation()
        HapticEngine.taken()

        return .result(dialog: "Got it — \(name) \(dosage) logged as taken.")
    }
}
