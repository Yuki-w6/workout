import Foundation
import SwiftData
import Testing
@testable import WorkoutShared

struct ExerciseDeduplicatorTests {
    @Test func collapsesExercisesSharingTheSameID() throws {
        let sharedID = UUID()
        let first = Exercise(
            id: sharedID,
            name: "ベンチプレス",
            bodyPart: .chest,
            defaultWeightUnit: .kg,
            isPreset: true,
            seedKey: "bench_press"
        )
        let duplicate = Exercise(
            id: sharedID,
            name: "ベンチプレス",
            bodyPart: .chest,
            defaultWeightUnit: .kg,
            isPreset: true,
            seedKey: "bench_press"
        )
        let other = Exercise(name: "スクワット", bodyPart: .legs, defaultWeightUnit: .kg)

        let result = ExerciseDeduplicator.deduplicatedByID([first, duplicate, other])

        #expect(result.count == 2)
        // 先に現れた方を残す(クエリのソート順を壊さない)。
        #expect(result[0] === first)
        #expect(result[1] === other)
    }

    @Test func keepsOrderAndReturnsAllWhenThereAreNoDuplicates() throws {
        let a = Exercise(name: "A", bodyPart: .chest, defaultWeightUnit: .kg)
        let b = Exercise(name: "B", bodyPart: .back, defaultWeightUnit: .kg)

        let result = ExerciseDeduplicator.deduplicatedByID([a, b])

        #expect(result.map { $0.id } == [a.id, b.id])
    }

    @Test func returnsEmptyForEmptyInput() throws {
        #expect(ExerciseDeduplicator.deduplicatedByID([]).isEmpty)
    }
}
