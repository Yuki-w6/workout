import Foundation

struct FetchExercisesUseCase {
    private let repository: ExerciseRepository

    init(repository: ExerciseRepository) {
        self.repository = repository
    }

    func execute(includeArchived: Bool = false) -> [Exercise] {
        do {
            return try repository.fetchAll(includeArchived: includeArchived)
        } catch {
            return []
        }
    }
}
