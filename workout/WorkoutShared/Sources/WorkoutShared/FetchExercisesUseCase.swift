import Foundation

public struct FetchExercisesUseCase {
    private let repository: ExerciseRepository

    public init(repository: ExerciseRepository) {
        self.repository = repository
    }

    public func execute(includeArchived: Bool = false) -> [Exercise] {
        do {
            return try repository.fetchAll(includeArchived: includeArchived)
        } catch {
            return []
        }
    }
}
