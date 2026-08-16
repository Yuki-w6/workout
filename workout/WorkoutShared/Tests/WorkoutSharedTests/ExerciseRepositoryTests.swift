import Foundation
import SwiftData
import Testing
@testable import WorkoutShared

struct ExerciseRepositoryTests {
    @Test func archiveSucceedsWhenOnlyEmptyHeaderExists() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let repository = SwiftDataExerciseRepository(context: context)

        let exercise = Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg)
        context.insert(exercise)
        // Watch側の先行作成を模した、setsが0件のヘッダー。
        let header = RecordHeader(date: Date(), exercise: exercise)
        context.insert(header)
        try context.save()

        try repository.archive(exercise.id)

        #expect(exercise.isArchived == true)
    }

    @Test func archiveThrowsWhenARealSetExists() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let repository = SwiftDataExerciseRepository(context: context)

        let exercise = Exercise(name: "Squat", bodyPart: .legs, defaultWeightUnit: .kg)
        context.insert(exercise)
        let header = RecordHeader(date: Date(), exercise: exercise)
        context.insert(header)
        let set = RecordSet(setNumber: 1, weight: 60.0, weightUnit: .kg, repetitions: 5, header: header)
        context.insert(set)
        header.sets = [set]
        try context.save()

        #expect(throws: ExerciseRepositoryError.self) {
            try repository.archive(exercise.id)
        }
        #expect(exercise.isArchived == false)
    }
}
