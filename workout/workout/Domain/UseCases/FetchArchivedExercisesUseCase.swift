import Foundation

struct FetchArchivedExercisesUseCase {
    private let repository: ExerciseRepository

    init(repository: ExerciseRepository) {
        self.repository = repository
    }

    func execute() -> [Exercise] {
        do {
            return try repository.fetchArchived()
        } catch {
            return []
        }
    }
}
