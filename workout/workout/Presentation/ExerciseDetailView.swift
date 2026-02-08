import SwiftUI
import SwiftData
import UIKit

struct ExerciseDetailView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    let exerciseID: UUID
    let exercise: Exercise?
    let isNewRecord: Bool
    let initialDate: Date?
    let onSave: ((String) -> Void)?
    @State private var isEditing = false
    @State private var draftName = ""
    @State private var draftBodyPart: BodyPart = .chest
    @State private var unit: WeightUnit = .kg
    @State private var sets: [ExerciseSetInput] = ExerciseSetInput.defaultSets()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var recordDate = Date()
    @State private var lastLoadedDate = Date()
    @State private var originalRecordDate: Date?
    @State private var scrollToSetIndex: Int?
    @FocusState private var focusedField: FocusField?
    @AppStorage("lastWeightUnit") private var lastWeightUnitRaw = WeightUnit.kg.rawValue

    private let calendar = Calendar.japaneseLocale
    private static let recordDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter
    }()
    private static let weightFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    init(
        viewModel: ExerciseListViewModel,
        exerciseID: UUID,
        exercise: Exercise? = nil,
        isNewRecord: Bool,
        initialDate: Date?,
        onSave: ((String) -> Void)? = nil
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.exerciseID = exerciseID
        self.exercise = exercise
        self.isNewRecord = isNewRecord
        self.initialDate = initialDate
        self.onSave = onSave
    }

    private enum FocusField: Hashable {
        case weight(Int)
        case reps(Int)
        case memo(Int)
    }

    private var currentExercise: Exercise? {
        exercise ?? viewModel.exercise(id: exerciseID)
    }

    private var formattedRecordDate: String {
        Self.recordDateFormatter.string(from: recordDate)
    }

    private var focusableFields: [FocusField] {
        sets.indices.flatMap { index in
            [.weight(index), .reps(index), .memo(index)]
        }
    }

    private var focusableFieldsWithoutMemo: [FocusField] {
        sets.indices.flatMap { index in
            [.weight(index), .reps(index)]
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    dateSection
                    setsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: scrollToSetIndex) {
                guard let index = scrollToSetIndex else {
                    return
                }
                let delay = 0.0
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation {
                        proxy.scrollTo(setRowID(index), anchor: .center)
                    }
                }
                scrollToSetIndex = nil
            }
        }
        .navigationBarBackButtonHidden(true)
        .onChange(of: focusedField) {
            selectAllIfNeeded(for: focusedField)
        }
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
                    let message = isNewRecord ? "記録しました" : "変更しました"
                    onSave?(message)
                    dismiss()
                }
                .accessibilityLabel("記録を保存")
            }
            ToolbarItem(placement: .keyboard) {
                HStack(spacing: 12) {
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
                .frame(maxWidth: .infinity, alignment: .trailing)
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
            originalRecordDate = isNewRecord ? nil : normalized
            loadRecord(for: normalized, focusAfterLoad: true)
        }
        .onChange(of: recordDate) { _, newValue in
            handleRecordDateChange(to: newValue)
        }
        .onChange(of: unit) { _, newValue in
            lastWeightUnitRaw = newValue.rawValue
        }
    }

    private func loadRecord(for date: Date, focusAfterLoad: Bool) {
        guard let exercise = exercise ?? fetchExerciseForRecord() else {
            return
        }
        if let record = fetchRecordHeader(for: date) {
            let sortedDetails = (record.sets ?? []).sorted { $0.setNumber < $1.setNumber }
            if let firstUnit = sortedDetails.first?.weightUnit {
                unit = firstUnit
                lastWeightUnitRaw = firstUnit.rawValue
            }
            let loadedSets = sortedDetails.map { ExerciseSetInput(from: $0) }
            sets = loadedSets.isEmpty ? ExerciseSetInput.defaultSets() : loadedSets
            if sets.last.map(isEmptySet) != true {
                sets.append(ExerciseSetInput())
            }
            if focusAfterLoad {
                setInitialFocus(toLastSet: true)
            }
        } else {
            unit = WeightUnit(rawValue: lastWeightUnitRaw) ?? exercise.defaultWeightUnit
            let templateSets = fetchTemplateSets(for: exercise)
            if templateSets.isEmpty {
                sets = ExerciseSetInput.defaultSets()
            } else {
                sets = templateSets.map { ExerciseSetInput(from: $0) }
            }
            if sets.last.map(isEmptySet) != true {
                sets.append(ExerciseSetInput())
            }
            if focusAfterLoad {
                setInitialFocus(toLastSet: false)
            }
        }
    }

    private func saveRecord(for date: Date) {
        guard let exercise = fetchExerciseForRecord() else {
            return
        }
        saveTemplateSets(for: exercise)
        saveWorkoutRecord(for: date, exercise: exercise)
    }

    private func handleRecordDateChange(to newDate: Date) {
        let normalized = calendar.startOfDay(for: newDate)
        guard normalized != lastLoadedDate else {
            return
        }
        if !isNewRecord {
            lastLoadedDate = normalized
            return
        }
        focusedField = nil
        loadRecord(for: normalized, focusAfterLoad: false)
        lastLoadedDate = normalized
    }

    private func setInitialFocus(toLastSet: Bool) {
        let targetIndex = toLastSet ? max(sets.count - 1, 0) : 0
        DispatchQueue.main.async {
            focusedField = .weight(targetIndex)
        }
    }

    private func focusNextField() {
        let fields = fieldsForNavigation(from: focusedField)
        guard !fields.isEmpty else {
            return
        }
        guard let current = focusedField,
              let index = fields.firstIndex(of: current) else {
            focusedField = fields.first
            return
        }
        let nextIndex = index + 1
        if nextIndex < fields.count {
            let nextField = fields[nextIndex]
            if focusedSetIndex(from: nextField) != focusedSetIndex(from: current) {
                scrollToSetIndex = focusedSetIndex(from: nextField)
            }
            focusedField = nextField
            return
        }
        sets.append(ExerciseSetInput())
        DispatchQueue.main.async {
            let newIndex = max(sets.count - 1, 0)
            focusedField = .weight(newIndex)
            scrollToSetIndex = newIndex
        }
    }

    private func focusPreviousField() {
        let fields = fieldsForNavigation(from: focusedField)
        guard let current = focusedField,
              let index = fields.firstIndex(of: current) else {
            return
        }
        let previousIndex = index - 1
        guard previousIndex >= 0 else {
            return
        }
        let previousField = fields[previousIndex]
        if focusedSetIndex(from: previousField) != focusedSetIndex(from: current) {
            scrollToSetIndex = focusedSetIndex(from: previousField)
        }
        focusedField = previousField
    }

    private func focusedSetIndex(from focusField: FocusField) -> Int {
        switch focusField {
        case .weight(let index), .reps(let index), .memo(let index):
            return index
        }
    }

    private func setRowID(_ index: Int) -> String {
        "set-row-\(index)"
    }

    private func fieldsForNavigation(from focusField: FocusField?) -> [FocusField] {
        guard let focusField else {
            return focusableFieldsWithoutMemo
        }
        switch focusField {
        case .memo:
            return focusableFields
        case .weight, .reps:
            return focusableFieldsWithoutMemo
        }
    }

    private func selectAllIfNeeded(for focusField: FocusField?) {
        guard let focusField else {
            return
        }
        switch focusField {
        case .weight, .reps:
            DispatchQueue.main.async {
                UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
            }
        case .memo:
            break
        }
    }

}

