import Foundation

struct AddExerciseUseCase {
    private let repository: ExerciseRepository

    init(repository: ExerciseRepository) {
        self.repository = repository
    }

    func execute(name: String, bodyPart: BodyPart) -> Exercise {
        let exercise = Exercise(
            name: name,
            bodyPart: bodyPart,
            defaultWeightUnit: .kg
        )
        do {
            try repository.upsert(exercise)
        } catch {
            // noop
        }
        return exercise
    }
}
