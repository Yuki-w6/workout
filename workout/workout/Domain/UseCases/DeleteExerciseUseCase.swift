import Foundation

struct DeleteExerciseUseCase {
    let repository: ExerciseRepository

    func execute(id: UUID) -> Bool {
        repository.deleteExercise(id: id)
    }
}
