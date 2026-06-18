import SwiftData
import SwiftUI

/// Application entry point. Wires up the shared App-Group SwiftData store, the
/// observable `DoseManager`, the notification delegate, and requests notification
/// authorization + registers dose action categories on first launch.
@main
struct MedicineReminderApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

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
                .task {
                    await bootstrap()
                }
        }
        .modelContainer(container)
    }

    /// One-time launch work: register notification categories, request authorization,
    /// and schedule the initial batch of reminders.
    @MainActor
    private func bootstrap() async {
        NotificationService.shared.registerCategories()
        _ = await NotificationService.shared.requestAuthorization()
        await NotificationService.shared.rescheduleAll(medicines: doseManager.medicines)
    }
}
