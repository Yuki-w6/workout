import SwiftUI
import SwiftData

struct ExerciseDetailView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    let exerciseID: UUID
    let isNewRecord: Bool
    let initialDate: Date?
    @State private var isEditing = false
    @State private var draftName = ""
    @State private var draftBodyPart: BodyPart = .chest
    @State private var unit: WeightUnit = .kg
    @State private var sets: [ExerciseSetInput] = ExerciseSetInput.defaultSets()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var recordDate = Date()
    @State private var lastLoadedDate = Date()
    @FocusState private var focusedField: FocusField?
    @AppStorage("lastWeightUnit") private var lastWeightUnitRaw = WeightUnit.kg.rawValue

    private let calendar = Calendar.current
    private static let recordDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()

    private enum FocusField: Hashable {
        case weight(Int)
        case reps(Int)
        case memo(Int)
    }

    private var currentExercise: Exercise? {
        viewModel.exercise(id: exerciseID)
    }

    private var formattedRecordDate: String {
        Self.recordDateFormatter.string(from: recordDate)
    }

    private var focusableFields: [FocusField] {
        sets.indices.flatMap { index in
            [.weight(index), .reps(index), .memo(index)]
        }
    }

    var body: some View {
        List {
            Section("日付") {
                HStack {
                    Spacer()
                    ZStack(alignment: .trailing) {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { recordDate },
                                set: { recordDate = calendar.startOfDay(for: $0) }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .opacity(0.02)
                        .accessibilityLabel("日付")
                        Text(formattedRecordDate)
                            .monospacedDigit()
                            .allowsHitTesting(false)
                    }
                }
            }
            Section {
                ForEach(Array($sets.enumerated()), id: \.element.id) { index, $set in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            TextField("重さ", text: $set.weight)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 72)
                                .recordInputStyle()
                                .submitLabel(.next)
                                .onSubmit { focusNextField() }
                                .focused($focusedField, equals: .weight(index))
                            Text(unit.rawValue)
                                .foregroundStyle(.secondary)
                            TextField("回数", text: $set.reps)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(minWidth: 72)
                                .recordInputStyle()
                                .submitLabel(.next)
                                .onSubmit { focusNextField() }
                                .focused($focusedField, equals: .reps(index))
                            Text("回")
                                .foregroundStyle(.secondary)
                        }
                        TextField("メモ", text: $set.memo)
                            .textInputAutocapitalization(.never)
                            .recordInputStyle()
                            .submitLabel(.next)
                            .onSubmit { focusNextField() }
                            .focused($focusedField, equals: .memo(index))
                    }
                    .padding(.vertical, 6)
                }
                Button {
                    sets.append(ExerciseSetInput())
                    let newIndex = max(sets.count - 1, 0)
                    DispatchQueue.main.async {
                        focusedField = .weight(newIndex)
                    }
                } label: {
                    Label("セットを追加", systemImage: "plus")
                }
            } header: {
                HStack {
                    Text("セット")
                    Spacer()
                    Picker("単位", selection: $unit) {
                        ForEach(WeightUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue.lowercased())
                                .textCase(.none)
                                .tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 140)
                    .textCase(.none)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("戻る")
            }
            ToolbarItem(placement: .principal) {
                Text(currentExercise?.name ?? "Exercise")
                    .font(.headline)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("保存") {
                    saveRecord(for: recordDate)
                    lastLoadedDate = calendar.startOfDay(for: recordDate)
                    dismiss()
                }
                .accessibilityLabel("記録を保存")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("<") {
                    focusPreviousField()
                }
                .keyboardButtonStyle()
                Button(">") {
                    focusNextField()
                }
                .keyboardButtonStyle()
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationStack {
                Form {
                    TextField("Exercise Name", text: $draftName)
                    Picker("Body Part", selection: $draftBodyPart) {
                        ForEach(BodyPart.allCases, id: \.self) { bodyPart in
                            Text(bodyPart.displayName)
                        }
                    }
                }
                .navigationTitle("Edit Exercise")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isEditing = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            viewModel.updateExercise(
                                id: exerciseID,
                                name: draftName,
                                bodyPart: draftBodyPart
                            )
                            isEditing = false
                        }
                    }
                }
            }
        }
        .onAppear {
            let baseDate = initialDate ?? Date()
            let normalized = calendar.startOfDay(for: baseDate)
            recordDate = normalized
            lastLoadedDate = normalized
            loadRecord(for: normalized)
        }
        .onChange(of: recordDate) { _, newValue in
            handleRecordDateChange(to: newValue)
        }
        .onChange(of: unit) { _, newValue in
            lastWeightUnitRaw = newValue.rawValue
        }
    }

    private func loadRecord(for date: Date) {
        guard let exercise = fetchExerciseForRecord() else {
            return
        }
        if let record = fetchRecordHeader(for: date) {
            let sortedDetails = record.details.sorted { $0.setNumber < $1.setNumber }
            if let firstUnit = sortedDetails.first?.weightUnit {
                unit = firstUnit
                lastWeightUnitRaw = firstUnit.rawValue
            }
            let loadedSets = sortedDetails.map { ExerciseSetInput(from: $0) }
            sets = loadedSets.isEmpty ? ExerciseSetInput.defaultSets() : loadedSets
            if sets.last.map(isEmptySet) != true {
                sets.append(ExerciseSetInput())
            }
            setInitialFocus(toLastSet: true)
        } else {
            unit = WeightUnit(rawValue: lastWeightUnitRaw) ?? exercise.weightUnit
            sets = ExerciseSetInput.defaultSets()
            setInitialFocus(toLastSet: false)
        }
    }

    private func saveRecord(for date: Date) {
        let savedSets = sets.enumerated().map { index, input in
            ExerciseSet(order: index, weight: input.weight, reps: input.reps, memo: input.memo)
        }
        viewModel.updateExerciseRecord(id: exerciseID, unit: unit, sets: savedSets)
        saveWorkoutRecord(for: date)
    }

    private func handleRecordDateChange(to newDate: Date) {
        let normalized = calendar.startOfDay(for: newDate)
        guard normalized != lastLoadedDate else {
            return
        }
        loadRecord(for: normalized)
        lastLoadedDate = normalized
    }

    private func setInitialFocus(toLastSet: Bool) {
        let targetIndex = toLastSet ? max(sets.count - 1, 0) : 0
        DispatchQueue.main.async {
            focusedField = .weight(targetIndex)
        }
    }

    private func focusNextField() {
        guard !focusableFields.isEmpty else {
            return
        }
        guard let current = focusedField,
              let index = focusableFields.firstIndex(of: current) else {
            focusedField = focusableFields.first
            return
        }
        let nextIndex = index + 1
        if nextIndex < focusableFields.count {
            focusedField = focusableFields[nextIndex]
            return
        }
        sets.append(ExerciseSetInput())
        DispatchQueue.main.async {
            focusedField = .weight(max(sets.count - 1, 0))
        }
    }

    private func focusPreviousField() {
        guard let current = focusedField,
              let index = focusableFields.firstIndex(of: current) else {
            return
        }
        let previousIndex = index - 1
        guard previousIndex >= 0 else {
            return
        }
        focusedField = focusableFields[previousIndex]
    }
}

