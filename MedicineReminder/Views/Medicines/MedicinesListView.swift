//
//  MedicinesListView.swift
//  MedicineReminder
//
//  A list of all (non-archived) medicines. Tap a row to edit it, swipe to
//  remove (archive) it, or use + to add a new one. Presented as a sheet from
//  Home. The edit flow reuses `AddEditMedicineView(medicine:)`.
//

import SwiftData
import SwiftUI

struct MedicinesListView: View {
    @Environment(DoseManager.self) private var manager
    @Environment(\.dismiss) private var dismiss

    /// The medicine being edited (drives the edit sheet).
    @State private var editingMedicine: Medicine?
    /// Drives the add-medicine sheet.
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            content
                .background(Color(.systemGroupedBackground))
                .navigationTitle("Medicines")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                            .accessibilityLabel("Done")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingAdd = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add medicine")
                    }
                }
                .sheet(item: $editingMedicine) { medicine in
                    AddEditMedicineView(medicine: medicine)
                }
                .sheet(isPresented: $showingAdd) {
                    AddEditMedicineView()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if manager.medicines.isEmpty {
            EmptyStateView(
                "No Medicines",
                systemImage: "pills.fill",
                description: "Add a medicine and it'll appear here to edit any time.",
                tint: MedicineColor.default.color,
                actionTitle: "Add Medicine"
            ) {
                showingAdd = true
            }
        } else {
            List {
                ForEach(manager.medicines) { medicine in
                    Button {
                        editingMedicine = medicine
                    } label: {
                        MedicineRow(medicine: medicine, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                }
                .onDelete(perform: deleteMedicines)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    /// Archive (soft-delete) the swiped medicines. Snapshot first since
    /// `archive` reloads and mutates `manager.medicines`.
    private func deleteMedicines(at offsets: IndexSet) {
        let toArchive = offsets.map { manager.medicines[$0] }
        for medicine in toArchive {
            manager.archive(medicine)
        }
    }
}

#if DEBUG
#Preview {
    let container = SharedModelContainer.preview()
    MedicinesListView()
        .modelContainer(container)
        .environment(DoseManager(context: container.mainContext))
}
#endif
