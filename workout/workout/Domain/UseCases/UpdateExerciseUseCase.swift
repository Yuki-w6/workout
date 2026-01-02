import Foundation

struct UpdateExerciseUseCase {
    let repository: ExerciseRepository

    func execute(id: UUID, name: String, bodyPart: BodyPart) -> Exercise? {
        repository.updateExercise(id: id, name: name, bodyPart: bodyPart)
    }
}