private extension ExerciseDetailView {
    var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("日付")
                .font(.headline)
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
                    .environment(\.calendar, calendar)
                    .environment(\.locale, calendar.locale ?? .current)
                    .labelsHidden()
                    .opacity(0.02)
                    .accessibilityLabel("日付")
                    Text(formattedRecordDate)
                        .monospacedDigit()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(Capsule())
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    var setsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("セット")
                    .font(.headline)
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
            .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 12) {
            ForEach(Array($sets.enumerated()), id: \.element.id) { index, $set in
                VStack(alignment: .leading, spacing: 12) {
                    Text("セット \(index + 1)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                            .frame(width: 28, alignment: .leading)
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
                .id(setRowID(index))
                if index < sets.count - 1 {
                    Divider()
                }
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
            .padding(.top, 4)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

private extension Calendar {
    static var japaneseLocale: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }
}

private struct ExerciseSetInput: Identifiable {
    let id = UUID()
    var weight: String = ""
    var reps: String = ""
    var memo: String = ""

    init() {}

    init(from template: ExerciseTemplateSet) {
        if let weight = template.weight, weight > 0 {
            self.weight = String(weight)
        }
        if let reps = template.reps, reps > 0 {
            self.reps = String(reps)
        }
        memo = template.memo ?? ""
    }

    init(from recordSet: RecordSet) {
        weight = recordSet.weight == 0 ? "" : String(recordSet.weight)
        reps = recordSet.repetitions == 0 ? "" : String(recordSet.repetitions)
        memo = recordSet.memo ?? ""
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
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
            .foregroundStyle(isEmphasized ? Color.accentColor : Color.primary)
            .frame(height: 32)
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

    func fetchTemplateSets(for exercise: Exercise) -> [ExerciseTemplateSet] {
        let exerciseID = exercise.id
        let descriptor = FetchDescriptor<ExerciseTemplateSet>(
            predicate: #Predicate { $0.exercise?.id == exerciseID },
            sortBy: [SortDescriptor(\.order, order: .forward)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func saveTemplateSets(for exercise: Exercise) {
        exercise.defaultWeightUnit = unit

        let existing = fetchTemplateSets(for: exercise)
        for template in existing {
            modelContext.delete(template)
        }

        let newTemplates = sets.enumerated().map { index, input in
            ExerciseTemplateSet(
                order: index,
                weight: Double(input.weight),
                reps: Int(input.reps),
                memo: input.memo.isEmpty ? nil : input.memo,
                exercise: exercise
            )
        }
        for template in newTemplates {
            modelContext.insert(template)
        }
        saveContext()
    }

    func saveWorkoutRecord(for date: Date, exercise: Exercise) {
        let trimmedSets = sets.filter { input in
            !(input.weight.isEmpty && input.reps.isEmpty && input.memo.isEmpty)
        }
        let targetDate = calendar.startOfDay(for: date)
        let originalDate = originalRecordDate.map { calendar.startOfDay(for: $0) }
        if trimmedSets.isEmpty {
            if let existing = fetchRecordHeader(for: targetDate) {
                modelContext.delete(existing)
            }
            if !isNewRecord, let originalDate, originalDate != targetDate,
               let originalHeader = fetchRecordHeader(for: originalDate) {
                modelContext.delete(originalHeader)
            }
            saveContext()
            originalRecordDate = nil
            return
        }

        let header: RecordHeader
        if let existing = fetchRecordHeader(for: targetDate) {
            header = existing
            for recordSet in existing.sets ?? [] {
                modelContext.delete(recordSet)
            }
        } else {
            header = RecordHeader(date: targetDate, exercise: exercise)
            modelContext.insert(header)
        }

        let recordSets = trimmedSets.enumerated().map { index, input in
            RecordSet(
                setNumber: index + 1,
                weight: Double(input.weight) ?? 0,
                weightUnit: unit,
                repetitions: Int(input.reps) ?? 0,
                memo: input.memo.isEmpty ? nil : input.memo,
                header: header
            )
        }
        for recordSet in recordSets {
            modelContext.insert(recordSet)
        }
        header.sets = recordSets
        if !isNewRecord, let originalDate, originalDate != targetDate,
           let originalHeader = fetchRecordHeader(for: originalDate) {
            modelContext.delete(originalHeader)
        }
        saveContext()
        originalRecordDate = targetDate
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
            predicate: #Predicate { $0.exerciseIDSnapshot == exerciseID && $0.date == targetDate }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }


    func formatWeight(_ weight: Double) -> String {
        let rounded = (weight * 2).rounded() / 2
        let number = NSNumber(value: rounded)
        return Self.weightFormatter.string(from: number) ?? String(format: "%.1f", weight)
    }

    func saveContext() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}
