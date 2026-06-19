import SwiftData
import SwiftUI

/// Application entry point. Wires up the shared App-Group SwiftData store, the
/// observable `DoseManager`, the notification delegate, and requests notification
/// authorization + registers dose action categories on first launch.
@main
struct MedicineReminderApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    /// The shared, App-Group-backed container used by the app and widget extension.
    private let container = SharedModelContainer.shared

    /// Single observable store injected into the environment for every screen.
    @State private var doseManager: DoseManager

    init() {
        // DoseManager must be constructed with the shared container's main context.
        _doseManager = State(initialValue: DoseManager(context: SharedModelContainer.shared.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(doseManager)
                .onChange(of: scenePhase) { _, phase in
                    // Notifications are not used. Reconcile the Live Activity and
                    // refresh widgets whenever the app comes to the foreground.
                    if phase == .active { doseManager.reload() }
                }
        }
        .modelContainer(container)
    }
}
