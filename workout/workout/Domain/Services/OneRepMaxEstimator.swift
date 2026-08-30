import Foundation

/// 推定1RM(1回だけ挙げられる最大重量の推定値)を求める。
///
/// O'Conner式 `1RM = 重量 × (1 + 回数 / 40)` を使う。
/// 実測ではなく計算値なので、画面上も「推定1RM」と表示する。
/// 「最大RM」という表記はRMが回数を指す用語のため意味が通らず、使わない。
struct OneRepMaxEstimator {
    func estimate(weight: Double, repetitions: Int) -> Double {
        weight * (1 + Double(repetitions) / 40.0)
    }
}
