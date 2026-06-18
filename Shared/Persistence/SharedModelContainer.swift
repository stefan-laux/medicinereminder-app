import Foundation
import SwiftData

// SharedModelContainer.swift
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
