# MedicineReminder — Engineering Contract (SINGLE SOURCE OF TRUTH)

> Every agent MUST read this file fully before writing code, and MUST conform to the
> exact type names, signatures, file locations, and bundle identifiers defined here.
> If something you need is not defined here, define it INSIDE YOUR OWN folder and keep
> it `private`/`fileprivate` — never redefine a shared symbol listed below.

## 0. Platform / Build facts
- **Min deployment target: iOS 26.0** (WWDC 2025 SDK — Liquid Glass, App Intents 2.0).
- Swift 6 language mode, strict concurrency. Prefer `Sendable`, `@MainActor` where stated.
- Built on macOS with Xcode 26 via XcodeGen (`project.yml` at repo root). Nothing compiles on the authoring machine (Windows) — write code that is *inspection-correct*.
- **Bundle IDs (placeholders — user replaces prefix/team):**
  - App: `com.example.medicinereminder`
  - Widget extension: `com.example.medicinereminder.widgets`
  - **App Group: `group.com.example.medicinereminder`** (shared SwiftData store).
- Two targets only:
  1. `MedicineReminder` (application) — sources: `MedicineReminder/` + `Shared/`.
  2. `MedicineReminderWidgets` (app-extension, WidgetBundle = widgets **and** Live Activity) — sources: `MedicineReminderWidgets/` + `Shared/`.
- App Intents live **in the app target** (no separate intents extension). Siri reaches them via `AppShortcutsProvider`.

## 1. Folder ownership (one writer per file — NO two agents edit the same file)
```
Shared/Models/          @Model SwiftData classes
Shared/Enums/           value enums + small Codable structs
Shared/Persistence/     shared ModelContainer (App Group), AppGroup constants
Shared/Activity/        DoseActivityAttributes (ActivityKit, shared app+widget)
Shared/Entities/        MedicineEntity (AppEntity) + queries
Shared/Logic/           ScheduleEngine, StreakCalculator, AdherenceCalculator, DoseEvent value types  (PURE, no UIKit, no @MainActor)
Shared/DesignSystem/    Theme, color tokens, typography, GlassComponents, reusable UI components, Color(hex:)  (SwiftUI only; usable by widgets)
MedicineReminder/App/        App entry, RootView, MainTabView, LaunchAnimationView, AppDelegate
MedicineReminder/Services/   NotificationService, FDAService, LiveActivityService, ExportService
MedicineReminder/Managers/   DoseManager (@Observable UI store), DoseActions (non-UI mutations)
MedicineReminder/Haptics/    HapticEngine
MedicineReminder/Views/Home/      home timeline screen
MedicineReminder/Views/AddEdit/   add/edit medicine flow + FDA autocomplete UI
MedicineReminder/Views/Plans/     calendar/plan overview
MedicineReminder/Views/Analytics/ streak + charts + heatmap
MedicineReminder/Views/Settings/  settings
MedicineReminder/Views/Components/ app-only composite views (DoseEventCard, StreakRing host, etc.)
MedicineReminder/Intents/    App Intents + AppShortcutsProvider
MedicineReminderWidgets/     WidgetBundle, widgets, Live Activity UI, WidgetDataProvider
```

## 2. Enums & small value types — `Shared/Enums/` (COPY VERBATIM)

