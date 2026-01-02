import Foundation
import SwiftData
import Testing
@testable import workout

struct ExerciseTests {
    @Test func createExercise() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Bench Press", bodyPart: .chest)
        context.insert(exercise)
        try context.save()

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.count == 1)
    }

    @Test func readExercise() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Squat", bodyPart: .legs)
        context.insert(exercise)
        try context.save()

        let exerciseID = exercise.id
        let fetched = try context.fetch(
            FetchDescriptor<Exercise>(predicate: #Predicate<Exercise> { $0.id == exerciseID })
        )
        #expect(fetched.first?.name == "Squat")
    }

    @Test func updateExercise() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Deadlift", bodyPart: .back)
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

        let exercise = Exercise(name: "Pull Up", bodyPart: .back)
        context.insert(exercise)
        try context.save()

        context.delete(exercise)
        try context.save()

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        #expect(exercises.isEmpty)
    }
}
