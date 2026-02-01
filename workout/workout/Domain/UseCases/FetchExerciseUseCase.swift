import Foundation

struct FetchExerciseUseCase {
    let repository: ExerciseRepository

    func execute(id: UUID) -> Exercise? {
        do {
            return try repository.fetch(by: id)
        } catch {
            return nil
        }
    }
}