private struct ExerciseSetInput: Identifiable {
    let id = UUID()
    var weight: String = ""
    var reps: String = ""
    var memo: String = ""

    init() {}

    init(from set: ExerciseSet) {
        weight = set.weight
        reps = set.reps
        memo = set.memo
    }

    init(from detail: RecordDetail) {
        weight = detail.weight == 0 ? "" : String(detail.weight)
        reps = detail.repetitions == 0 ? "" : String(detail.repetitions)
        memo = detail.memo ?? ""
    }

    static func defaultSets() -> [ExerciseSetInput] {
        (0..<3).map { _ in ExerciseSetInput() }
    }
}

private struct RecordInputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.35))
            )
    }
}

private extension View {
    func recordInputStyle() -> some View {
        modifier(RecordInputFieldModifier())
    }
}

private struct KeyboardButtonModifier: ViewModifier {
    let isEmphasized: Bool

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isEmphasized ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
            .clipShape(Capsule())
    }
}

private extension View {
    func keyboardButtonStyle(isEmphasized: Bool = false) -> some View {
        modifier(KeyboardButtonModifier(isEmphasized: isEmphasized))
    }
}

private extension ExerciseDetailView {
    func isEmptySet(_ set: ExerciseSetInput) -> Bool {
        set.weight.isEmpty && set.reps.isEmpty && set.memo.isEmpty
    }

    func saveWorkoutRecord(for date: Date) {
        let trimmedSets = sets.filter { input in
            !(input.weight.isEmpty && input.reps.isEmpty && input.memo.isEmpty)
        }
        guard let exercise = fetchExerciseForRecord() else {
            return
        }
        let targetDate = calendar.startOfDay(for: date)
        let targetID = exerciseID
        if trimmedSets.isEmpty {
            if let existing = fetchRecordHeader(for: targetDate) {
                modelContext.delete(existing)
            }
            saveContext()
            return
        }

        let header: RecordHeader
        if let existing = fetchRecordHeader(for: targetDate) {
            header = existing
            for detail in existing.details {
                modelContext.delete(detail)
            }
        } else {
            header = RecordHeader(date: targetDate, exercise: exercise)
            modelContext.insert(header)
        }

        let details = trimmedSets.enumerated().map { index, input in
            RecordDetail(
                header: header,
                setNumber: index + 1,
                weight: Double(input.weight) ?? 0,
                weightUnit: unit,
                repetitions: Int(input.reps) ?? 0,
                memo: input.memo.isEmpty ? nil : input.memo
            )
        }
        for detail in details {
            modelContext.insert(detail)
        }
        header.details = details
        saveContext()
    }

    func fetchExerciseForRecord() -> Exercise? {
        var descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.id == exerciseID }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    func fetchRecordHeader(for date: Date) -> RecordHeader? {
        let targetDate = calendar.startOfDay(for: date)
        var descriptor = FetchDescriptor<RecordHeader>(
            predicate: #Predicate { $0.exercise.id == exerciseID && $0.date == targetDate }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    func saveContext() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}
