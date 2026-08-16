import Foundation

/// 2セット目以降のデフォルト値を算出する。
/// - 重量: 前回セッションの同一セット番号間の差分を、今回の直前セットの重量に適用する。
///   前回セッションにその番号の記録がなければ、今回すでに入力済みの直近2セットの差分にフォールバックする。
///   どちらもなければ直前の値をそのまま使う。
/// - 回数: 直前のセットの回数をそのまま引き継ぐ。
struct SetProgressionPredictor {
    func predictNextSet(
        todayWeights: [Double],
        todayReps: [Int],
        history: [RecordHeader],
        unit: WeightUnit
    ) -> (weight: Double, reps: Int)? {
        guard let previousWeight = todayWeights.last, let previousReps = todayReps.last else {
            return nil
        }
        let targetSetNumber = todayWeights.count + 1
        let weight = predictWeight(
            targetSetNumber: targetSetNumber,
            previousWeight: previousWeight,
            todayWeights: todayWeights,
            history: history,
            unit: unit
        )
        return (weight, previousReps)
    }

    private func predictWeight(
        targetSetNumber: Int,
        previousWeight: Double,
        todayWeights: [Double],
        history: [RecordHeader],
        unit: WeightUnit
    ) -> Double {
        let previousSetNumber = targetSetNumber - 1

        if let mostRecentPast = history.filter(\.hasRecordedSets).max(by: { $0.date < $1.date }) {
            let pastSets = (mostRecentPast.sets ?? []).filter { $0.weightUnit == unit }
            if let previousPastSet = pastSets.first(where: { $0.setNumber == previousSetNumber }),
               let targetPastSet = pastSets.first(where: { $0.setNumber == targetSetNumber }) {
                return previousWeight + (targetPastSet.weight - previousPastSet.weight)
            }
        }

        if todayWeights.count >= 2 {
            let secondLastWeight = todayWeights[todayWeights.count - 2]
            return previousWeight + (previousWeight - secondLastWeight)
        }

        return previousWeight
    }
}
