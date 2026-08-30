import Foundation
import Testing
@testable import WorkoutLogJP2026WOD01

struct GraphPeriodTests {
    /// rawValue は @AppStorage("lastGraphPeriod") に保存される。
    /// case名を変えるとユーザーの選択が黙って既定値に戻るため、値を固定する。
    @Test func rawValuesArePersistedAndMustNotChange() {
        #expect(GraphPeriod.oneWeek.rawValue == "oneWeek")
        #expect(GraphPeriod.oneMonth.rawValue == "oneMonth")
        #expect(GraphPeriod.threeMonths.rawValue == "threeMonths")
        #expect(GraphPeriod.sixMonths.rawValue == "sixMonths")
        #expect(GraphPeriod.oneYear.rawValue == "oneYear")
    }

    @Test func roundTripsThroughRawValue() {
        for period in GraphPeriod.allCases {
            #expect(GraphPeriod(rawValue: period.rawValue) == period)
        }
    }

    @Test func unknownRawValueDoesNotResolve() {
        // 保存値が壊れていたら nil になり、呼び出し側の既定値(3か月)に落ちる
        #expect(GraphPeriod(rawValue: "quarterly") == nil)
    }
}
