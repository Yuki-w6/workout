import Foundation

struct UpdateExerciseUseCase {
    let repository: ExerciseRepository

    func execute(id: UUID, name: String, bodyPart: BodyPart) -> Exercise? {
        do {
            guard let exercise = try repository.fetch(by: id) else {
                return nil
            }
            exercise.name = name
            exercise.bodyPart = bodyPart
            try repository.upsert(exercise)
            return exercise
        } catch {
            return nil
        }
    }
}
