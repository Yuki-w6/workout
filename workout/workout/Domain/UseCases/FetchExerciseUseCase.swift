import Foundation

struct FetchExerciseUseCase {
    let repository: ExerciseRepository

    func execute(id: UUID) -> Exercise? {
        repository.fetch(id: id)
    }
}
