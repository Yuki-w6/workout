import Foundation

protocol ExerciseRepository {
    func fetchAll() -> [Exercise]
    func addExercise(name: String, bodyPart: BodyPart) -> Exercise
}
