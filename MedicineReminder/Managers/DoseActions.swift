import Foundation
import SwiftData

/// Non-UI dose mutations shared by the UI layer and App Intents.
///
/// Every method runs on the `@MainActor` because it touches a SwiftData
/// `ModelContext`. They locate (or create) the `DoseLog` for a given slot and
/// set its status, persisting before returning.
@MainActor
public enum DoseActions {

    /// Log a dose as taken. If `scheduledTime` is nil the dose is treated as
    /// ad-hoc / PRN and a fresh log is created at "now".
    @discardableResult
    public static func logTaken(medicineID: UUID,
                                scheduledTime: Date?,
                                amount: Double?,
                                source: LogSource,
                                in context: ModelContext) throws -> DoseLog {
        let medicine = try requireMedicine(medicineID, in: context)
        let slot = scheduledTime ?? Date()
        let log = try resolveLog(for: medicine, scheduledTime: slot, isAdHoc: scheduledTime == nil, in: context)
        log.statusRaw = DoseStatus.taken.rawValue
        log.loggedAt = Date()
        log.amountTaken = amount
        log.sourceRaw = source.rawValue
        log.snoozedUntil = nil
        try context.save()
        return log
    }

    /// Mark a dose as skipped.
    @discardableResult
    public static func skip(medicineID: UUID,
                            scheduledTime: Date?,
                            source: LogSource,
                            in context: ModelContext) throws -> DoseLog {
        let medicine = try requireMedicine(medicineID, in: context)
        let slot = scheduledTime ?? Date()
        let log = try resolveLog(for: medicine, scheduledTime: slot, isAdHoc: scheduledTime == nil, in: context)
        log.statusRaw = DoseStatus.skipped.rawValue
        log.loggedAt = Date()
        log.amountTaken = nil
        log.sourceRaw = source.rawValue
        log.snoozedUntil = nil
        try context.save()
        return log
    }

    /// Snooze a dose by `minutes`, leaving it in a `.snoozed` state until then.
    @discardableResult
    public static func snooze(medicineID: UUID,
                              scheduledTime: Date?,
                              minutes: Int,
                              source: LogSource,
                              in context: ModelContext) throws -> DoseLog {
        let medicine = try requireMedicine(medicineID, in: context)
        let slot = scheduledTime ?? Date()
        let log = try resolveLog(for: medicine, scheduledTime: slot, isAdHoc: scheduledTime == nil, in: context)
        log.statusRaw = DoseStatus.snoozed.rawValue
        log.loggedAt = Date()
        log.snoozedUntil = Date().addingTimeInterval(TimeInterval(max(1, minutes) * 60))
        log.sourceRaw = source.rawValue
        try context.save()
        return log
    }

    /// Fuzzy resolve for Siri / search. Returns active medicines whose name (or
    /// generic name) matches `query`, sorted by match quality:
    /// exact > prefix > contains > generic-name match.
    public static func resolveMedicines(matching query: String, in context: ModelContext) throws -> [Medicine] {
        let needle = normalize(query)
        guard !needle.isEmpty else { return [] }

        let descriptor = FetchDescriptor<Medicine>(
            predicate: #Predicate { !$0.isArchived }
        )
        let all = try context.fetch(descriptor)

        let scored: [(medicine: Medicine, score: Int)] = all.compactMap { medicine in
            let name = normalize(medicine.name)
            let generic = medicine.fdaGenericName.map(normalize)

            if name == needle { return (medicine, 0) }
            if name.hasPrefix(needle) { return (medicine, 1) }
            if name.contains(needle) { return (medicine, 2) }
            if let generic, generic.contains(needle) { return (medicine, 3) }
            return nil
        }

        return scored
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                return lhs.medicine.name.localizedCaseInsensitiveCompare(rhs.medicine.name) == .orderedAscending
            }
            .map(\.medicine)
    }

    // MARK: Private helpers

    private static func requireMedicine(_ id: UUID, in context: ModelContext) throws -> Medicine {
        let descriptor = FetchDescriptor<Medicine>(predicate: #Predicate { $0.id == id })
        guard let medicine = try context.fetch(descriptor).first else {
            throw DoseActionError.medicineNotFound(id)
        }
        return medicine
    }

    /// Find the existing log for this medicine + slot, or insert a new one.
    /// Ad-hoc doses always create a new log so PRN history is never collapsed.
    private static func resolveLog(for medicine: Medicine,
                                   scheduledTime: Date,
                                   isAdHoc: Bool,
                                   in context: ModelContext) throws -> DoseLog {
        if !isAdHoc {
            let medicineID = medicine.id
            // Match within the same minute to tolerate sub-second slot drift.
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

    private static func normalize(_ string: String) -> String {
        string
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Errors surfaced by dose mutations.
public enum DoseActionError: LocalizedError {
    case medicineNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .medicineNotFound:
            return String(localized: "That medicine could no longer be found.")
        }
    }
}
