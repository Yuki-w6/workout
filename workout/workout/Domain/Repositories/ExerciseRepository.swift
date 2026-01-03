import Foundation

protocol ExerciseRepository {
    func fetchAll() -> [Exercise]
    func fetch(id: UUID) -> Exercise?
    func addExercise(name: String, bodyPart: BodyPart) -> Exercise
    func updateExercise(id: UUID, name: String, bodyPart: BodyPart) -> Exercise?
    func updateExerciseRecord(id: UUID, unit: WeightUnit, sets: [ExerciseSet]) -> Exercise?
    func deleteExercise(id: UUID) -> Bool
}
