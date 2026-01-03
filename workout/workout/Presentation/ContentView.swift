import SwiftUI
import SwiftData

struct ContentView: View {
    @StateObject private var viewModel: ExerciseListViewModel

    init(viewModel: ExerciseListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        TabView {
            ExerciseListView(viewModel: viewModel)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            RecordListView(viewModel: viewModel)
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
    }
}

struct ExerciseListView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    @State private var searchText = ""

    private let bodyPartSections: [(bodyPart: BodyPart, title: String)] = [
        (.chest, "胸"),
        (.back, "背中"),
        (.legs, "脚"),
        (.shoulders, "肩"),
        (.arms, "腕"),
        (.glutes, "お尻"),
        (.core, "お腹"),
        (.fullBody, "全身")
    ]

    private var filteredExercises: [Exercise] {
        guard !searchText.isEmpty else {
            return viewModel.exercises
        }
        return viewModel.exercises.filter { exercise in
            exercise.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func exercises(for bodyPart: BodyPart) -> [Exercise] {
        filteredExercises.filter { $0.bodyPart == bodyPart }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                List {
                    ForEach(bodyPartSections, id: \.bodyPart) { section in
                        let sectionExercises = exercises(for: section.bodyPart)
                        Section(section.title) {
                            ForEach(sectionExercises, id: \.id) { exercise in
                                NavigationLink {
                                    ExerciseDetailView(
                                        viewModel: viewModel,
                                        exerciseID: exercise.id,
                                        isNewRecord: true,
                                        initialDate: nil
                                    )
                                } label: {
                                    Text(exercise.name)
                                        .font(.headline)
                                }
                            }
                            .onDelete { offsets in
                                let ids = offsets.compactMap { index in
                                    sectionExercises.indices.contains(index) ? sectionExercises[index].id : nil
                                }
                                viewModel.deleteExercises(ids: ids)
                            }
                        }
                    }
                }
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "種目を検索"
                )
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 72)
                }

                Button(action: viewModel.addSampleExercise) {
                    Label("新規追加", systemImage: "plus")
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .foregroundStyle(.white)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                        .shadow(radius: 4, x: 0, y: 2)
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
            .onAppear {
                viewModel.load()
            }
        }
    }
}

