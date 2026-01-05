import Foundation
import Testing
@testable import workout

struct ExerciseRecordPredictorTests {
    @Test func predictionsAreStableAcrossRecordOrder() {
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest)
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
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest)
        let record1 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 0), weight: 100, reps: 5)
        let record2 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 86_400), weight: 110, reps: 4)
        let record3 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 172_800), weight: 120, reps: 3)

        let predictor = ExerciseRecordPredictor()
        let predictions = predictor.predict(
            records: [record1, record2, record3],
            unit: .kg,
            maxSetNumber: 1
        )

        #expect(predictions[1]?.weight == 100)
        #expect(predictions[1]?.reps == 5)
    }

    @Test func predictionsIgnoreMismatchedWeightUnit() {
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest)
        let recordKg1 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 0), weight: 100, reps: 5, unit: .kg)
        let recordKg2 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 86_400), weight: 110, reps: 4, unit: .kg)
        let recordLbs = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 172_800), weight: 200, reps: 10, unit: .lbs)

        let predictor = ExerciseRecordPredictor()
        let predictions = predictor.predict(
            records: [recordKg1, recordLbs, recordKg2],
            unit: .kg,
            maxSetNumber: 1
        )

        #expect(predictions[1]?.weight == 95)
        #expect(predictions[1]?.reps == 6)
    }

    @Test func predictionsAreEmptyWhenNoRecords() {
        let predictor = ExerciseRecordPredictor()
        let predictions = predictor.predict(records: [], unit: .kg, maxSetNumber: 3)
        #expect(predictions.isEmpty)
    }

    @Test func predictionsHandleWeightOnlySamples() {
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest)
        let record1 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 0), weight: 100, reps: 0)
        let record2 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 86_400), weight: 110, reps: 0)
        let record3 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 172_800), weight: 120, reps: 0)

        let predictor = ExerciseRecordPredictor()
        let predictions = predictor.predict(records: [record1, record2, record3], unit: .kg, maxSetNumber: 1)

        #expect(predictions[1]?.weight == 100)
        #expect(predictions[1]?.reps == nil)
    }

    @Test func predictionsHandleRepsOnlySamples() {
        let exercise = Exercise(name: "Bench Press", bodyPart: .chest)
        let record1 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 0), weight: 0, reps: 5)
        let record2 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 86_400), weight: 0, reps: 4)
        let record3 = makeRecord(for: exercise, date: Date(timeIntervalSince1970: 172_800), weight: 0, reps: 3)

        let predictor = ExerciseRecordPredictor()
        let predictions = predictor.predict(records: [record1, record2, record3], unit: .kg, maxSetNumber: 1)

        #expect(predictions[1]?.weight == nil)
        #expect(predictions[1]?.reps == 5)
    }

    private func makeRecord(
        for exercise: Exercise,
        date: Date,
        weight: Double,
        reps: Int,
        unit: WeightUnit = .kg
    ) -> RecordHeader {
        let header = RecordHeader(date: date, exercise: exercise)
        let detail = RecordDetail(
            header: header,
            setNumber: 1,
            weight: weight,
            weightUnit: unit,
            repetitions: reps
        )
        header.details = [detail]
        return header
    }
}
