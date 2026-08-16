import Foundation
import Testing
@testable import WorkoutLogJP2026WOD01

struct ExerciseRecordPredictorTests {
    @Test func predictionsAreStableAcrossRecordOrder() {
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg)
        let record1 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 0), weight: 100, reps: 5)
        let record2 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 86_400), weight: 110, reps: 4)
        let record3 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 172_800), weight: 120, reps: 3)

        let predictor = ExerciseRecordPredictor()
        let ascending = [record1, record2, record3]
        let shuffled = [record3, record1, record2]

        let expected = predictor.predict(records: ascending, unit: .kg, maxSetNumber: 1)
        let actual = predictor.predict(records: shuffled, unit: .kg, maxSetNumber: 1)

        #expect(actual[1]?.weight == expected[1]?.weight)
        #expect(actual[1]?.reps == expected[1]?.reps)
    }

    @Test func predictionsFollowTrendAdjustedAverage() {
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg)
        let record1 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 0), weight: 100, reps: 5)
        let record2 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 86_400), weight: 110, reps: 4)
        let record3 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 172_800), weight: 120, reps: 3)

        let predictor = ExerciseRecordPredictor()
        let predictions = predictor.predict(
            records: [record1, record2, record3],
            unit: .kg,
            maxSetNumber: 1
        )

        // weight 100->110->120 (upward trend): average(110) + trend(+10) = 120
        #expect(predictions[1]?.weight == 120)
        // reps 5->4->3 (downward trend): average(4) + trend(-1) = 3
        #expect(predictions[1]?.reps == 3)
    }

    @Test func predictionsIgnoreMismatchedWeightUnit() {
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg)
        let recordKg1 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 0), weight: 100, reps: 5, unit: .kg)
        let recordKg2 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 86_400), weight: 110, reps: 4, unit: .kg)
        let recordLbs = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 172_800), weight: 200, reps: 10, unit: .lb)

        let predictor = ExerciseRecordPredictor()
        let predictions = predictor.predict(
            records: [recordKg1, recordLbs, recordKg2],
            unit: .kg,
            maxSetNumber: 1
        )

        // lbs record is filtered out; only 100kg->110kg remain: average(105) + trend(+10) = 115
        #expect(predictions[1]?.weight == 115)
        // only 5->4 reps remain: average(4.5) + trend(-1) = 3.5, rounded = 4
        #expect(predictions[1]?.reps == 4)
    }

    @Test func predictionsAreEmptyWhenNoRecords() {
        let predictor = ExerciseRecordPredictor()
        let predictions = predictor.predict(records: [], unit: .kg, maxSetNumber: 3)
        #expect(predictions.isEmpty)
    }

    @Test func predictionsHandleWeightOnlySamples() {
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg)
        let record1 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 0), weight: 100, reps: 0)
        let record2 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 86_400), weight: 110, reps: 0)
        let record3 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 172_800), weight: 120, reps: 0)

        let predictor = ExerciseRecordPredictor()
        let predictions = predictor.predict(records: [record1, record2, record3], unit: .kg, maxSetNumber: 1)

        #expect(predictions[1]?.weight == 120)
        #expect(predictions[1]?.reps == nil)
    }

    @Test func predictionsHandleRepsOnlySamples() {
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest, defaultWeightUnit: .kg)
        let record1 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 0), weight: 0, reps: 5)
        let record2 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 86_400), weight: 0, reps: 4)
        let record3 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 172_800), weight: 0, reps: 3)

        let predictor = ExerciseRecordPredictor()
        let predictions = predictor.predict(records: [record1, record2, record3], unit: .kg, maxSetNumber: 1)

        #expect(predictions[1]?.weight == nil)
        #expect(predictions[1]?.reps == 3)
    }

    private func makeRecord(
        for exercise: Exercise,
        date: Date,
        weight: Double,
        reps: Int,
        unit: WeightUnit = .kg
    ) -> RecordHeader {
        let header = RecordHeader(date: date, exercise: exercise)
        let set = RecordSet(
            setNumber: 1,
            weight: weight,
            weightUnit: unit,
            repetitions: reps,
            header: header
        )
        header.sets = [set]
        return header
    }
}
