import Foundation
import Testing
@testable import WorkoutShared

struct SetProgressionPredictorTests {
    @Test func usesPreviousSessionDeltaWhenAvailable() {
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

        #expect(result?.weight == 37.5)
        #expect(result?.reps == 10)
    }

    @Test func fallsBackToTodaysOwnDeltaWhenPreviousSessionLacksTargetSet() {
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

        #expect(result?.weight == 44.0)
        #expect(result?.reps == 6)
    }

    @Test func carriesOverUnchangedWhenNoDeltaSourceExists() {
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
            sets: [(1, 100.0, 5), (2, 90.0, 5)]
        )
        let newerHeader = makeHeader(
            for: exercise,
            date: Date(timeIntervalSince1970: 86_400),
            sets: [(1, 105.0, 5), (2, 100.0, 5)]
        )

        let predictor = SetProgressionPredictor()
        let result = predictor.predictNextSet(
            todayWeights: [110.0],
            todayReps: [5],
            history: [olderHeader, newerHeader],
            unit: .kg
        )

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

        #expect(result?.weight == 40.0)
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
