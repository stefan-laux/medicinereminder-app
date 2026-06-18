# MedicineReminder

A polished, production-grade **iOS 26 / iPadOS 26** medication tracking app built entirely in
SwiftUI with SwiftData. MedicineReminder helps people remember their medicines, log doses,
build adherence streaks, and understand their habits over time — with deep system
integration via notifications, widgets, Live Activities, Siri/App Intents, and the new
**Liquid Glass** design language.

---

## ⚠️ Authored on Windows — build on macOS

This repository was **authored on a Windows machine and has never been compiled.** Swift,
the iOS 26 SDK, and Xcode do not run on Windows, so the code here is *inspection-correct*
but not machine-verified. **You must build it on a Mac** (Apple Silicon recommended)
running **Xcode 26** with the **iOS 26 SDK**. Expect to fix the occasional small issue that
only a real compiler can catch, and to perform the manual signing/capability steps listed
below — they cannot be encoded in source.

The Xcode project itself is **not** checked in. It is generated from
[`project.yml`](project.yml) with [XcodeGen](https://github.com/yonik0/XcodeGen), so the
first build requires a generation step.

---

## Build steps (macOS)

1. **Install XcodeGen** (via Homebrew):

   ```sh
   brew install xcodegen
   ```

2. **Generate the Xcode project** from the repo root:

   ```sh
   xcodegen generate
   ```

   This produces `MedicineReminder.xcodeproj` with the two targets defined in `project.yml`.

3. **Open the project** in Xcode 26:

   ```sh
   open MedicineReminder.xcodeproj
   ```

4. **Set your signing & identifiers.** In the project editor, for **both** the
   `MedicineReminder` app target and the `MedicineReminderWidgets` extension target:

   - Set **`DEVELOPMENT_TEAM`** to your Apple Developer Team ID (it ships blank).
   - Replace the placeholder **bundle id prefix `com.example`** with your own reverse-DNS
     prefix. The identifiers to update are:
     - App: `com.example.medicinereminder`
     - Widgets: `com.example.medicinereminder.widgets`
   - Replace the placeholder **App Group `group.com.example.medicinereminder`** with your
     own (it is referenced in `Shared/Persistence/AppGroup.swift`, the two `.entitlements`
     files, and `project.yml` — keep them all in sync).

5. **Enable capabilities** under *Signing & Capabilities* for **both** targets:

   - **App Groups** — add your App Group id (the SwiftData store is shared App Group ↔ widget).
   - **Live Activities** — the app target ships `NSSupportsLiveActivities` in its Info.plist;
     enable the capability so ActivityKit works on device.
   - **Push Notifications** — only required *if you wire up remote Live Activity / push
     updates*. Local notifications and on-device Live Activity updates do **not** need it.
     `remote-notification` is declared in `UIBackgroundModes` for forward compatibility.

6. **Pick an iOS 26 destination.** Select a physical device or simulator running **iOS 26**
   (Live Activities, widgets, and Siri shortcuts behave best on a real device).

7. **Run** (`⌘R`).

> If you change `project.yml` later, re-run `xcodegen generate`. Do not hand-edit the
> generated `.xcodeproj`.

---

## Features

- **Today timeline (Home)** — dose events grouped by time slot, with one-tap *Take / Skip /
  Snooze*, live status, and a celebratory confetti + haptic on completion.
- **Add / edit medicines** — name, dosage amount + unit, color, SF Symbol icon, notes, and
  flexible scheduling (once, twice, three-times daily, every-N-hours, specific weekdays, or
  as-needed/PRN).
- **FDA drug autocomplete** — debounced openFDA brand-name search with graceful offline
  fallback; medicines with no match are tagged **Custom**.
- **Plans / calendar** — month and week views with per-day dose markers and a day-detail
  sheet for any date.
- **Insights / analytics** — current & longest adherence streaks, weekly adherence chart,
  per-medicine adherence, an all-time totals summary, and a monthly heatmap (Swift Charts).
- **Notifications** — actionable reminders (Take / Skip / Snooze categories) with automatic
  rescheduling of the next batch, plus an optional weekly summary.
- **Live Activities** — a Lock Screen / Dynamic Island activity for the current dose slot
  that updates as you take doses.
- **Home Screen & Lock Screen widgets** — Next Dose, Today Timeline, and Lock Screen
  complications, all reading the shared App Group store.
- **Siri & App Intents** — log a dose taken (with or without an amount), skip, snooze, check
  your streak, and check upcoming doses, exposed through `AppShortcutsProvider`.
- **Data export** — CSV export of medicines and dose logs.
- **Liquid Glass UI** — iOS 26 glass surfaces, value-based `Tab`s with a tab bar that
  minimizes on scroll, SF Pro Rounded typography for medicine names, and symbol effects.
- **Accessibility & adaptivity** — full Dynamic Type support, accessibility labels/values on
  controls and charts, Reduce Motion gating for large animations, and light/dark adaptive
  colors with no hard-coded backgrounds.

---

## Architecture & folder overview

Two targets share a single SwiftData store via an App Group. Pure logic and the design
system are shared by the app and the widget extension.

```
Shared/                         Code shared between app + widget extension
  Models/         SwiftData @Model classes: Medicine, DoseSchedule, DoseLog
  Enums/          Value enums + small Codable structs (DosageUnit, DoseStatus,
                  ScheduleFrequencyType, LogSource, TimeOfDay, MedicineColor)
  Persistence/    App Group-backed SharedModelContainer, AppGroup id, SampleData seed
  Activity/       DoseActivityAttributes (ActivityKit, shared app + widget)
  Entities/       MedicineEntity (AppEntity) + query for App Intents
  Logic/          PURE, Sendable logic: ScheduleEngine, StreakCalculator,
                  AdherenceCalculator, DoseEvent value types (no UIKit, no @MainActor)
  DesignSystem/   Theme tokens, typography (AppFont), Color(hex:), MedicineColor+UI,
                  Liquid Glass wrappers (GlassCard, .liquidGlass, GlassContainer),
                  reusable widget-safe components (StreakRing, PillIcon, ColorChip, …)

MedicineReminder/               The application target
  App/            App entry, RootView, MainTabView, LaunchAnimationView, AppDelegate
  Services/       NotificationService, FDAService (actor), LiveActivityService, ExportService
  Managers/       DoseManager (@Observable UI store), DoseActions (non-UI mutations)
  Haptics/        HapticEngine
  Intents/        App Intents + AppShortcutsProvider
  Views/
    Home/         Today timeline screen
    AddEdit/      Add/edit medicine flow + FDA autocomplete UI
    Plans/        Calendar / plan overview
    Analytics/    Streak, charts, heatmap
    Settings/     Settings
    Components/   App-only composite views (DoseEventCard, MedicineRow, ConfettiCanvas, …)
  Resources/      Assets.xcassets (AppIcon, AccentColor)

MedicineReminderWidgets/        The widget + Live Activity app-extension target
                  WidgetBundle, widgets, Live Activity UI, WidgetDataProvider
```

**Design principles**

- **One source of truth:** all shared type names, signatures, file locations, bundle ids and
  the App Group are defined in [`CONTRACT.md`](CONTRACT.md). The store is the App
  Group-backed `SharedModelContainer.shared`.
- **Concurrency:** SwiftData `ModelContext` work is `@MainActor`; pure logic is `Sendable`;
  `FDAService` is an `actor`. Built for Swift 6 strict concurrency.
- **Liquid Glass is insulated:** every iOS 26 glass API call lives behind the DesignSystem
  wrappers; the rest of the app never calls `.glassEffect` directly.

---

## Known manual steps / not compiler-verified

This project was written on Windows and has **not been compiled.** Before it builds, runs,
and is App Store-submittable you should plan for the following:

- **Compile on a Mac.** The code targets the iOS 26 SDK and Swift 6 strict concurrency.
  Some symbols may need minor adjustment under a real compiler; treat the first build as a
  fix-up pass.
- **Run `xcodegen generate` first.** No `.xcodeproj` is committed — it does not exist until
  you generate it.
- **Signing is not configured.** `DEVELOPMENT_TEAM` is blank and signing must be set per
  target. Without a team, device builds and capabilities will not provision.
- **Replace placeholder identifiers.** `com.example…` bundle ids and the
  `group.com.example.medicinereminder` App Group are placeholders — change them in
  `project.yml`, the entitlements files, and `Shared/Persistence/AppGroup.swift` together.
- **Enable capabilities manually.** App Groups, Live Activities, and (if you add remote
  updates) Push Notifications must be toggled on in *Signing & Capabilities* for **both**
  targets; XcodeGen seeds the entitlements but the capability switches are an Xcode/portal
  step.
- **App icon is a marker only.** `AppIcon.appiconset` declares a single universal
  1024×1024 iOS App Store slot with **no image asset attached**. Add your real 1024px PNG in
  Xcode before archiving for the App Store, or the validation will fail.
- **openFDA has no key but is rate-limited.** `FDAService` calls the public openFDA API and
  returns `[]` on any failure, so the app degrades gracefully offline; for heavy use,
  consider adding an API key.
- **Live Activities / widgets are best on device.** Behavior in the simulator can differ;
  verify reminders, widgets, and the Live Activity on a physical iOS 26 device.
- **App Store metadata, privacy nutrition label, and screenshots** are outside this repo and
  must be completed in App Store Connect.
