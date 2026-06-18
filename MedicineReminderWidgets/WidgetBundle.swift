//
//  WidgetBundle.swift
//  MedicineReminderWidgets
//
//  The widget extension entry point. Bundles every home-screen and
//  lock-screen widget plus the dose Live Activity.
//

import SwiftUI
import WidgetKit

@main
struct MedicineReminderWidgetBundle: WidgetBundle {
    var body: some Widget {
        // Home-screen widgets.
        NextDoseWidget()
        TodayTimelineWidget()

        // Lock-screen / StandBy accessory widgets.
        LockCircularWidget()
        LockInlineWidget()
        LockRectangularWidget()

        // ActivityKit Live Activity for the in-progress dose slot.
        DoseLiveActivity()
    }
}