```swift
import SwiftUI

// DosageUnit.swift
public enum DosageUnit: String, CaseIterable, Codable, Identifiable, Sendable {
    case mg, mcg, g, ml, tablet, capsule, drops, puff, unit, patch, spray, suppository
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .mg: "milligrams"; case .mcg: "micrograms"; case .g: "grams"
        case .ml: "milliliters"; case .tablet: "tablet"; case .capsule: "capsule"
        case .drops: "drops"; case .puff: "puff"; case .unit: "unit"
        case .patch: "patch"; case .spray: "spray"; case .suppository: "suppository"
        }
    }
    public var abbreviation: String {
        switch self {
        case .mg: "mg"; case .mcg: "mcg"; case .g: "g"; case .ml: "ml"
        case .tablet: "tab"; case .capsule: "cap"; case .drops: "drops"
        case .puff: "puff"; case .unit: "unit"; case .patch: "patch"
        case .spray: "spray"; case .suppository: "supp"
        }
    }
    /// Whether the amount field should allow decimals.
    public var allowsDecimal: Bool {
        switch self { case .tablet, .capsule, .drops, .puff, .patch, .suppository: false; default: true }
    }
    /// Pluralize for spoken/written output, e.g. "2 tablets".
    public func formatted(_ amount: Double) -> String {
        let n = amount == amount.rounded() ? String(Int(amount)) : String(format: "%.2g", amount)
        switch self {
        case .mg, .mcg, .g, .ml: return "\(n) \(abbreviation)"
        case .tablet, .capsule, .drops, .puff, .unit, .patch, .spray, .suppository:
            let unit = amount == 1 ? displayName : displayName + "s"
            return "\(n) \(unit)"
        }
    }
}

// ScheduleFrequencyType.swift
public enum ScheduleFrequencyType: String, CaseIterable, Codable, Identifiable, Sendable {
    case once              // one time per day at a single time
    case twiceDaily        // two times per day
    case threeTimesDaily   // three times per day
    case everyNHours       // interval-based (use intervalHours)
    case specificDays      // chosen weekdays at the time slots
    case asNeeded          // PRN — no scheduled reminders, manual logging only
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .once: "Once daily"; case .twiceDaily: "Twice daily"
        case .threeTimesDaily: "3 times daily"; case .everyNHours: "Every N hours"
        case .specificDays: "Specific days"; case .asNeeded: "As needed"
        }
    }
}

// DoseStatus.swift
public enum DoseStatus: String, Codable, Sendable, CaseIterable {
    case pending, taken, skipped, snoozed
    public var label: String {
        switch self { case .pending: "Pending"; case .taken: "Taken"; case .skipped: "Skipped"; case .snoozed: "Snoozed" }
    }
    public var systemImage: String {
        switch self { case .pending: "circle"; case .taken: "checkmark.circle.fill"
        case .skipped: "xmark.circle.fill"; case .snoozed: "clock.badge.fill" }
    }
}

// LogSource.swift
public enum LogSource: String, Codable, Sendable {
    case manual, siri, notification, liveActivity, widget, auto
}

// TimeOfDay.swift  — Codable struct stored in SwiftData arrays
public struct TimeOfDay: Codable, Hashable, Sendable, Comparable, Identifiable {
    public var hour: Int      // 0...23
    public var minute: Int    // 0...59
    public init(hour: Int, minute: Int) { self.hour = hour; self.minute = minute }
    public var id: Int { hour * 60 + minute }
    public static func < (l: TimeOfDay, r: TimeOfDay) -> Bool { l.id < r.id }
    /// Resolve to a concrete Date on the given day using the supplied calendar.
    public func date(on day: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
    public var displayString: String {
        let c = DateComponents(hour: hour, minute: minute)
        let d = Calendar.current.date(from: c) ?? Date()
        return d.formatted(date: .omitted, time: .shortened)
    }
}

// MedicineColor.swift  — programmatic palette (NO asset catalog dependency)
public enum MedicineColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case coral, tangerine, amber, lime, emerald, teal, sky, blue, indigo, violet, magenta, rose, slate
    public var id: String { rawValue }
    public static let `default`: MedicineColor = .blue
    public var displayName: String { rawValue.capitalized }
    /// Hex for light appearance. DesignSystem provides `Color(hex:)`.
    public var lightHex: UInt {
        switch self {
        case .coral: 0xFF6B6B; case .tangerine: 0xFF8C42; case .amber: 0xFFB400
        case .lime: 0x9BCF53; case .emerald: 0x2ECC71; case .teal: 0x1ABC9C
        case .sky: 0x4FC3F7; case .blue: 0x4D8AF0; case .indigo: 0x5B6CF0
        case .violet: 0x8E7CFF; case .magenta: 0xE056C1; case .rose: 0xF06292; case .slate: 0x7E8AA2
        }
    }
    /// Slightly brighter hex for dark appearance.
    public var darkHex: UInt {
        switch self {
        case .coral: 0xFF8585; case .tangerine: 0xFFA15C; case .amber: 0xFFC93C
        case .lime: 0xB5E06F; case .emerald: 0x4BE08C; case .teal: 0x37D7B6
        case .sky: 0x6FD0FF; case .blue: 0x6FA0FF; case .indigo: 0x7C8CFF
        case .violet: 0xA594FF; case .magenta: 0xF06FD6; case .rose: 0xFF7BA6; case .slate: 0x9AA6BE
        }
    }
    // `color` / `gradient` are provided by DesignSystem (MedicineColor+UI.swift) as a SwiftUI extension.
}
```

