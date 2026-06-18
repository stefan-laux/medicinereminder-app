//
//  AddEditMedicineView.swift
//  MedicineReminder
//
//  The add / edit medicine flow. Presented as a sheet from Home / Plans.
//  Initialized with an optional `Medicine`:
//    • nil   → "Add Medicine" (creates a new Medicine + DoseSchedule on save).
//    • value → "Edit Medicine" (mutates the existing Medicine + its schedule).
//
//  Features
//  --------
//  • FDA brand-name autocomplete on the name field (debounced async call to
//    `FDAService.search`, graceful offline fallback, suggestion list, applies a
//    "Custom" `TagBadge` when the entry is free-text with no FDA match).
//  • Dosage amount (decimals gated by `DosageUnit.allowsDecimal`), unit picker,
//    `ColorChip` palette grid, SF Symbol icon picker, notes.
//  • A schedule builder driven by `ScheduleFrequencyType` with conditional UI:
//    time-slot editor, an interval stepper for `.everyNHours`, a weekday
//    selector for `.specificDays`, and start / end date pickers.
//  • Pill bounce-in on appear, gated by Reduce Motion.
//
//  Persistence is delegated to `DoseManager.addMedicine` / `.update`, so
//  notification rescheduling and haptics run through the single owning store.
//

import SwiftUI
import SwiftData

/// Sheet that creates or edits a `Medicine` together with its primary
/// `DoseSchedule`. Use inside a sheet / full-screen cover; it provides its own
/// `NavigationStack`, toolbar, Cancel / Save buttons.
///
/// ```swift
/// .sheet(isPresented: $showingAdd) { AddEditMedicineView() }
/// .sheet(item: $editing) { medicine in AddEditMedicineView(medicine: medicine) }
/// ```
public struct AddEditMedicineView: View {

    // MARK: Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(DoseManager.self) private var manager

    // MARK: Edit target

    /// The medicine being edited, or `nil` when adding a new one.
    private let editingMedicine: Medicine?

    // MARK: Identity fields

    @State private var name: String = ""
    @State private var fdaGenericName: String? = nil
    /// `true` when the entry is free-text with no confirmed FDA match.
    @State private var isCustom: Bool = true

    // MARK: Dosage fields

    @State private var dosageText: String = "1"
    @State private var unit: DosageUnit = .mg

    // MARK: Appearance fields

    @State private var color: MedicineColor = .default
    @State private var iconName: String = "pills.fill"

    // MARK: Notes

    @State private var notes: String = ""

    // MARK: Schedule fields

    @State private var frequency: ScheduleFrequencyType = .once
    @State private var timeSlots: [TimeOfDay] = [TimeOfDay(hour: 8, minute: 0)]
    @State private var intervalHours: Int = 8
    @State private var weekdays: Set<Int> = []
    @State private var startDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var hasEndDate: Bool = false
    @State private var endDate: Date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(60 * 60 * 24 * 30)

    // MARK: FDA autocomplete state

    @State private var suggestions: [FDADrug] = []
    @State private var isSearching: Bool = false
    @State private var showSuggestions: Bool = false
    /// The text the running search task is debouncing/serving.
    @State private var searchQuery: String = ""

    // MARK: Animation

    @State private var pillScale: CGFloat = 1

    /// Guards the name `onChange` while we populate fields from an existing
    /// medicine, so loading doesn't reset the FDA / custom state.
    @State private var isLoading: Bool = false
    @State private var didLoad: Bool = false

    // MARK: Init

    /// - Parameter medicine: An existing medicine to edit, or `nil` to add a new one.
    public init(medicine: Medicine? = nil) {
        self.editingMedicine = medicine
    }

    private var isEditing: Bool { editingMedicine != nil }

    private var navigationTitle: String {
        isEditing ? String(localized: "Edit Medicine") : String(localized: "Add Medicine")
    }

    // MARK: Body

