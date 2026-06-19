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
                .task { await bootstrap() }
                .onChange(of: scenePhase) { _, phase in
                    // Reconcile the Live Activity + widgets (and fallback
                    // notifications) whenever the app returns to the foreground.
                    if phase == .active { doseManager.reload() }
                }
        }
        .modelContainer(container)
    }

    /// Request notification permission — used only as a fallback for when the app
    /// isn't open to show a Live Activity — and register the dose action category.
    @MainActor
    private func bootstrap() async {
        NotificationService.shared.registerCategories()
        _ = await NotificationService.shared.requestAuthorization()
        doseManager.reload()
    }
}
