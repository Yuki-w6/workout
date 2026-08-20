import Foundation

struct RestoreExerciseUseCase {
    let repository: ExerciseRepository

    @discardableResult
    func execute(id: UUID) -> Bool {
        do {
            try repository.unarchive(id)
            return true
        } catch {
            return false
        }
    }
}