struct RecordListView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    @Query(sort: \RecordHeader.date) private var records: [RecordHeader]
    @State private var selectedDate = Date()
    @State private var displayedMonth = Date()
    @Environment(\.modelContext) private var modelContext

    private let calendar = Calendar.current

    private var markedDates: Set<Date> {
        Set(records.map { calendar.startOfDay(for: $0.date) })
    }

    private var recordsForSelectedDate: [RecordHeader] {
        records.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    Button {
                        shiftMonth(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    Text(monthTitle(for: monthStart))
                        .font(.headline)
                    Spacer()
                    Button {
                        shiftMonth(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                }
                .padding(.horizontal)

                CalendarMonthView(
                    month: monthStart,
                    selectedDate: $selectedDate,
                    markedDates: markedDates
                )
                .padding(.horizontal)

                List {
                    if recordsForSelectedDate.isEmpty {
                        Text("記録はありません")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(recordsForSelectedDate, id: \.id) { record in
                            Section(record.exercise.name) {
                                let sortedDetails = record.details.sorted { $0.setNumber < $1.setNumber }
                                ForEach(sortedDetails, id: \.id) { detail in
                                    NavigationLink {
                                        ExerciseDetailView(
                                            viewModel: viewModel,
                                            exerciseID: record.exercise.id,
                                            isNewRecord: false,
                                            initialDate: record.date
                                        )
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Set \(detail.setNumber)")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            Text("\(detail.weight, specifier: "%.1f") \(detail.weightUnit.rawValue) ・ \(detail.repetitions)回")
                                                .font(.headline)
                                            if let memo = detail.memo, !memo.isEmpty {
                                                Text(memo)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .padding(.vertical, 4)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            deleteDetail(detail, in: record)
                                        } label: {
                                            Label("削除", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
            .navigationTitle("History")
        }
    }

    private func deleteDetail(_ detail: RecordDetail, in record: RecordHeader) {
        if let index = record.details.firstIndex(where: { $0.id == detail.id }) {
            record.details.remove(at: index)
        }
        modelContext.delete(detail)
        let sorted = record.details.sorted { $0.setNumber < $1.setNumber }
        if sorted.isEmpty {
            modelContext.delete(record)
        } else {
            for (index, item) in sorted.enumerated() {
                item.setNumber = index + 1
            }
            record.details = sorted
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }

    private func shiftMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: monthStart) {
            displayedMonth = newMonth
            selectedDate = newMonth
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM"
        return formatter.string(from: date)
    }
}

private struct CalendarMonthView: View {
    let month: Date
    @Binding var selectedDate: Date
    let markedDates: Set<Date>

    private let calendar = Calendar.current

    private var days: [Date?] {
        guard
            let range = calendar.range(of: .day, in: .month, for: month),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month))
        else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = range.count
        let total = leading + daysInMonth
        return (0..<total).map { index in
            guard index >= leading else { return nil }
            let dayOffset = index - leading
            return calendar.date(byAdding: .day, value: dayOffset, to: firstDay)
        }
    }

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 7)
        VStack(spacing: 8) {
            let symbols = weekdaySymbols()
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(symbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(days.indices, id: \.self) { index in
                    if let date = days[index] {
                        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                        let isMarked = markedDates.contains(calendar.startOfDay(for: date))
                        Button {
                            selectedDate = date
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(calendar.component(.day, from: date))")
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity)
                                Circle()
                                    .fill(isMarked ? Color.accentColor : Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                            .padding(6)
                            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
        }
    }

    private func weekdaySymbols() -> [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let shift = max(calendar.firstWeekday - 1, 0)
        if shift == 0 {
            return symbols
        }
        return Array(symbols[shift...]) + symbols[..<shift]
    }
}

struct ExerciseDetailView: View {
    @ObservedObject var viewModel: ExerciseListViewModel
    let exerciseID: UUID
    let isNewRecord: Bool
    let initialDate: Date?
    @State private var isEditing = false
    @State private var draftName = ""
    @State private var draftBodyPart: BodyPart = .fullBody
    @State private var unit: WeightUnit = .kg
    @State private var sets: [ExerciseSetInput] = ExerciseSetInput.defaultSets()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var recordDate = Date()
    @State private var lastLoadedDate = Date()

    private let calendar = Calendar.current

    private var currentExercise: Exercise? {
        viewModel.exercise(id: exerciseID)
    }

    var body: some View {
        List {
            Section("記録日") {
                DatePicker(
                    "日付",
                    selection: Binding(
                        get: { recordDate },
                        set: { recordDate = calendar.startOfDay(for: $0) }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }
            Section("セット") {
                ForEach($sets) { $set in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            TextField("重さ", text: $set.weight)
                                .keyboardType(.decimalPad)
                            Text(unit.rawValue)
                                .foregroundStyle(.secondary)
                            TextField("回数", text: $set.reps)
                                .keyboardType(.numberPad)
                            Text("回")
                                .foregroundStyle(.secondary)
                        }
                        TextField("メモ", text: $set.memo)
                            .textInputAutocapitalization(.never)
                    }
                    .padding(.vertical, 4)
                }
                Button {
                    sets.append(ExerciseSetInput())
                } label: {
                    Label("セットを追加", systemImage: "plus")
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
                Picker("単位", selection: $unit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
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
        .onDisappear {
            saveRecord(for: lastLoadedDate)
        }
        .onChange(of: recordDate) { _, newValue in
            handleRecordDateChange(to: newValue)
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
            }
            let loadedSets = sortedDetails.map { ExerciseSetInput(from: $0) }
            sets = loadedSets.isEmpty ? ExerciseSetInput.defaultSets() : loadedSets
        } else {
            unit = exercise.weightUnit
            let loadedSets = exercise.sets
                .sorted { $0.order < $1.order }
                .map { ExerciseSetInput(from: $0) }
            sets = loadedSets.isEmpty ? ExerciseSetInput.defaultSets() : loadedSets
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
        saveRecord(for: lastLoadedDate)
        loadRecord(for: normalized)
        lastLoadedDate = normalized
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

private extension ExerciseDetailView {
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

#Preview {
    let repository = InMemoryExerciseRepository()
    let viewModel = ExerciseListViewModel(
        fetchExercises: FetchExercisesUseCase(repository: repository),
        fetchExercise: FetchExerciseUseCase(repository: repository),
        addExercise: AddExerciseUseCase(repository: repository),
        updateExercise: UpdateExerciseUseCase(repository: repository),
        updateExerciseRecord: UpdateExerciseRecordUseCase(repository: repository),
        deleteExercise: DeleteExerciseUseCase(repository: repository)
    )
    return ContentView(viewModel: viewModel)
}
