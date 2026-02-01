import Foundation

struct DeleteExerciseUseCase {
    let repository: ExerciseRepository

    func execute(id: UUID) -> Bool {
        do {
            try repository.archive(id)
            return true
        } catch {
            return false
        }
    }
}
