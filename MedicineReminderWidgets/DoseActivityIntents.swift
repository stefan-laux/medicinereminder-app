//
//  DoseActivityIntents.swift
//  MedicineReminderWidgets
//
//  Interactive App Intents backing the Live Activity (and any widget) Take /
//  Skip buttons. They conform to `LiveActivityIntent` so they execute in this
//  extension's process and can update the shared SwiftData store immediately.
//
//  The widget extension does NOT link the app target's `DoseActions`, so the
//  dose mutation is implemented here directly against the shared App Group
//  store, mirroring `DoseActions` semantics (locate-or-create the log for the
//  slot, set its status, save). All SwiftData work is on the @MainActor.
//

import AppIntents
import Foundation
import SwiftData
import WidgetKit

// MARK: - Take

/// Marks a specific medicine's dose at a given slot as taken from the Live
/// Activity / widget.
struct TakeDoseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Take Dose"
    static let description = IntentDescription("Marks a scheduled dose as taken.")
    /// Run in-app/in-extension so the action is immediate; don't open the app.
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Medicine ID")
    var medicineID: String

    /// Slot time as a Unix timestamp (seconds). 0 == ad-hoc / now.
    @Parameter(title: "Scheduled Time")
    var scheduledEpoch: Double

    init() {}

    init(medicineID: UUID, scheduledTime: Date?) {
        self.medicineID = medicineID.uuidString
        self.scheduledEpoch = scheduledTime?.timeIntervalSince1970 ?? 0
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try DoseActivityMutations.apply(
            status: .taken,
            medicineIDString: medicineID,
            scheduledEpoch: scheduledEpoch
        )
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Skip

/// Marks a specific medicine's dose at a given slot as skipped.
struct SkipDoseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Dose"
    static let description = IntentDescription("Marks a scheduled dose as skipped.")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Medicine ID")
    var medicineID: String

    @Parameter(title: "Scheduled Time")
    var scheduledEpoch: Double

    init() {}

    init(medicineID: UUID, scheduledTime: Date?) {
        self.medicineID = medicineID.uuidString
        self.scheduledEpoch = scheduledTime?.timeIntervalSince1970 ?? 0
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try DoseActivityMutations.apply(
            status: .skipped,
            medicineIDString: medicineID,
            scheduledEpoch: scheduledEpoch
        )
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

// MARK: - Shared mutation

/// Dose mutation helper local to the widget extension. Mirrors the app-target
/// `DoseActions` logic but operates on the shared store without depending on
/// app-only code.
@MainActor
enum DoseActivityMutations {

    enum MutationError: LocalizedError {
        case invalidMedicineID
        case medicineNotFound

        var errorDescription: String? {
            switch self {
            case .invalidMedicineID: return String(localized: "That dose reference was invalid.")
            case .medicineNotFound: return String(localized: "That medicine could no longer be found.")
            }
        }
    }

    static func apply(status: DoseStatus, medicineIDString: String, scheduledEpoch: Double) throws {
        guard let medicineID = UUID(uuidString: medicineIDString) else {
            throw MutationError.invalidMedicineID
        }
        let context = SharedModelContainer.shared.mainContext

        let descriptor = FetchDescriptor<Medicine>(predicate: #Predicate { $0.id == medicineID })
        guard let medicine = try context.fetch(descriptor).first else {
            throw MutationError.medicineNotFound
        }

        let isAdHoc = scheduledEpoch == 0
        let slot = isAdHoc ? Date() : Date(timeIntervalSince1970: scheduledEpoch)
        let log = try resolveLog(for: medicine, scheduledTime: slot, isAdHoc: isAdHoc, in: context)

        log.statusRaw = status.rawValue
        log.loggedAt = Date()
        log.amountTaken = status == .taken ? medicine.dosageAmount : nil
        log.sourceRaw = LogSource.liveActivity.rawValue
        log.snoozedUntil = nil
        try context.save()
    }

    /// Locate the existing log for this medicine + slot (matched within a
    /// 1-minute window to tolerate sub-second drift) or insert a fresh one.
    private static func resolveLog(for medicine: Medicine,
                                   scheduledTime: Date,
                                   isAdHoc: Bool,
                                   in context: ModelContext) throws -> DoseLog {
        if !isAdHoc {
            let medicineID = medicine.id
            let lower = scheduledTime.addingTimeInterval(-30)
            let upper = scheduledTime.addingTimeInterval(30)
            let descriptor = FetchDescriptor<DoseLog>(
                predicate: #Predicate { log in
                    log.medicine?.id == medicineID
                        && log.scheduledTime >= lower
                        && log.scheduledTime <= upper
                }
            )
            if let existing = try context.fetch(descriptor).first {
                return existing
            }
        }
        let log = DoseLog(scheduledTime: scheduledTime, status: .pending)
        log.medicine = medicine
        context.insert(log)
        return log
    }
}