## 3. SwiftData models — `Shared/Models/` (COPY VERBATIM; do not change property names)

```swift
import Foundation
import SwiftData

// Medicine.swift
@Model
public final class Medicine {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var dosageAmount: Double
    public var unitRaw: String            // DosageUnit.rawValue
    public var colorRaw: String           // MedicineColor.rawValue
    public var iconName: String           // SF Symbol
    public var notes: String
    public var isCustom: Bool             // true when no FDA match
    public var fdaGenericName: String?
    public var createdAt: Date
    public var isArchived: Bool
    public var sortIndex: Int

    @Relationship(deleteRule: .cascade, inverse: \DoseSchedule.medicine)
    public var schedules: [DoseSchedule]
    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medicine)
    public var logs: [DoseLog]

    public init(id: UUID = UUID(), name: String, dosageAmount: Double, unit: DosageUnit,
                color: MedicineColor = .default, iconName: String = "pills.fill", notes: String = "",
                isCustom: Bool = false, fdaGenericName: String? = nil, createdAt: Date = Date(),
                isArchived: Bool = false, sortIndex: Int = 0) {
        self.id = id; self.name = name; self.dosageAmount = dosageAmount
        self.unitRaw = unit.rawValue; self.colorRaw = color.rawValue; self.iconName = iconName
        self.notes = notes; self.isCustom = isCustom; self.fdaGenericName = fdaGenericName
        self.createdAt = createdAt; self.isArchived = isArchived; self.sortIndex = sortIndex
        self.schedules = []; self.logs = []
    }

    // Computed convenience (non-stored)
    public var unit: DosageUnit { DosageUnit(rawValue: unitRaw) ?? .mg }
    public var color: MedicineColor { MedicineColor(rawValue: colorRaw) ?? .default }
    public var dosageDescription: String { unit.formatted(dosageAmount) }   // e.g. "50 mg"
}

// DoseSchedule.swift
@Model
public final class DoseSchedule {
    @Attribute(.unique) public var id: UUID
    public var medicine: Medicine?
    public var frequencyRaw: String       // ScheduleFrequencyType.rawValue
    public var timeSlots: [TimeOfDay]     // sorted; the times of day reminders fire
    public var intervalHours: Int         // used when frequency == .everyNHours
    public var weekdays: [Int]            // 1...7 (Calendar weekday); used when .specificDays; empty == every day
    public var startDate: Date
    public var endDate: Date?
    public var isActive: Bool

    public init(id: UUID = UUID(), frequency: ScheduleFrequencyType, timeSlots: [TimeOfDay] = [],
                intervalHours: Int = 8, weekdays: [Int] = [], startDate: Date = Date(),
                endDate: Date? = nil, isActive: Bool = true) {
        self.id = id; self.frequencyRaw = frequency.rawValue
        self.timeSlots = timeSlots.sorted(); self.intervalHours = intervalHours
        self.weekdays = weekdays; self.startDate = startDate; self.endDate = endDate; self.isActive = isActive
    }
    public var frequency: ScheduleFrequencyType { ScheduleFrequencyType(rawValue: frequencyRaw) ?? .once }
}

// DoseLog.swift
@Model
public final class DoseLog {
    @Attribute(.unique) public var id: UUID
    public var medicine: Medicine?
    public var scheduledTime: Date        // the slot this log belongs to (== loggedAt for PRN/ad-hoc)
    public var loggedAt: Date
    public var statusRaw: String          // DoseStatus.rawValue
    public var amountTaken: Double?       // quantity override; nil == use medicine.dosageAmount
    public var sourceRaw: String          // LogSource.rawValue
    public var snoozedUntil: Date?

    public init(id: UUID = UUID(), scheduledTime: Date, loggedAt: Date = Date(),
                status: DoseStatus, amountTaken: Double? = nil, source: LogSource = .manual,
                snoozedUntil: Date? = nil) {
        self.id = id; self.scheduledTime = scheduledTime; self.loggedAt = loggedAt
        self.statusRaw = status.rawValue; self.amountTaken = amountTaken
        self.sourceRaw = source.rawValue; self.snoozedUntil = snoozedUntil
    }
    public var status: DoseStatus { DoseStatus(rawValue: statusRaw) ?? .pending }
    public var source: LogSource { LogSource(rawValue: sourceRaw) ?? .manual }
}
```

