import Foundation

struct FetchExercisesUseCase {
    private let repository: ExerciseRepository

    init(repository: ExerciseRepository) {
        self.repository = repository
    }

    func execute() -> [Exercise] {
        repository.fetchAll()
    }
}
