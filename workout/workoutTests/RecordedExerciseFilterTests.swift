import Foundation
import SwiftData
import Testing
@testable import WorkoutLogJP2026WOD01

/// 全画面広告を閉じた直後にグラフタブが落ちた件の回帰テスト。
///
/// 広告を閉じるとアプリがアクティブに戻り、AppContainerの正規化が走って
/// 重複した種目を削除する。ViewModelが保持している配列には削除済みの
/// インスタンスが残るため、そのままプロパティに触れるとSwiftDataが停止する。
@MainActor
struct RecordedExerciseFilterTests {
    private func makeExercise(_ name: String, in context: ModelContext) -> Exercise {
        let exercise = Exercise(name: name, bodyPart: .chest, defaultWeightUnit: .kg)
        context.insert(exercise)
        return exercise
    }

    private func addRecord(to exercise: Exercise, in context: ModelContext) {
        let header = RecordHeader(date: Date(), exercise: exercise)
        context.insert(header)
        let set = RecordSet(setNumber: 1, weight: 60, weightUnit: .kg, repetitions: 10, header: header)
        context.insert(set)
        header.sets = [set]
    }

    @Test func returnsOnlyExercisesThatHaveRecords() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let withRecord = makeExercise("ベンチプレス", in: context)
        let withoutRecord = makeExercise("チェストプレス", in: context)
        addRecord(to: withRecord, in: context)
        try context.save()

        let headers = try context.fetch(FetchDescriptor<RecordHeader>())
        let result = RecordedExerciseFilter.exercisesWithRecords(
            exercises: [withRecord, withoutRecord],
            records: headers
        )

        #expect(result.map(\.name) == ["ベンチプレス"])
    }

    @Test func skipsExercisesThatWereAlreadyDeleted() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let alive = makeExercise("ベンチプレス", in: context)
        let doomed = makeExercise("重複したベンチプレス", in: context)
        addRecord(to: alive, in: context)
        addRecord(to: doomed, in: context)
        try context.save()

        let headers = try context.fetch(FetchDescriptor<RecordHeader>())
        // 正規化が重複を消した状態を作る
        context.delete(doomed)
        try context.save()

        // 削除済みインスタンスが配列に残っていても停止してはいけない
        let result = RecordedExerciseFilter.exercisesWithRecords(
            exercises: [alive, doomed],
            records: headers
        )

        #expect(result.map(\.name) == ["ベンチプレス"])
    }

    @Test func returnsEmptyWhenThereAreNoRecords() throws {
        let container = try makeTestContainer()
        let context = ModelContext(container)
        let exercise = makeExercise("ベンチプレス", in: context)
        try context.save()

        let result = RecordedExerciseFilter.exercisesWithRecords(exercises: [exercise], records: [])

        #expect(result.isEmpty)
    }
}
