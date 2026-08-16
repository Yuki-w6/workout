import Foundation
import SwiftData
import Testing
import WorkoutShared

// RecordInputView.init が組み立てる @Query のフィルタ（exerciseIDSnapshot + date）と
// 同じ形のFetchDescriptorを使い、「種目1でセット記録後、種目2を開くとセット数が
// 引き継がれる」という報告のうち、クエリ自体が他種目のデータを混ぜ込んでいないかを検証する。
// ⚠️実際のバグはSwiftUIのビューアイデンティティ（@Queryストレージの使い回し）に起因しており、
// ここではそれを再現できない。ここで担保するのはクエリ述語自体が正しく種目単位に
// 分離されている、という前提条件のみ。

private func makeWatchTestContainer() throws -> ModelContainer {
    let schema = Schema([
        Exercise.self,
        ExerciseTemplateSet.self,
        RecordHeader.self,
        RecordSet.self,
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
}

private var todayStartInJapan: Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "ja_JP")
    return calendar.startOfDay(for: Date())
}

private func nextSetNumber(for exerciseID: UUID, in context: ModelContext) throws -> Int {
    let startOfDay = todayStartInJapan
    let descriptor = FetchDescriptor<RecordHeader>(
        predicate: #Predicate { $0.exerciseIDSnapshot == exerciseID && $0.date == startOfDay }
    )
    let headers = try context.fetch(descriptor)
    let sets = headers.first?.sets ?? []
    return (sets.map(\.setNumber).max() ?? 0) + 1
}

// RecordEntryPage.ensureTodayHeaderExists() と同じ「無ければ作る」ロジックを直接再現する。
private func ensureTodayHeaderExists(for exercise: Exercise, in context: ModelContext) throws {
    let exerciseID = exercise.id
    let startOfDay = todayStartInJapan
    let descriptor = FetchDescriptor<RecordHeader>(
        predicate: #Predicate<RecordHeader> { $0.exerciseIDSnapshot == exerciseID && $0.date == startOfDay }
    )
    guard try context.fetch(descriptor).first == nil else { return }
    let header = RecordHeader(date: startOfDay, exercise: exercise)
    context.insert(header)
    try context.save()
}

@Suite("RecordInputViewの今日のセット数クエリ")
struct RecordInputViewQueryTests {

    @Test("種目ごとにtodayHeadersが分離され、次のセット番号が他種目に引き継がれない")
    func nextSetNumberDoesNotLeakBetweenExercises() throws {
        let container = try makeWatchTestContainer()
        let context = ModelContext(container)

        let benchPress = Exercise(name: "ベンチプレス", bodyPart: .chest, defaultWeightUnit: .kg)
        let squat = Exercise(name: "スクワット", bodyPart: .legs, defaultWeightUnit: .kg)
        context.insert(benchPress)
        context.insert(squat)

        // ベンチプレスは今日2セット記録済み
        let benchHeader = RecordHeader(date: todayStartInJapan, exercise: benchPress)
        context.insert(benchHeader)
        let benchSet1 = RecordSet(setNumber: 1, weight: 60, weightUnit: .kg, repetitions: 10, header: benchHeader)
        let benchSet2 = RecordSet(setNumber: 2, weight: 62.5, weightUnit: .kg, repetitions: 8, header: benchHeader)
        context.insert(benchSet1)
        context.insert(benchSet2)
        benchHeader.sets = [benchSet1, benchSet2]

        try context.save()

        // ベンチプレス側は「セット3」が次
        #expect(try nextSetNumber(for: benchPress.id, in: context) == 3)

        // スクワットは今日まだ記録がないので「セット1」が次（ベンチプレスの記録数が漏れ出さない）
        #expect(try nextSetNumber(for: squat.id, in: context) == 1)
    }

    @Test("同じ種目・別の日のヘッダーは今日のセット数に数えない")
    func headerFromYesterdayIsNotCountedAsToday() throws {
        let container = try makeWatchTestContainer()
        let context = ModelContext(container)

        let deadlift = Exercise(name: "デッドリフト", bodyPart: .back, defaultWeightUnit: .kg)
        context.insert(deadlift)

        let yesterday = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: todayStartInJapan)!
        let yesterdayHeader = RecordHeader(date: yesterday, exercise: deadlift)
        context.insert(yesterdayHeader)
        let yesterdaySet = RecordSet(setNumber: 1, weight: 100, weightUnit: .kg, repetitions: 5, header: yesterdayHeader)
        context.insert(yesterdaySet)
        yesterdayHeader.sets = [yesterdaySet]

        try context.save()

        #expect(try nextSetNumber(for: deadlift.id, in: context) == 1)
    }

    @Test("画面表示時の先行ヘッダー作成はsets 0件で作られ、次のセット番号は1のまま")
    func ensureTodayHeaderExistsCreatesEmptyHeader() throws {
        let container = try makeWatchTestContainer()
        let context = ModelContext(container)

        let benchPress = Exercise(name: "ベンチプレス", bodyPart: .chest, defaultWeightUnit: .kg)
        context.insert(benchPress)
        try context.save()

        try ensureTodayHeaderExists(for: benchPress, in: context)

        let exerciseID = benchPress.id
        let startOfDay = todayStartInJapan
        let headers = try context.fetch(
            FetchDescriptor<RecordHeader>(
                predicate: #Predicate<RecordHeader> { $0.exerciseIDSnapshot == exerciseID && $0.date == startOfDay }
            )
        )
        #expect(headers.count == 1)
        #expect(headers.first?.hasRecordedSets == false)
        #expect(try nextSetNumber(for: benchPress.id, in: context) == 1)
    }

    @Test("先行ヘッダー作成は冪等で、複数回呼んでも重複作成されない")
    func ensureTodayHeaderExistsIsIdempotent() throws {
        let container = try makeWatchTestContainer()
        let context = ModelContext(container)

        let squat = Exercise(name: "スクワット", bodyPart: .legs, defaultWeightUnit: .kg)
        context.insert(squat)
        try context.save()

        try ensureTodayHeaderExists(for: squat, in: context)
        try ensureTodayHeaderExists(for: squat, in: context)
        try ensureTodayHeaderExists(for: squat, in: context)

        let headers = try context.fetch(FetchDescriptor<RecordHeader>())
        #expect(headers.count == 1)
    }
}
