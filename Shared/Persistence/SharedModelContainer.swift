import Foundation
import SwiftData

// SharedModelContainer.swift
public enum SharedModelContainer {
    public static let schema = Schema([Medicine.self, DoseSchedule.self, DoseLog.self])

    /// App Group-backed container so the widget extension and app share one
    /// store. `cloudKitDatabase: .automatic` enables iCloud sync when the app is
    /// signed with the iCloud (CloudKit) entitlement — see `project.yml`. With a
    /// free Personal Team (no entitlement) it transparently stays local-only, so
    /// the app keeps working; a do/catch fallback adds extra safety.
    public static let shared: ModelContainer = {
        let cloudConfig = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier),
            cloudKitDatabase: .automatic
        )
        if let container = try? ModelContainer(for: schema, configurations: cloudConfig) {
            return container
        }

        // Fallback: local-only (no CloudKit) if the cloud-backed store can't open.
        let localConfig = ModelConfiguration(
            schema: schema,
            groupContainer: .identifier(AppGroup.identifier)
        )
        do { return try ModelContainer(for: schema, configurations: localConfig) }
        catch { fatalError("Could not create ModelContainer: \(error)") }
    }()

    /// In-memory container for previews/tests, prefilled via SampleData.
    @MainActor public static func preview() -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        do {
            let container = try ModelContainer(for: schema, configurations: config)
            SampleData.seed(container.mainContext)
            return container
        } catch {
            fatalError("Could not create preview ModelContainer: \(error)")
        }
    }
}
