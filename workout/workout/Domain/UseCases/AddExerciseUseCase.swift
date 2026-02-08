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

    func executePreset(_ preset: PresetExerciseDefinition) -> Exercise {
        let exercise = Exercise(
            id: preset.id,
            name: preset.name,
            bodyPart: preset.bodyPart,
            defaultWeightUnit: preset.defaultWeightUnit,
            isPreset: true,
            seedKey: preset.seedKey,
            seedVersion: preset.seedVersion,
            isArchived: false
        )
        do {
            try repository.upsert(exercise)
        } catch {
            // noop
        }
        return exercise
    }
}
