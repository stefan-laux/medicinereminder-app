import Foundation
import SwiftData

// SampleData.swift  (preview/demo seed — used by #Preview and first-run optional)
@MainActor public enum SampleData {

    /// Seed a context with a few realistic medicines, varied schedules, and ~2 weeks of dose logs
    /// so previews and analytics render with believable data.
    public static func seed(_ context: ModelContext) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        // History window: the past 14 days through today.
        guard let windowStart = calendar.date(byAdding: .day, value: -13, to: today) else { return }

        let medicines = makeMedicines(referenceDay: today, calendar: calendar)
        for medicine in medicines {
            context.insert(medicine)
        }

        // Generate logs across the history window for every scheduled occurrence,
        // skipping the future (after now) so "today" still has pending doses to act on.
        let now = Date()
        var rng = SeededGenerator(seed: 0xC0FFEE)

        for medicine in medicines {
            for schedule in medicine.schedules ?? [] {
                var day = windowStart
                var safety = 0
                while day <= today && safety < 400 {
                    for occurrence in ScheduleEngine.occurrences(for: schedule, on: day, calendar: calendar) where occurrence <= now {
                        let status = simulateStatus(using: &rng)
                        guard status != .pending else { continue }
                        // Logged a little after the slot for realism.
                        let logged = occurrence.addingTimeInterval(Double(Int.random(in: -300...1200, using: &rng)))
                        let log = DoseLog(
                            scheduledTime: occurrence,
                            loggedAt: logged,
                            status: status,
                            amountTaken: status == .taken ? medicine.dosageAmount : nil,
                            source: .manual
                        )
                        log.medicine = medicine
                        context.insert(log)
                    }
                    guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
                    day = next
                    safety += 1
                }
            }
        }

        try? context.save()
    }

    // MARK: - Medicine fixtures

    private static func makeMedicines(referenceDay: Date, calendar: Calendar) -> [Medicine] {
        let start = calendar.date(byAdding: .day, value: -30, to: referenceDay) ?? referenceDay

        // 1. Lisinopril — once daily, morning. (FDA-matched)
        let lisinopril = Medicine(
            name: "Lisinopril",
            dosageAmount: 10,
            unit: .mg,
            color: .blue,
            iconName: "heart.fill",
            notes: "Take in the morning with water.",
            isCustom: false,
            fdaGenericName: "lisinopril",
            createdAt: start,
            sortIndex: 0
        )
        let lisinoprilSchedule = DoseSchedule(
            frequency: .once,
            timeSlots: [TimeOfDay(hour: 8, minute: 0)],
            startDate: start
        )
        lisinoprilSchedule.medicine = lisinopril
        lisinopril.schedules = [lisinoprilSchedule]

        // 2. Metformin — twice daily, with meals. (FDA-matched)
        let metformin = Medicine(
            name: "Metformin",
            dosageAmount: 500,
            unit: .mg,
            color: .emerald,
            iconName: "pills.fill",
            notes: "Take with breakfast and dinner.",
            isCustom: false,
            fdaGenericName: "metformin hydrochloride",
            createdAt: start,
            sortIndex: 1
        )
        let metforminSchedule = DoseSchedule(
            frequency: .twiceDaily,
            timeSlots: [TimeOfDay(hour: 8, minute: 30), TimeOfDay(hour: 19, minute: 0)],
            startDate: start
        )
        metforminSchedule.medicine = metformin
        metformin.schedules = [metforminSchedule]

        // 3. Vitamin D3 — specific days (Mon/Wed/Fri), midday. (custom)
        let vitaminD = Medicine(
            name: "Vitamin D3",
            dosageAmount: 1,
            unit: .capsule,
            color: .amber,
            iconName: "sun.max.fill",
            notes: "Supplement — Mon/Wed/Fri at lunch.",
            isCustom: true,
            fdaGenericName: nil,
            createdAt: start,
            sortIndex: 2
        )
        // Calendar weekday: 1=Sun ... 7=Sat. Monday=2, Wednesday=4, Friday=6.
        let vitaminDSchedule = DoseSchedule(
            frequency: .specificDays,
            timeSlots: [TimeOfDay(hour: 12, minute: 30)],
            weekdays: [2, 4, 6],
            startDate: start
        )
        vitaminDSchedule.medicine = vitaminD
        vitaminD.schedules = [vitaminDSchedule]

        // 4. Ibuprofen — as needed (PRN). (FDA-matched)
        let ibuprofen = Medicine(
            name: "Ibuprofen",
            dosageAmount: 200,
            unit: .tablet,
            color: .coral,
            iconName: "bandage.fill",
            notes: "For pain as needed, max 3 per day.",
            isCustom: false,
            fdaGenericName: "ibuprofen",
            createdAt: start,
            sortIndex: 3
        )
        let ibuprofenSchedule = DoseSchedule(
            frequency: .asNeeded,
            startDate: start
        )
        ibuprofenSchedule.medicine = ibuprofen
        ibuprofen.schedules = [ibuprofenSchedule]

        return [lisinopril, metformin, vitaminD, ibuprofen]
    }

    // MARK: - Status simulation

    /// Weighted toward taken so adherence/streak views look healthy but not perfect.
    private static func simulateStatus(using rng: inout SeededGenerator) -> DoseStatus {
        let roll = Int.random(in: 0..<100, using: &rng)
        switch roll {
        case 0..<82: return .taken
        case 82..<90: return .skipped
        case 90..<94: return .snoozed
        default: return .pending   // left unlogged (becomes a real pending dose)
        }
    }

    /// Small deterministic PRNG so previews/snapshots are stable across runs.
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
        mutating func next() -> UInt64 {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return state
        }
    }
}