## 4. Persistence — `Shared/Persistence/`

```swift
// AppGroup.swift
public enum AppGroup {
    public static let identifier = "group.com.example.medicinereminder"
}

// SharedModelContainer.swift
import SwiftData
public enum SharedModelContainer {
    public static let schema = Schema([Medicine.self, DoseSchedule.self, DoseLog.self])
    /// App Group-backed container so the widget extension and app share one store.
    public static let shared: ModelContainer = {
        let config = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier)
        )
        do { return try ModelContainer(for: schema, configurations: config) }
        catch { fatalError("Could not create ModelContainer: \(error)") }
    }()
    /// In-memory container for previews/tests, prefilled via SampleData.
    @MainActor public static func preview() -> ModelContainer { /* impl: in-memory + SampleData.seed */ }
}

// SampleData.swift  (preview/demo seed — used by #Preview and first-run optional)
@MainActor public enum SampleData {
    public static func seed(_ context: ModelContext) { /* a few medicines w/ schedules + logs */ }
}
```

## 5. Logic (PURE, Sendable, no UI) — `Shared/Logic/`

```swift
import Foundation

// DoseEvent.swift — a time slot grouping one-or-more medicines due together
public struct DoseEvent: Identifiable, Hashable, Sendable {
    public let id: String              // stable: ISO slot time, e.g. "2026-06-18T08:00"
    public let time: Date
    public var items: [DoseEventItem]
    public init(id: String, time: Date, items: [DoseEventItem])
}
public struct DoseEventItem: Identifiable, Hashable, Sendable {
    public let id: UUID                // == medicine.id (a medicine appears once per slot)
    public let medicineID: UUID
    public let scheduleID: UUID
    public let name: String
    public let dosageDescription: String
    public let colorRaw: String
    public let iconName: String
    public var status: DoseStatus      // resolved from matching DoseLog, else .pending
    public var logID: UUID?
}

// ScheduleEngine.swift
public enum ScheduleEngine {
    /// Concrete dose times for a single schedule on a given calendar day (respects start/end/weekdays/freq).
    public static func occurrences(for schedule: DoseSchedule, on day: Date, calendar: Calendar = .current) -> [Date]
    /// All grouped dose events for the medicines on a given day, sorted by time. Pending/looked-up status applied from `logs`.
    public static func events(for medicines: [Medicine], logs: [DoseLog], on day: Date, calendar: Calendar = .current) -> [DoseEvent]
    /// Events across an inclusive day range (for Plans/timeline).
    public static func events(for medicines: [Medicine], logs: [DoseLog], from: Date, to: Date, calendar: Calendar = .current) -> [DoseEvent]
    /// Next upcoming (or currently-due) event strictly relevant after `date`. Used by widgets/intents/Live Activity.
    public static func nextEvent(for medicines: [Medicine], logs: [DoseLog], after date: Date, calendar: Calendar = .current) -> DoseEvent?
    /// Slot identity helper — MUST be used everywhere a slot id is needed so ids match across modules.
    public static func slotID(_ time: Date) -> String
}

// StreakCalculator.swift
public enum StreakCalculator {
    /// Consecutive days (ending at `asOf`) where every scheduled dose that day was taken. PRN ignored.
    public static func currentStreak(medicines: [Medicine], logs: [DoseLog], asOf: Date = Date(), calendar: Calendar = .current) -> Int
    public static func longestStreak(medicines: [Medicine], logs: [DoseLog], asOf: Date = Date(), calendar: Calendar = .current) -> Int
}

// AdherenceCalculator.swift
public struct AdherenceStat: Sendable, Hashable { public let taken: Int; public let scheduled: Int; public var rate: Double { scheduled == 0 ? 0 : Double(taken)/Double(scheduled) } }
public enum AdherenceCalculator {
    public static func overall(medicines: [Medicine], logs: [DoseLog], from: Date, to: Date, calendar: Calendar = .current) -> AdherenceStat
    public static func perMedicine(medicines: [Medicine], logs: [DoseLog], from: Date, to: Date, calendar: Calendar = .current) -> [UUID: AdherenceStat]
    public static func daily(medicines: [Medicine], logs: [DoseLog], from: Date, to: Date, calendar: Calendar = .current) -> [(day: Date, stat: AdherenceStat)]
}
```

