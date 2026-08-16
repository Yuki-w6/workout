import SwiftUI
import SwiftData
import WorkoutShared

struct RecordInputView: View {
    let exercise: Exercise

    @Environment(\.modelContext) private var modelContext
    @Query private var todayHeaders: [RecordHeader]

    @State private var weight: Double
    @State private var reps: Int

    init(exercise: Exercise) {
        self.exercise = exercise
        let exerciseID = exercise.id
        let startOfDay = Calendar.japaneseLocale.startOfDay(for: Date())
        _todayHeaders = Query(
            filter: #Predicate<RecordHeader> { $0.exerciseIDSnapshot == exerciseID && $0.date == startOfDay }
        )
        _weight = State(initialValue: 20)
        _reps = State(initialValue: 10)
    }

    private var todaySets: [RecordSet] {
        (todayHeaders.first?.sets ?? []).sorted { $0.setNumber < $1.setNumber }
    }

    private var nextSetNumber: Int {
        (todaySets.map(\.setNumber).max() ?? 0) + 1
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Stepper(value: $weight, in: 0...500, step: 2.5) {
                    Text("\(formatted(weight)) \(exercise.defaultWeightUnit.displayName)")
                        .font(.title3)
                }

                Stepper(value: $reps, in: 1...50) {
                    Text("\(reps) 回")
                        .font(.title3)
                }

                Button("セット\(nextSetNumber)を記録") {
                    addSet()
                }
                .buttonStyle(.borderedProminent)

                if !todaySets.isEmpty {
                    Divider()
                    ForEach(todaySets, id: \.id) { set in
                        HStack {
                            Text("\(set.setNumber)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(formatted(set.weight))\(set.weightUnit.displayName) × \(set.repetitions)")
                        }
                        .font(.caption)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .task(id: todaySets.count) {
            applySuggestion()
        }
    }

    private func applySuggestion() {
        guard let lastSet = todaySets.last else {
            applyFirstSetSuggestion()
            return
        }
        applySubsequentSetSuggestion(after: lastSet)
    }

    private func applyFirstSetSuggestion() {
        let repository = SwiftDataRecordRepository(context: modelContext)
        guard let history = try? repository.fetchHeaders(for: exercise.id), !history.isEmpty else {
            return
        }
        let predictor = ExerciseRecordPredictor()
        let predictions = predictor.predict(records: history, unit: exercise.defaultWeightUnit, maxSetNumber: 1)
        if let prediction = predictions[1] {
            if let predictedWeight = prediction.weight {
                weight = predictedWeight
            }
            if let predictedReps = prediction.reps {
                reps = predictedReps
            }
        }
    }

    private func applySubsequentSetSuggestion(after lastSet: RecordSet) {
        let repository = SwiftDataRecordRepository(context: modelContext)
        let todayHeaderID = todayHeaders.first?.id
        let history = ((try? repository.fetchHeaders(for: exercise.id)) ?? [])
            .filter { $0.id != todayHeaderID }

        let progressionPredictor = SetProgressionPredictor()
        if let prediction = progressionPredictor.predictNextSet(
            todayWeights: todaySets.map(\.weight),
            todayReps: todaySets.map(\.repetitions),
            history: history,
            unit: exercise.defaultWeightUnit
        ) {
            weight = prediction.weight
            reps = prediction.reps
        }
    }

    private func addSet() {
        let startOfDay = Calendar.japaneseLocale.startOfDay(for: Date())
        let header: RecordHeader
        if let existing = todayHeaders.first {
            header = existing
        } else {
            header = RecordHeader(date: startOfDay, exercise: exercise)
            modelContext.insert(header)
        }
        let newSet = RecordSet(
            setNumber: nextSetNumber,
            weight: weight,
            weightUnit: exercise.defaultWeightUnit,
            repetitions: reps,
            header: header
        )
        modelContext.insert(newSet)
        header.sets = (header.sets ?? []) + [newSet]
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }

    private func formatted(_ value: Double) -> String {
        let rounded = (value * 2).rounded() / 2
        return rounded.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", rounded)
            : String(format: "%.1f", rounded)
    }
}

private extension Calendar {
    // iPhone側(ExerciseDetailView等)と同じ定義。日付の起点計算を完全に一致させ、
    // 同日のRecordHeaderがCloudKit経由で重複せず1件に統合されるようにする。
    static var japaneseLocale: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }
}
