import Foundation

@MainActor
final class ExerciseListViewModel: ObservableObject {
    @Published private(set) var exercises: [Exercise] = []

    private let fetchExercises: FetchExercisesUseCase
    private let fetchExerciseUseCase: FetchExerciseUseCase
    private let addExercise: AddExerciseUseCase
    private let updateExerciseUseCase: UpdateExerciseUseCase
    private let deleteExerciseUseCase: DeleteExerciseUseCase

    init(
        fetchExercises: FetchExercisesUseCase,
        fetchExercise: FetchExerciseUseCase,
        addExercise: AddExerciseUseCase,
        updateExercise: UpdateExerciseUseCase,
        deleteExercise: DeleteExerciseUseCase
    ) {
        self.fetchExercises = fetchExercises
        self.fetchExerciseUseCase = fetchExercise
        self.addExercise = addExercise
        self.updateExerciseUseCase = updateExercise
        self.deleteExerciseUseCase = deleteExercise
    }

    func load() {
        exercises = fetchExercises.execute()
    }

    func exercise(id: UUID) -> Exercise? {
        fetchExerciseUseCase.execute(id: id)
    }

    func addExercise(name: String, bodyPart: BodyPart) {
        _ = addExercise.execute(name: name, bodyPart: bodyPart)
        load()
    }

    func updateExercise(id: UUID, name: String, bodyPart: BodyPart) {
        _ = updateExerciseUseCase.execute(id: id, name: name, bodyPart: bodyPart)
        load()
    }

    func deleteExercises(at offsets: IndexSet) -> [UUID] {
        let ids = offsets.compactMap { index in
            exercises.indices.contains(index) ? exercises[index].id : nil
        }
        return deleteExercises(ids: ids)
    }

    func deleteExercises(ids: [UUID]) -> [UUID] {
        var failedIds: [UUID] = []
        for id in ids {
            let deleted = deleteExerciseUseCase.execute(id: id)
            if !deleted {
                failedIds.append(id)
            }
        }
        load()
        return failedIds
    }
}
