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

    func addSampleExercise() {
        let bodyPart = BodyPart.allCases.randomElement() ?? .fullBody
        _ = addExercise.execute(name: "New Exercise", bodyPart: bodyPart)
        load()
    }

    func updateExercise(id: UUID, name: String, bodyPart: BodyPart) {
        _ = updateExerciseUseCase.execute(id: id, name: name, bodyPart: bodyPart)
        load()
    }

    func deleteExercises(at offsets: IndexSet) {
        let ids = offsets.compactMap { index in
            exercises.indices.contains(index) ? exercises[index].id : nil
        }
        for id in ids {
            _ = deleteExerciseUseCase.execute(id: id)
        }
        load()
    }
}