    public var body: some View {
        NavigationStack {
            Form {
                identitySection
                dosageSection
                appearanceSection
                scheduleSection
                notesSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .onAppear(perform: loadIfNeeded)
            .task(id: searchQuery) { await runSearch(for: searchQuery) }
        }
    }

    // MARK: - Identity section (name + FDA autocomplete)

    @ViewBuilder
    private var identitySection: some View {
        Section {
            HStack(spacing: Spacing.md) {
                PillIcon(systemName: iconName, color: color, size: 52)
                    .scaleEffect(pillScale)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    TextField("Medicine name", text: $name)
                        .font(AppFont.headline)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .accessibilityLabel("Medicine name")
                        .onChange(of: name, handleNameChange)

                    HStack(spacing: Spacing.sm) {
                        if isCustom {
                            TagBadge.custom
                        } else {
                            TagBadge("FDA", systemImage: "checkmark.seal.fill", tint: MedicineColor.emerald.color)
                        }
                        if isSearching {
                            ProgressView()
                                .controlSize(.mini)
                                .accessibilityLabel("Searching")
                        }
                    }
                    .animation(reduceMotion ? nil : .snappy(duration: 0.2), value: isCustom)
                }
            }
            .padding(.vertical, Spacing.xs)

            if showSuggestions && !suggestions.isEmpty {
                ForEach(suggestions) { drug in
                    suggestionRow(drug)
                }
            }
        } header: {
            Text("Medicine")
        } footer: {
            if isCustom && !trimmedName.isEmpty {
                Text("No FDA match — this will be saved as a custom medicine.")
            } else if !isCustom, let generic = fdaGenericName, !generic.isEmpty {
                Text("Generic name: \(generic)")
            }
        }
    }

