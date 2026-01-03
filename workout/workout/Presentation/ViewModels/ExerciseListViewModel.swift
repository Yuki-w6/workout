import Foundation

@MainActor
final class ExerciseListViewModel: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []

    private let fetchExercises: FetchExercisesUseCase
    private let fetchExerciseUseCase: FetchExerciseUseCase
    private let addExercise: AddExerciseUseCase
    private let updateExerciseUseCase: UpdateExerciseUseCase
    private let updateExerciseRecordUseCase: UpdateExerciseRecordUseCase
    private let deleteExerciseUseCase: DeleteExerciseUseCase

    init(
        fetchExercises: FetchExercisesUseCase,
        fetchExercise: FetchExerciseUseCase,
        addExercise: AddExerciseUseCase,
        updateExercise: UpdateExerciseUseCase,
        updateExerciseRecord: UpdateExerciseRecordUseCase,
        deleteExercise: DeleteExerciseUseCase
    ) {
        self.fetchExercises = fetchExercises
        self.fetchExerciseUseCase = fetchExercise
        self.addExercise = addExercise
        self.updateExerciseUseCase = updateExercise
        self.updateExerciseRecordUseCase = updateExerciseRecord
        self.deleteExerciseUseCase = deleteExercise
    }

    func load() {
        exercises = fetchExercises.execute()
    }

    func exercise(id: UUID) -> Exercise? {
        fetchExerciseUseCase.execute(id: id)
    }

    func addSampleExercise() {
        let bodyPart = BodyPart.allCases.randomElement() ?? .fullBody
        _ = addExercise.execute(name: "New Exercise", bodyPart: bodyPart)
        load()
    }

    func updateExercise(id: UUID, name: String, bodyPart: BodyPart) {
        _ = updateExerciseUseCase.execute(id: id, name: name, bodyPart: bodyPart)
        load()
    }

    func updateExerciseRecord(id: UUID, unit: WeightUnit, sets: [ExerciseSet]) {
        _ = updateExerciseRecordUseCase.execute(id: id, unit: unit, sets: sets)
        load()
    }

    func deleteExercises(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            exercises.indices.contains(index) ? exercises[index].id : nil
        }
        deleteExercises(ids: ids)
    }

    func deleteExercises(ids: [UUID]) {
        for id in ids {
            _ = deleteExerciseUseCase.execute(id: id)
        }
        load()
    }
}
