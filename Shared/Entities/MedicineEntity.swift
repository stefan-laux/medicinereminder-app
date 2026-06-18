import AppIntents
import Foundation
import SwiftData

// MedicineEntity.swift
public struct MedicineEntity: AppEntity, Identifiable {
    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Medicine"
    public static let defaultQuery = MedicineEntityQuery()

    public var id: UUID
    public var name: String
    public var dosageDescription: String
    public var colorRaw: String
    public var iconName: String

    public init(id: UUID, name: String, dosageDescription: String, colorRaw: String, iconName: String) {
        self.id = id
        self.name = name
        self.dosageDescription = dosageDescription
        self.colorRaw = colorRaw
        self.iconName = iconName
    }

    public init(_ medicine: Medicine) {
        self.id = medicine.id
        self.name = medicine.name
        self.dosageDescription = medicine.dosageDescription
        self.colorRaw = medicine.colorRaw
        self.iconName = medicine.iconName
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(dosageDescription)")
    }
}

// MedicineEntityQuery conforms to EntityQuery + EntityStringQuery; fetches from SharedModelContainer.shared
// (use a @MainActor ModelContext). entities(matching:) does case/diacritic-insensitive fuzzy match on name.
public struct MedicineEntityQuery: EntityQuery, EntityStringQuery {
    public init() {}

    /// Resolve entities for the given identifiers.
    public func entities(for identifiers: [UUID]) async throws -> [MedicineEntity] {
        try await MainActor.run {
            let context = SharedModelContainer.shared.mainContext
            let idSet = Set(identifiers)
            let descriptor = FetchDescriptor<Medicine>(
                predicate: #Predicate { idSet.contains($0.id) && !$0.isArchived }
            )
            let medicines = try context.fetch(descriptor)
            // Preserve the requested order where possible.
            let byID = Dictionary(uniqueKeysWithValues: medicines.map { ($0.id, $0) })
            return identifiers.compactMap { byID[$0].map(MedicineEntity.init) }
        }
    }

    /// Case/diacritic-insensitive fuzzy match across name and fdaGenericName.
    public func entities(matching string: String) async throws -> [MedicineEntity] {
        try await MainActor.run {
            let context = SharedModelContainer.shared.mainContext
            let descriptor = FetchDescriptor<Medicine>(
                predicate: #Predicate { !$0.isArchived },
                sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.name)]
            )
            let medicines = try context.fetch(descriptor)
            let needle = Self.fold(string)
            guard !needle.isEmpty else {
                return medicines.map(MedicineEntity.init)
            }
            let matches = medicines.filter { medicine in
                Self.fold(medicine.name).contains(needle) ||
                (medicine.fdaGenericName.map { Self.fold($0).contains(needle) } ?? false)
            }
            return matches.map(MedicineEntity.init)
        }
    }

    /// Suggested entities (e.g. for Shortcuts parameter pickers).
    public func suggestedEntities() async throws -> [MedicineEntity] {
        try await MainActor.run {
            let context = SharedModelContainer.shared.mainContext
            let descriptor = FetchDescriptor<Medicine>(
                predicate: #Predicate { !$0.isArchived },
                sortBy: [SortDescriptor(\.sortIndex), SortDescriptor(\.name)]
            )
            let medicines = try context.fetch(descriptor)
            return medicines.map(MedicineEntity.init)
        }
    }

    /// Normalize for case- and diacritic-insensitive comparison.
    private static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