    private func suggestionRow(_ drug: FDADrug) -> some View {
        Button {
            applySuggestion(drug)
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MedicineColor.emerald.color)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(drug.brandName)
                        .font(AppFont.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if let generic = drug.genericName, !generic.isEmpty {
                        Text(generic)
                            .font(AppFont.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: Spacing.sm)
                Image(systemName: "arrow.up.left")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(drug.brandName)\(drug.genericName.map { ", \($0)" } ?? "")")
        .accessibilityHint("Uses this FDA medicine name.")
    }

    // MARK: - Dosage section

    @ViewBuilder
    private var dosageSection: some View {
        Section("Dosage") {
            HStack {
                Text("Amount")
                    .font(AppFont.body)
                Spacer()
                TextField("Amount", text: $dosageText)
                    .keyboardType(unit.allowsDecimal ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
                    .font(AppFont.headline)
                    .onChange(of: dosageText) { _, _ in sanitizeDosage() }
                    .onChange(of: unit) { _, _ in sanitizeDosage() }
                    .accessibilityLabel("Dosage amount")
                    .accessibilityValue(dosageText.isEmpty ? "Empty" : dosageText)
                Text(unit.abbreviation)
                    .font(AppFont.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }

            Picker("Unit", selection: $unit) {
                ForEach(DosageUnit.allCases) { u in
                    Text(u.displayName.capitalized).tag(u)
                }
            }
            .accessibilityLabel("Dosage unit")
            .accessibilityValue(unit.displayName)

            if !dosagePreview.isEmpty {
                HStack {
                    Text("Each dose")
                        .font(AppFont.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(dosagePreview)
                        .font(AppFont.subheadline)
                        .foregroundStyle(color.color)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Each dose")
                .accessibilityValue(dosagePreview)
            }
        }
    }

    // MARK: - Appearance section (color + icon)

    @ViewBuilder
    private var appearanceSection: some View {
        Section("Color") {
            LazyVGrid(columns: colorColumns, spacing: Spacing.md) {
                ForEach(MedicineColor.allCases) { palette in
                    Button {
                        selectColor(palette)
                    } label: {
                        ColorChip(color: palette, isSelected: palette == color)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, Spacing.xs)
            .accessibilityLabel("Color palette")
        }

        Section("Icon") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.md) {
                    ForEach(Self.iconChoices, id: \.self) { symbol in
                        iconButton(symbol)
                    }
                }
                .padding(.vertical, Spacing.xs)
                .padding(.horizontal, 2)
            }
            .accessibilityLabel("Icon picker")
        }
    }

    private func iconButton(_ symbol: String) -> some View {
        let selected = symbol == iconName
        return Button {
            selectIcon(symbol)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selected ? Color.white : color.color)
                .frame(width: 48, height: 48)
                .background {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .fill(selected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(color.soft))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(color.color.opacity(selected ? 0 : 0.25), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.iconLabel(symbol))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Schedule section

    @ViewBuilder
    private var scheduleSection: some View {
        Section("Schedule") {
            Picker("Frequency", selection: $frequency) {
                ForEach(ScheduleFrequencyType.allCases) { freq in
                    Text(freq.displayName).tag(freq)
                }
            }
            .onChange(of: frequency) { _, newValue in applyFrequencyDefaults(newValue) }
            .accessibilityLabel("Dose frequency")
            .accessibilityValue(frequency.displayName)

            switch frequency {
            case .once, .twiceDaily, .threeTimesDaily, .specificDays:
                timeSlotEditor
            case .everyNHours:
                intervalEditor
            case .asNeeded:
                asNeededInfo
            }

            if frequency == .specificDays {
                weekdaySelector
            }
        }

        if frequency != .asNeeded {
            Section("Active period") {
                DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                    .accessibilityLabel("Schedule start date")

                Toggle("Has end date", isOn: $hasEndDate.animation(reduceMotion ? nil : .snappy))
                    .accessibilityLabel("Has end date")

                if hasEndDate {
                    DatePicker("Ends", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .accessibilityLabel("Schedule end date")
                }
            }
        }
    }

    // MARK: Time slot editor

    @ViewBuilder
    private var timeSlotEditor: some View {
        ForEach(Array(timeSlots.enumerated()), id: \.element.id) { index, slot in
            DatePicker(
                "Dose \(index + 1)",
                selection: bindingForSlot(at: index),
                displayedComponents: .hourAndMinute
            )
            .accessibilityLabel("Dose \(index + 1) time")
            .accessibilityValue(slot.displayString)
        }
        .onDelete(perform: canRemoveSlots ? removeSlots : nil)

        if canAddSlots {
            Button {
                addSlot()
            } label: {
                Label("Add time", systemImage: "plus.circle.fill")
                    .font(AppFont.subheadline)
            }
            .accessibilityLabel("Add another dose time")
        }
    }

    // MARK: Interval editor

    @ViewBuilder
    private var intervalEditor: some View {
        Stepper(value: $intervalHours, in: 1...24) {
            HStack {
                Text("Every")
                    .font(AppFont.body)
                Spacer()
                Text(intervalHours == 1 ? "1 hour" : "\(intervalHours) hours")
                    .font(AppFont.subheadline)
                    .foregroundStyle(color.color)
            }
        }
        .accessibilityLabel("Hours between doses")
        .accessibilityValue(intervalHours == 1 ? "1 hour" : "\(intervalHours) hours")

        DatePicker(
            "First dose",
            selection: bindingForSlot(at: 0),
            displayedComponents: .hourAndMinute
        )
        .accessibilityLabel("First dose time")
        .accessibilityValue(timeSlots.first?.displayString ?? "")
    }

    // MARK: As-needed info

    private var asNeededInfo: some View {
        HStack(spacing: Spacing.sm) {
            TagBadge("As needed", systemImage: "hand.raised.fill", tint: MedicineColor.amber.color)
            Text("Logged manually — no reminders.")
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("As needed. Logged manually, no reminders.")
    }

    // MARK: Weekday selector

    private var weekdaySelector: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("On these days")
                .font(AppFont.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: Spacing.xs) {
                ForEach(Self.weekdayOrder, id: \.self) { weekday in
                    weekdayToggle(weekday)
                }
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private func weekdayToggle(_ weekday: Int) -> some View {
        let selected = weekdays.contains(weekday)
        return Button {
            toggleWeekday(weekday)
        } label: {
            Text(Self.weekdaySymbol(weekday))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(selected ? Color.white : .primary)
                .frame(width: 38, height: 38)
                .background {
                    Circle().fill(selected ? AnyShapeStyle(color.gradient) : AnyShapeStyle(Color(.tertiarySystemFill)))
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.weekdayName(weekday))
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - Notes section

    private var notesSection: some View {
        Section("Notes") {
            TextField("Optional notes", text: $notes, axis: .vertical)
                .lineLimit(2...5)
                .font(AppFont.body)
                .accessibilityLabel("Notes")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .accessibilityLabel("Cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Save") { save() }
                .fontWeight(.semibold)
                .disabled(!canSave)
                .accessibilityLabel("Save medicine")
                .accessibilityHint(canSave ? "Saves this medicine." : "Enter a name and a valid amount to save.")
        }
    }

    // MARK: - Derived values

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var dosageValue: Double? {
        Double(dosageText.replacingOccurrences(of: ",", with: "."))
    }

    private var dosagePreview: String {
        guard let value = dosageValue, value > 0 else { return "" }
        return unit.formatted(value)
    }

    private var canSave: Bool {
        guard !trimmedName.isEmpty else { return false }
        guard let value = dosageValue, value > 0 else { return false }
        if frequency == .specificDays && weekdays.isEmpty { return false }
        return true
    }

    private var colorColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 44), spacing: Spacing.md)]
    }

    /// Whether the current frequency permits adding extra daily time slots.
    private var canAddSlots: Bool {
        switch frequency {
        case .once: timeSlots.count < 1
        case .twiceDaily: timeSlots.count < 2
        case .threeTimesDaily: timeSlots.count < 3
        case .specificDays: timeSlots.count < 6
        case .everyNHours, .asNeeded: false
        }
    }

    private var canRemoveSlots: Bool {
        timeSlots.count > 1 && frequency == .specificDays
    }

    // MARK: - Bindings

    private func bindingForSlot(at index: Int) -> Binding<Date> {
        Binding(
            get: {
                guard timeSlots.indices.contains(index) else { return Date() }
                return timeSlots[index].date(on: Date())
            },
            set: { newDate in
                guard timeSlots.indices.contains(index) else { return }
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                timeSlots[index] = TimeOfDay(hour: comps.hour ?? 0, minute: comps.minute ?? 0)
            }
        )
    }

    // MARK: - Loading existing medicine

    private func loadIfNeeded() {
        animatePillIn()
        guard let medicine = editingMedicine, !didLoad else { return }
        didLoad = true

        // Guard the name onChange while we populate from the model. Reset on the
        // next runloop tick so any queued change is ignored, then live typing works.
        isLoading = true
        defer { DispatchQueue.main.async { isLoading = false } }

        name = medicine.name
        fdaGenericName = medicine.fdaGenericName
        isCustom = medicine.isCustom
        dosageText = formatLoadedAmount(medicine.dosageAmount)
        unit = medicine.unit
        color = medicine.color
        iconName = medicine.iconName
        notes = medicine.notes

        if let schedule = medicine.schedules.first {
            frequency = schedule.frequency
            timeSlots = schedule.timeSlots.isEmpty ? defaultSlots(for: schedule.frequency) : schedule.timeSlots
            intervalHours = schedule.intervalHours
            weekdays = Set(schedule.weekdays)
            startDate = schedule.startDate
            if let end = schedule.endDate {
                hasEndDate = true
                endDate = end
            }
        }
    }

    private func formatLoadedAmount(_ amount: Double) -> String {
        amount == amount.rounded() ? String(Int(amount)) : String(format: "%g", amount)
    }

    // MARK: - Pill bounce-in

    private func animatePillIn() {
        guard !reduceMotion else { return }
        pillScale = 0.6
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            pillScale = 1
        }
    }

    // MARK: - Name change + FDA search driving

    private func handleNameChange(_ oldValue: String, _ newValue: String) {
        // Don't disturb FDA/custom state while populating from an existing medicine.
        guard !isLoading else { return }
        // Typing free-text marks the entry custom until a suggestion is chosen.
        isCustom = true
        fdaGenericName = nil
        showSuggestions = true
        searchQuery = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Debounced FDA search. Re-run automatically by `.task(id: searchQuery)`
    /// whenever the query changes; the sleep provides the debounce and is
    /// cancelled when the id changes again.
    private func runSearch(for query: String) async {
        guard query.count >= 2 else {
            suggestions = []
            isSearching = false
            return
        }

        // Debounce: wait a beat; if the query changes, this task is cancelled.
        do {
            try await Task.sleep(for: .milliseconds(350))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }

        isSearching = true
        let results = await FDAService.shared.search(query)
        guard !Task.isCancelled else { return }

        isSearching = false
        suggestions = results

        // Auto-confirm an exact brand-name match so the badge flips to FDA.
        if let exact = results.first(where: { $0.brandName.compare(query, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) {
            isCustom = false
            fdaGenericName = exact.genericName
        }
    }

    private func applySuggestion(_ drug: FDADrug) {
        name = drug.brandName
        fdaGenericName = drug.genericName
        isCustom = false
        showSuggestions = false
        suggestions = []
        searchQuery = drug.brandName
        if !reduceMotion {
            animatePillIn()
        }
        HapticEngine.selection()
    }

    // MARK: - Field mutations

    private func sanitizeDosage() {
        if !unit.allowsDecimal {
            // Strip any fractional part for unit types that must be whole.
            if let value = dosageValue {
                let whole = Int(value)
                dosageText = String(max(whole, 0))
            } else {
                dosageText = dosageText.filter(\.isNumber)
            }
        }
    }

    private func selectColor(_ palette: MedicineColor) {
        guard palette != color else { return }
        if reduceMotion {
            color = palette
        } else {
            withAnimation(.snappy(duration: 0.2)) { color = palette }
        }
        HapticEngine.selection()
    }

    private func selectIcon(_ symbol: String) {
        guard symbol != iconName else { return }
        if reduceMotion {
            iconName = symbol
        } else {
            withAnimation(.snappy(duration: 0.2)) { iconName = symbol }
        }
        HapticEngine.selection()
    }

    private func toggleWeekday(_ weekday: Int) {
        if weekdays.contains(weekday) {
            weekdays.remove(weekday)
        } else {
            weekdays.insert(weekday)
        }
        HapticEngine.selection()
    }

    private func applyFrequencyDefaults(_ newValue: ScheduleFrequencyType) {
        // Skip while populating from an existing medicine — keep its real slots.
        guard !isLoading else { return }
        timeSlots = defaultSlots(for: newValue)
        if newValue == .specificDays && weekdays.isEmpty {
            // Default to weekdays Mon–Fri.
            weekdays = [2, 3, 4, 5, 6]
        }
    }

    private func defaultSlots(for freq: ScheduleFrequencyType) -> [TimeOfDay] {
        switch freq {
        case .once:
            [TimeOfDay(hour: 8, minute: 0)]
        case .twiceDaily:
            [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 20, minute: 0)]
        case .threeTimesDaily:
            [TimeOfDay(hour: 8, minute: 0), TimeOfDay(hour: 13, minute: 0), TimeOfDay(hour: 20, minute: 0)]
        case .everyNHours:
            [TimeOfDay(hour: 8, minute: 0)]
        case .specificDays:
            timeSlots.isEmpty ? [TimeOfDay(hour: 8, minute: 0)] : timeSlots
        case .asNeeded:
            []
        }
    }

    private func addSlot() {
        let last = timeSlots.max() ?? TimeOfDay(hour: 8, minute: 0)
        let nextHour = min(last.hour + 4, 23)
        timeSlots.append(TimeOfDay(hour: nextHour, minute: last.minute))
        timeSlots.sort()
        HapticEngine.selection()
    }

    private func removeSlots(at offsets: IndexSet) {
        timeSlots.remove(atOffsets: offsets)
        if timeSlots.isEmpty {
            timeSlots = [TimeOfDay(hour: 8, minute: 0)]
        }
    }

    // MARK: - Save

    private func save() {
        guard let amount = dosageValue, amount > 0 else { return }

        let schedule = buildSchedule()

        if let medicine = editingMedicine {
            medicine.name = trimmedName
            medicine.dosageAmount = amount
            medicine.unitRaw = unit.rawValue
            medicine.colorRaw = color.rawValue
            medicine.iconName = iconName
            medicine.notes = notes
            medicine.isCustom = isCustom
            medicine.fdaGenericName = isCustom ? nil : fdaGenericName

            applySchedule(schedule, to: medicine)
            manager.update(medicine)
        } else {
            let medicine = Medicine(
                name: trimmedName,
                dosageAmount: amount,
                unit: unit,
                color: color,
                iconName: iconName,
                notes: notes,
                isCustom: isCustom,
                fdaGenericName: isCustom ? nil : fdaGenericName,
                sortIndex: manager.medicines.count
            )
            schedule.medicine = medicine
            medicine.schedules = [schedule]
            manager.addMedicine(medicine)
        }

        dismiss()
    }

    private func buildSchedule() -> DoseSchedule {
        let resolvedSlots: [TimeOfDay] = frequency == .asNeeded ? [] : timeSlots
        let resolvedWeekdays = frequency == .specificDays ? weekdays.sorted() : []
        return DoseSchedule(
            frequency: frequency,
            timeSlots: resolvedSlots,
            intervalHours: intervalHours,
            weekdays: resolvedWeekdays,
            startDate: startDate,
            endDate: (frequency != .asNeeded && hasEndDate) ? endDate : nil,
            isActive: true
        )
    }

    /// Update the medicine's primary schedule in place (reuse the first one so
    /// existing relationships/ids stay stable), or attach a new schedule.
    private func applySchedule(_ schedule: DoseSchedule, to medicine: Medicine) {
        if let existing = medicine.schedules.first {
            existing.frequencyRaw = schedule.frequencyRaw
            existing.timeSlots = schedule.timeSlots
            existing.intervalHours = schedule.intervalHours
            existing.weekdays = schedule.weekdays
            existing.startDate = schedule.startDate
            existing.endDate = schedule.endDate
            existing.isActive = true
        } else {
            schedule.medicine = medicine
            medicine.schedules = [schedule]
        }
    }

    // MARK: - Icon catalog

    private static let iconChoices: [String] = [
        "pills.fill", "pill.fill", "capsule.fill", "cross.vial.fill",
        "drop.fill", "syringe.fill", "bandage.fill", "heart.fill",
        "lungs.fill", "brain.head.profile", "sun.max.fill", "leaf.fill",
        "cross.case.fill", "eyedropper.halffull", "facemask.fill", "allergens.fill",
        "stethoscope", "thermometer.medium", "wind", "bolt.heart.fill"
    ]

    private static func iconLabel(_ symbol: String) -> String {
        symbol
            .replacingOccurrences(of: ".fill", with: "")
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "halffull", with: "")
            .trimmingCharacters(in: .whitespaces)
            + " icon"
    }

    // MARK: - Weekday helpers

    /// Display order Mon...Sun (Calendar weekday: 1=Sun ... 7=Sat).
    private static let weekdayOrder: [Int] = [2, 3, 4, 5, 6, 7, 1]

    private static func weekdaySymbol(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortWeekdaySymbols   // index 0 == Sunday
        let index = (weekday - 1) % symbols.count
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }

    private static func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols           // index 0 == Sunday
        let index = (weekday - 1) % symbols.count
        guard symbols.indices.contains(index) else { return "" }
        return symbols[index]
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Add Medicine") {
    let container = SharedModelContainer.preview()
    return AddEditMedicineView()
        .modelContainer(container)
        .environment(DoseManager(context: container.mainContext))
}

#Preview("Edit Medicine") {
    let container = SharedModelContainer.preview()
    let medicine = (try? container.mainContext.fetch(FetchDescriptor<Medicine>()))?.first
    return Group {
        if let medicine {
            AddEditMedicineView(medicine: medicine)
        } else {
            AddEditMedicineView()
        }
    }
    .modelContainer(container)
    .environment(DoseManager(context: container.mainContext))
}
#endif
