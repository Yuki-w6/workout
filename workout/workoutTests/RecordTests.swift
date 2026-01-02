import Foundation
import SwiftData
import Testing
@testable import workout

struct RecordTests {
    private func makeExercise(context: ModelContext) throws -> Exercise {
        let exercise = Exercise(name: "Deadlift", bodyPart: .back)
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

    @Test func createRecordHeader() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = RecordHeader(date: Date(), exercise: exercise)
        context.insert(header)
        try context.save()

        let headers = try context.fetch(FetchDescriptor<RecordHeader>())
        #expect(headers.count == 1)
    }

    @Test func readRecordHeader() throws {
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
        #expect(fetched.first?.exercise.name == "Deadlift")
    }

    @Test func updateRecordHeader() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let menu = Menu(name: "Pull Day", exercises: [exercise])
        context.insert(menu)
        let header = RecordHeader(date: Date(), menu: menu, exercise: exercise)
        context.insert(header)
        try context.save()

        header.menu = nil
        try context.save()

        let headerID = header.id
        let fetched = try context.fetch(
            FetchDescriptor<RecordHeader>(predicate: #Predicate<RecordHeader> { $0.id == headerID })
        )
        #expect(fetched.first?.menu == nil)
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

    @Test func createRecordDetail() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = try makeHeader(context: context, exercise: exercise)
        let detail = RecordDetail(
            header: header,
            setNumber: 1,
            weight: 60.0,
            weightUnit: .kilogram,
            repetitions: 5
        )
        context.insert(detail)
        try context.save()

        let details = try context.fetch(FetchDescriptor<RecordDetail>())
        #expect(details.count == 1)
    }

    @Test func readRecordDetail() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = try makeHeader(context: context, exercise: exercise)
        let detail = RecordDetail(
            header: header,
            setNumber: 1,
            weight: 80.0,
            weightUnit: .kilogram,
            repetitions: 3
        )
        context.insert(detail)
        try context.save()

        let detailID = detail.id
        let fetched = try context.fetch(
            FetchDescriptor<RecordDetail>(predicate: #Predicate<RecordDetail> { $0.id == detailID })
        )
        #expect(fetched.first?.weight == 80.0)
    }

    @Test func updateRecordDetail() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = try makeHeader(context: context, exercise: exercise)
        let detail = RecordDetail(
            header: header,
            setNumber: 1,
            weight: 40.0,
            weightUnit: .kilogram,
            repetitions: 8,
            memo: "Controlled"
        )
        context.insert(detail)
        try context.save()

        detail.weight = 42.5
        detail.repetitions = 6
        detail.memo = nil
        try context.save()

        let detailID = detail.id
        let fetched = try context.fetch(
            FetchDescriptor<RecordDetail>(predicate: #Predicate<RecordDetail> { $0.id == detailID })
        )
        #expect(fetched.first?.weight == 42.5)
        #expect(fetched.first?.repetitions == 6)
        #expect(fetched.first?.memo == nil)
    }

    @Test func deleteRecordDetail() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)

        let exercise = try makeExercise(context: context)
        let header = try makeHeader(context: context, exercise: exercise)
        let detail = RecordDetail(
            header: header,
            setNumber: 1,
            weight: 70.0,
            weightUnit: .kilogram,
            repetitions: 4
        )
        context.insert(detail)
        try context.save()

        context.delete(detail)
        try context.save()

        let details = try context.fetch(FetchDescriptor<RecordDetail>())
        #expect(details.isEmpty)
    }
}
