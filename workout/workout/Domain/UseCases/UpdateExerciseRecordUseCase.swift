import Foundation

struct UpdateExerciseRecordUseCase {
    let repository: ExerciseRepository

    func execute(id: UUID, unit: WeightUnit, sets: [ExerciseSet]) -> Exercise? {
        repository.updateExerciseRecord(id: id, unit: unit, sets: sets)
    }
}
