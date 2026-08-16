import Foundation
import Testing
@testable import WorkoutLogJP2026WOD01

struct SetProgressionPredictorTests {
    @Test func usesPreviousSessionDeltaWhenAvailable() {
        // 前回: 1セット目40kg -> 2セット目35kg (差分-5kg)
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg)
        let pastHeader = makeHeader(
            for: exercise,
            date: Date(timeIntervalSince1970: 0),
            sets: [(1, 40.0, 8), (2, 35.0, 6)]
        )

        let predictor = SetProgressionPredictor()
        let result = predictor.predictNextSet(
            todayWeights: [42.5],
            todayReps: [10],
            history: [pastHeader],
            unit: .kg
        )

        #expect(result?.weight == 37.5) // 42.5 + (-5)
        #expect(result?.reps == 10) // 直前セットの回数をそのまま引き継ぐ
    }

    @Test func fallsBackToTodaysOwnDeltaWhenPreviousSessionLacksTargetSet() {
        // 前回は3セットで、今回は4セット目を予測する
        let exercise = Exercise(name: "Squat", bodyPart: .legs, defaultWeightUnit: .kg)
        let pastHeader = makeHeader(
            for: exercise,
            date: Date(timeIntervalSince1970: 0),
            sets: [(1, 50.0, 10), (2, 48.0, 8), (3, 46.0, 6)]
        )

        let predictor = SetProgressionPredictor()
        let result = predictor.predictNextSet(
            todayWeights: [50.0, 48.0, 46.0],
            todayReps: [10, 8, 6],
            history: [pastHeader],
            unit: .kg
        )

        // 前回に4セット目が無いため、今回の直近2セットの差分(46-48=-2)を46に適用
        #expect(result?.weight == 44.0)
        #expect(result?.reps == 6)
    }

    @Test func carriesOverUnchangedWhenNoDeltaSourceExists() {
        // 前回は1セットのみ、今回はまだ1セットしか記録していない
        let exercise = Exercise(name: "Deadlift", bodyPart: .back, defaultWeightUnit: .kg)
        let pastHeader = makeHeader(
            for: exercise,
            date: Date(timeIntervalSince1970: 0),
            sets: [(1, 40.0, 5)]
        )

        let predictor = SetProgressionPredictor()
        let result = predictor.predictNextSet(
            todayWeights: [40.0],
            todayReps: [5],
            history: [pastHeader],
            unit: .kg
        )

        #expect(result?.weight == 40.0)
        #expect(result?.reps == 5)
    }

    @Test func usesMostRecentPastSessionOnly() {
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg)
        let olderHeader = makeHeader(
            for: exercise,
            date: Date(timeIntervalSince1970: 0),
            sets: [(1, 100.0, 5), (2, 90.0, 5)] // 差分-10
        )
        let newerHeader = makeHeader(
            for: exercise,
            date: Date(timeIntervalSince1970: 86_400),
            sets: [(1, 105.0, 5), (2, 100.0, 5)] // 差分-5
        )

        let predictor = SetProgressionPredictor()
        let result = predictor.predictNextSet(
            todayWeights: [110.0],
            todayReps: [5],
            history: [olderHeader, newerHeader],
            unit: .kg
        )

        // 直近セッション(差分-5)が使われ、古いセッション(差分-10)は無視される
        #expect(result?.weight == 105.0)
    }

    @Test func ignoresRecordsWithMismatchedWeightUnit() {
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg)
        let pastHeaderLbs = makeHeader(
            for: exercise,
            date: Date(timeIntervalSince1970: 0),
            sets: [(1, 100.0, 5), (2, 90.0, 5)],
            unit: .lb
        )

        let predictor = SetProgressionPredictor()
        let result = predictor.predictNextSet(
            todayWeights: [40.0],
            todayReps: [5],
            history: [pastHeaderLbs],
            unit: .kg
        )

        // unit不一致で前回データは使えず、今回の差分も無いのでそのまま維持
        #expect(result?.weight == 40.0)
    }

    @Test func ignoresEmptyMostRecentHeaderAndFallsBackToOlderValidHistory() {
        // Watch側の先行作成等で、今日の空ヘッダー(setsなし)が一番新しい日付として
        // 存在していても、有効なセットを持つ1つ前の履歴が使われるべき。
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg)
        let olderHeader = makeHeader(
            for: exercise,
            date: Date(timeIntervalSince1970: 0),
            sets: [(1, 100.0, 5), (2, 95.0, 5)] // 差分-5
        )
        let emptyTodayHeader = RecordHeader(date: Date(timeIntervalSince1970: 86_400), exercise: exercise)

        let predictor = SetProgressionPredictor()
        let result = predictor.predictNextSet(
            todayWeights: [110.0],
            todayReps: [5],
            history: [olderHeader, emptyTodayHeader],
            unit: .kg
        )

        #expect(result?.weight == 105.0) // 110 + (-5)
    }

    @Test func returnsNilWhenTodayHasNoSetsYet() {
        let predictor = SetProgressionPredictor()
        let result = predictor.predictNextSet(
            todayWeights: [],
            todayReps: [],
            history: [],
            unit: .kg
        )

        #expect(result == nil)
    }

    private func makeHeader(
        for exercise: Exercise,
        date: Date,
        sets: [(setNumber: Int, weight: Double, reps: Int)],
        unit: WeightUnit = .kg
    ) -> RecordHeader {
        let header = RecordHeader(date: date, exercise: exercise)
        header.sets = sets.map { setNumber, weight, reps in
            RecordSet(
                setNumber: setNumber,
                weight: weight,
                weightUnit: unit,
                repetitions: reps,
                header: header
            )
        }
        return header
    }
}
