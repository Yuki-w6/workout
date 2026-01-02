import Foundation

protocol ExerciseRepository {
    func fetchAll() -> [Exercise]
    func fetch(id: UUID) -> Exercise?
    func addExercise(name: String, bodyPart: BodyPart) -> Exercise
    func updateExercise(id: UUID, name: String, bodyPart: BodyPart) -> Exercise?
    func deleteExercise(id: UUID) -> Bool
}
