import Foundation
import SwiftData
import Testing
@testable import WorkoutLogJP2026WOD01

struct ExerciseTests {
    @Test func addExercise() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg)
        context.insert(exercise)
        try context.save()

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.count == 1)
    }

    @Test func getExercise() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Squat", bodyPart: .legs, defaultWeightUnit: .kg)
        context.insert(exercise)
        try context.save()

        let exerciseID = exercise.id
        let fetched = try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate<Exercise> { $0.id == exerciseID })
        )
        #expect(fetched.first?.name == "Squat")
    }

    @Test func editExercise() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Deadlift", bodyPart: .back, defaultWeightUnit: .kg)
        context.insert(exercise)
        try context.save()

        exercise.name = "Romanian Deadlift"
        try context.save()

        let exerciseID = exercise.id
        let fetched = try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate<Exercise> { $0.id == exerciseID })
        )
        #expect(fetched.first?.name == "Romanian Deadlift")
    }

    @Test func deleteExercise() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Pull Up", bodyPart: .back, defaultWeightUnit: .kg)
        context.insert(exercise)
        try context.save()

        context.delete(exercise)
        try context.save()

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.isEmpty)
    }

    @Test func getExerciseList() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        context.insert(Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg))
        context.insert(Exercise(name: "Overhead Press", bodyPart: .shoulders, defaultWeightUnit: .kg))
        try context.save()

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.count == 2)
    }
}
