import Foundation
import SwiftData
import Testing
@testable import WorkoutShared

struct RecordHeaderTests {
    @Test func hasRecordedSetsIsFalseForEmptyHeader() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg)
        context.insert(exercise)
        let header = RecordHeader(date: Date(), exercise: exercise)
        context.insert(header)
        try context.save()

        #expect(header.hasRecordedSets == false)
    }

    @Test func hasRecordedSetsIsTrueOnceASetExists() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = Exercise(name: "Squat", bodyPart: .legs, defaultWeightUnit: .kg)
        context.insert(exercise)
        let header = RecordHeader(date: Date(), exercise: exercise)
        context.insert(header)
        let set = RecordSet(setNumber: 1, weight: 60, weightUnit: .kg, repetitions: 5, header: header)
        context.insert(set)
        header.sets = [set]
        try context.save()

        #expect(header.hasRecordedSets == true)
    }
}
