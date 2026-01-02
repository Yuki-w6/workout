import Foundation

final class InMemoryExerciseRepository: ExerciseRepository {
    private var exercises: [Exercise]

    init(initialExercises: [Exercise] = []) {
        self.exercises = initialExercises
    }

    func fetchAll() -> [Exercise] {
        exercises
    }

    func addExercise(name: String, bodyPart: BodyPart) -> Exercise {
        let exercise = Exercise(name: name, bodyPart: bodyPart)
        exercises.append(exercise)
        return exercise
    }
}
