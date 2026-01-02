import Foundation

struct AddExerciseUseCase {
    private let repository: ExerciseRepository

    init(repository: ExerciseRepository) {
        self.repository = repository
    }

    func execute(name: String, bodyPart: BodyPart) -> Exercise {
        repository.addExercise(name: name, bodyPart: bodyPart)
    }
}
