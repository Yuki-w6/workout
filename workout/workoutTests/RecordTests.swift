import Foundation
import SwiftData
import Testing
@testable import WorkoutLogJP2026WOD01

struct RecordTests {
    private func makeExercise(context: ModelContext) throws -> Exercise {
        let exercise = Exercise(name: "Deadlift", bodyPart: .back, defaultWeightUnit: .kg)
        context.insert(exercise)
        try context.save()
        return exercise
    }

    private func makeHeader(context: ModelContext, exercise: Exercise) throws -> RecordHeader {
        let header = RecordHeader(date: Date(), exercise: exercise)
        context.insert(header)
        try context.save()
        return header
    }

    @Test func addRecordHeader() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = RecordHeader(date: Date(), exercise: exercise)
        context.insert(header)
        try context.save()

        let headers = try context.fetch(FetchDescriptor<RecordHeader>())
        #expect(headers.count == 1)
    }

    @Test func getRecordHeader() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = RecordHeader(date: Date(), exercise: exercise)
        context.insert(header)
        try context.save()

        let headerID = header.id
        let fetched = try context.fetch(
            FetchDescriptor<RecordHeader>(predicate: #Predicate<RecordHeader> { $0.id == headerID })
        )
        #expect(fetched.first?.exercise?.name == "Deadlift")
    }

    @Test func editRecordHeader() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = RecordHeader(date: Date(timeIntervalSince1970: 0), exercise: exercise)
        context.insert(header)
        try context.save()

        let newDate = Date(timeIntervalSince1970: 86_400)
        header.date = newDate
        try context.save()

        let headerID = header.id
        let fetched = try context.fetch(
            FetchDescriptor<RecordHeader>(predicate: #Predicate<RecordHeader> { $0.id == headerID })
        )
        #expect(fetched.first?.date == newDate)
    }

    @Test func deleteRecordHeader() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = RecordHeader(date: Date(), exercise: exercise)
        context.insert(header)
        try context.save()

        context.delete(header)
        try context.save()

        let headers = try context.fetch(FetchDescriptor<RecordHeader>())
        #expect(headers.isEmpty)
    }

    @Test func addRecordSet() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = try makeHeader(context: context, exercise: exercise)
        let set = RecordSet(
            setNumber: 1,
            weight: 60.0,
            weightUnit: .kg,
            repetitions: 5,
            header: header
        )
        context.insert(set)
        try context.save()

        let sets = try context.fetch(FetchDescriptor<RecordSet>())
        #expect(sets.count == 1)
    }

    @Test func getRecordSet() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = try makeHeader(context: context, exercise: exercise)
        let set = RecordSet(
            setNumber: 1,
            weight: 80.0,
            weightUnit: .kg,
            repetitions: 3,
            header: header
        )
        context.insert(set)
        try context.save()

        let setID = set.id
        let fetched = try context.fetch(
            FetchDescriptor<RecordSet>(predicate: #Predicate<RecordSet> { $0.id == setID })
        )
        #expect(fetched.first?.weight == 80.0)
    }

    @Test func editRecordSet() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = try makeHeader(context: context, exercise: exercise)
        let set = RecordSet(
            setNumber: 1,
            weight: 40.0,
            weightUnit: .kg,
            repetitions: 8,
            memo: "Controlled",
            header: header
        )
        context.insert(set)
        try context.save()

        set.weight = 42.5
        set.repetitions = 6
        set.memo = nil
        try context.save()

        let setID = set.id
        let fetched = try context.fetch(
            FetchDescriptor<RecordSet>(predicate: #Predicate<RecordSet> { $0.id == setID })
        )
        #expect(fetched.first?.weight == 42.5)
        #expect(fetched.first?.repetitions == 6)
        #expect(fetched.first?.memo == nil)
    }

    @Test func deleteRecordSet() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = try makeHeader(context: context, exercise: exercise)
        let set = RecordSet(
            setNumber: 1,
            weight: 70.0,
            weightUnit: .kg,
            repetitions: 4,
            header: header
        )
        context.insert(set)
        try context.save()

        context.delete(set)
        try context.save()

        let sets = try context.fetch(FetchDescriptor<RecordSet>())
        #expect(sets.isEmpty)
    }

    @Test func getRecordHeaderList() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        context.insert(RecordHeader(date: Date(), exercise: exercise))
        context.insert(RecordHeader(date: Date().addingTimeInterval(-3600), exercise: exercise))
        try context.save()

        let headers = try context.fetch(FetchDescriptor<RecordHeader>())
        #expect(headers.count == 2)
    }

    @Test func getRecordSetList() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = try makeHeader(context: context, exercise: exercise)
        context.insert(RecordSet(
            setNumber: 1,
            weight: 60.0,
            weightUnit: .kg,
            repetitions: 5,
            header: header
        ))
        context.insert(RecordSet(
            setNumber: 2,
            weight: 60.0,
            weightUnit: .kg,
            repetitions: 5,
            header: header
        ))
        try context.save()

        let sets = try context.fetch(FetchDescriptor<RecordSet>())
        #expect(sets.count == 2)
    }
}
