import Foundation
import SwiftData

final class SwiftDataExerciseRepository: ExerciseRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>()
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    func fetch(id: UUID) -> Exercise? {
        var descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    func addExercise(name: String, bodyPart: BodyPart) -> Exercise {
        let exercise = Exercise(name: name, bodyPart: bodyPart)
        modelContext.insert(exercise)
        save()
        return exercise
    }

    func updateExercise(id: UUID, name: String, bodyPart: BodyPart) -> Exercise? {
        guard let exercise = fetch(id: id) else {
            return nil
        }
        exercise.name = name
        exercise.bodyPart = bodyPart
        save()
        return exercise
    }

    func updateExerciseRecord(id: UUID, unit: WeightUnit, sets: [ExerciseSet]) -> Exercise? {
        guard let exercise = fetch(id: id) else {
            return nil
        }
        for existingSet in exercise.sets {
            modelContext.delete(existingSet)
        }
        for set in sets {
            modelContext.insert(set)
        }
        exercise.weightUnit = unit
        exercise.sets = sets
        save()
        return exercise
    }

    func deleteExercise(id: UUID) -> Bool {
        guard let exercise = fetch(id: id) else {
            return false
        }
        var recordDescriptor = FetchDescriptor<RecordHeader>(
            predicate: #Predicate { $0.exercise.id == id }
        )
        recordDescriptor.fetchLimit = 1
        if let existing = try? modelContext.fetch(recordDescriptor), !existing.isEmpty {
            return false
        }
        modelContext.delete(exercise)
        save()
        return true
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }
}
