import Foundation

final class InMemoryExerciseRepository: ExerciseRepository {
    private var exercises: [Exercise]

    init(initialExercises: [Exercise] = []) {
        self.exercises = initialExercises
    }

    func fetchAll() -> [Exercise] {
        exercises
    }

    func fetch(id: UUID) -> Exercise? {
        exercises.first { $0.id == id }
    }

    func addExercise(name: String, bodyPart: BodyPart) -> Exercise {
        let exercise = Exercise(name: name, bodyPart: bodyPart)
        exercises.append(exercise)
        return exercise
    }

    func updateExercise(id: UUID, name: String, bodyPart: BodyPart) -> Exercise? {
        guard let index = exercises.firstIndex(where: { $0.id == id }) else {
            return nil
        }
        exercises[index].name = name
        exercises[index].bodyPart = bodyPart
        return exercises[index]
    }

    func deleteExercise(id: UUID) -> Bool {
        guard let index = exercises.firstIndex(where: { $0.id == id }) else {
            return false
        }
        exercises.remove(at: index)
        return true
    }
}