## 6. ActivityKit — `Shared/Activity/DoseActivityAttributes.swift` (shared app + widget)

```swift
import ActivityKit
import Foundation
public struct DoseActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var medicines: [Item]
        public var takenCount: Int
        public var totalCount: Int
        public struct Item: Codable, Hashable, Identifiable {
            public var id: String          // medicineID uuid string
            public var name: String
            public var dosage: String
            public var colorRaw: String
            public var iconName: String
            public var statusRaw: String   // DoseStatus.rawValue
        }
    }
    public var eventID: String             // == DoseEvent.id (slot id)
    public var slotTime: Date
    public var title: String               // e.g. "Morning dose"
}
```

## 7. AppEntity — `Shared/Entities/MedicineEntity.swift`

```swift
import AppIntents
public struct MedicineEntity: AppEntity, Identifiable {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Medicine"
    public static var defaultQuery = MedicineEntityQuery()
    public var id: UUID
    public var name: String
    public var dosageDescription: String
    public var colorRaw: String
    public var iconName: String
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(dosageDescription)")
    }
}
// MedicineEntityQuery conforms to EntityQuery + EntityStringQuery; fetches from SharedModelContainer.shared
// (use a @MainActor ModelContext). entities(matching:) does case/diacritic-insensitive fuzzy match on name.
public struct MedicineEntityQuery: EntityQuery, EntityStringQuery { /* per contract */ }
```

## 8. App-target service / manager APIs (consumers code against these signatures)

```swift
// MedicineReminder/Managers/DoseActions.swift  — non-UI mutations usable from Intents + UI
@MainActor public enum DoseActions {
    @discardableResult public static func logTaken(medicineID: UUID, scheduledTime: Date?, amount: Double?, source: LogSource, in context: ModelContext) throws -> DoseLog
    @discardableResult public static func skip(medicineID: UUID, scheduledTime: Date?, source: LogSource, in context: ModelContext) throws -> DoseLog
    @discardableResult public static func snooze(medicineID: UUID, scheduledTime: Date?, minutes: Int, source: LogSource, in context: ModelContext) throws -> DoseLog
    /// Fuzzy resolve for Siri: returns matches sorted by score (exact, prefix, contains, generic name).
    public static func resolveMedicines(matching query: String, in context: ModelContext) throws -> [Medicine]
}

// MedicineReminder/Managers/DoseManager.swift — @Observable UI store, owns refresh side-effects
@MainActor @Observable public final class DoseManager {
    public init(context: ModelContext)
    public var medicines: [Medicine] { get }
    public var todaysEvents: [DoseEvent] { get }
    public var currentStreak: Int { get }
    public var longestStreak: Int { get }
    public func reload()
    public func markTaken(_ item: DoseEventItem, amount: Double?)   // calls DoseActions + Notif + LiveActivity + Haptics
    public func skip(_ item: DoseEventItem)
    public func snooze(_ item: DoseEventItem)
    public func addMedicine(_ medicine: Medicine)                   // inserts + schedules notifications
    public func update(_ medicine: Medicine)
    public func archive(_ medicine: Medicine)
}

// MedicineReminder/Services/NotificationService.swift
@MainActor public final class NotificationService {
    public static let shared: NotificationService
    public func requestAuthorization() async -> Bool
    public func registerCategories()                               // TAKE / SKIP / SNOOZE actions
    public func rescheduleAll(medicines: [Medicine]) async         // wipes + reschedules next ~64 notifications
    public func cancel(for medicineID: UUID) async
    public func scheduleWeeklySummary(enabled: Bool, weekday: Int, hour: Int) async
}
// Notification identifiers, category/action ids: define as static constants here (NotificationIDs).

// MedicineReminder/Services/FDAService.swift
public struct FDADrug: Identifiable, Hashable, Sendable { public let id: String; public let brandName: String; public let genericName: String?; public let route: String?; public let dosageForms: [String] }
public actor FDAService {
    public static let shared: FDAService
    /// openFDA brand-name search. Returns [] on any failure (graceful offline fallback). Debounce in the View.
    public func search(_ query: String) async -> [FDADrug]
}

// MedicineReminder/Services/LiveActivityService.swift
@MainActor public final class LiveActivityService {
    public static let shared: LiveActivityService
    public func startOrUpdate(for event: DoseEvent, title: String) async
    public func update(for event: DoseEvent) async
    public func end(eventID: String) async
    public func endAll() async
}

// MedicineReminder/Services/ExportService.swift
public enum ExportService { public static func csv(medicines: [Medicine], logs: [DoseLog]) -> String }

// MedicineReminder/Haptics/HapticEngine.swift
@MainActor public enum HapticEngine { public static func taken(); public static func skipped(); public static func added(); public static func milestone(); public static func selection() }
```

