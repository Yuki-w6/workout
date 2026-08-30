import Foundation
import Testing
@testable import WorkoutLogJP2026WOD01

struct OneRepMaxEstimatorTests {
    private let estimator = OneRepMaxEstimator()

    @Test func estimatesFromWeightAndRepetitions() {
        // O'Conner式: 重量 × (1 + 回数/40)
        // 60kg × 10回 → 60 × 1.25 = 75.0
        #expect(estimator.estimate(weight: 60, repetitions: 10) == 75.0)
        // 100kg × 5回 → 100 × 1.125 = 112.5
        #expect(estimator.estimate(weight: 100, repetitions: 5) == 112.5)
    }

    @Test func oneRepetitionIsSlightlyAboveTheLiftedWeight() {
        #expect(estimator.estimate(weight: 80, repetitions: 1) == 82.0)
    }

    @Test func returnsTheWeightItselfWhenRepetitionsAreZero() {
        // 回数が記録されていないセットでも重量ぶんは返す(既存の挙動を維持)
        #expect(estimator.estimate(weight: 50, repetitions: 0) == 50.0)
    }

    @Test func returnsZeroWhenWeightIsZero() {
        #expect(estimator.estimate(weight: 0, repetitions: 10) == 0.0)
    }

    @Test func moreRepetitionsEstimateAHigherMax() {
        let fewer = estimator.estimate(weight: 70, repetitions: 5)
        let more = estimator.estimate(weight: 70, repetitions: 12)
        #expect(more > fewer)
    }
}
