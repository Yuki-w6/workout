import Foundation
import Testing
@testable import WorkoutLogJP2026WOD01

struct ReviewRequestPolicyTests {
    @Test func doesNotRequestBeforeReachingRequiredSaveCount() {
        let policy = ReviewRequestPolicy(requiredSaveCount: 3)

        #expect(policy.shouldRequest(saveCount: 0, hasRequested: false) == false)
        #expect(policy.shouldRequest(saveCount: 2, hasRequested: false) == false)
    }

    @Test func requestsOnceRequiredSaveCountIsReached() {
        let policy = ReviewRequestPolicy(requiredSaveCount: 3)

        #expect(policy.shouldRequest(saveCount: 3, hasRequested: false) == true)
    }

    @Test func keepsRequestingAllowedAfterOvershootingWhenNotYetRequested() {
        // 判定中に保存が進んで閾値を飛び越えた場合でも、まだ出していなければ出す
        let policy = ReviewRequestPolicy(requiredSaveCount: 3)

        #expect(policy.shouldRequest(saveCount: 10, hasRequested: false) == true)
    }

    @Test func neverRequestsTwice() {
        let policy = ReviewRequestPolicy(requiredSaveCount: 3)

        #expect(policy.shouldRequest(saveCount: 3, hasRequested: true) == false)
        #expect(policy.shouldRequest(saveCount: 100, hasRequested: true) == false)
    }
}