## 9. DesignSystem — `Shared/DesignSystem/` (SwiftUI only; widget-safe)
Provide these PUBLIC symbols (agents consume them):
- `extension Color { init(hex: UInt, alpha: Double = 1) }` and an adaptive `init(lightHex:darkHex:)`.
- `extension MedicineColor { var color: Color; var gradient: LinearGradient; var soft: Color }` (uses light/dark hex).
- `enum AppFont { static func rounded(_ size: CGFloat, _ weight: Font.Weight) -> Font; static let largeTitle/title/headline/body/caption ... }` — medicine names & dose headings use **SF Pro Rounded** (`.system(..., design: .rounded)`); body uses default.
- `enum Spacing { static let xs/sm/md/lg/xl: CGFloat }`, `enum Radius { ... }`.
- **Liquid Glass wrappers (insulate iOS 26 APIs in ONE place):**
  - `struct GlassCard<Content: View>: View` — wraps content in a rounded container using `.glassEffect(.regular, in: .rect(cornerRadius:))`, accepts an optional `tint: Color`.
  - `extension View { func liquidGlass(tint: Color? = nil, cornerRadius: CGFloat = ...) -> some View }`
  - `struct GlassContainer<Content: View>: View` — wraps `GlassEffectContainer { ... }` (iOS 26) so morphing/merging works; degrade gracefully if needed.
  - Use `@available`/`if #available(iOS 26, *)` guards ONLY inside these wrappers; the rest of the app calls the wrappers and stays clean.
- Reusable components (widget-safe, SwiftUI-only): `StreakRing`, `PillIcon`, `ColorChip`, `TagBadge` ("Custom"), `CircularCountdown`.

> App-only composite components that depend on `DoseManager`/haptics go in `MedicineReminder/Views/Components/` (e.g. `DoseEventCard`, `MedicineRow`, `ConfettiCanvas`), NOT in Shared.

## 10. Cross-cutting requirements (EVERY agent)
- **Accessibility:** every interactive control has `.accessibilityLabel`; respect Dynamic Type (no fixed font sizes that clip; use scalable fonts); meaningful `.accessibilityValue` for rings/charts; honor Reduce Motion for animations.
- **Dark/light:** rely on semantic colors + the adaptive `MedicineColor`. No hard-coded white/black backgrounds — use materials/`Color(.systemBackground)`.
- **No placeholder UI**, no `// TODO` stubs in shipped paths, no `print` debugging, no force-unwraps on optionals that can be nil, no private APIs.
- **Concurrency:** SwiftData `ModelContext` work on `@MainActor`. `FDAService` is an `actor`. Pure logic is `Sendable`.
- **Previews:** every View file ends with a `#Preview` using `SharedModelContainer.preview()` (or sample data) — guard with `#if DEBUG` where it imports sample data.
- **Naming:** match the exact symbol names above. Slot ids ALWAYS via `ScheduleEngine.slotID(_:)`.
- **iOS 26 API spellings to use:** `.glassEffect(_:in:)`, `GlassEffectContainer`, `.glassEffectID(_:in:)` (for matched morphs), `.tabBarMinimizeBehavior(.onScrollDown)` on `TabView`, `Tab(...) {}` value-based tabs, `@Animatable`/spring `.smooth`/`.snappy`, `ContentUnavailableView` for empty states, `.symbolEffect` for icon animation, Swift Charts (`Chart`, `BarMark`, `SectorMark`). App Intents: `AppIntent`, `@Parameter`, `AppShortcutsProvider`, `PredictableIntent` where applicable, `IntentDialog`, `.result(dialog:)`/`.result(value:dialog:)`.
```
```
