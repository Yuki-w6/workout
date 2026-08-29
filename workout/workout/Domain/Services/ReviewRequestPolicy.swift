import Foundation

/// レビュー依頼を出してよいかを判定する。
/// - 記録が積み上がって「続けて使えている」と言える段階に入ってから初めて出す。
/// - 一度出したら二度と出さない。Apple側にも表示回数の上限があり、
///   こちらから何度も呼ぶと単に無視されるだけで、ユーザーには煩わしさだけが残るため。
struct ReviewRequestPolicy {
    /// この回数の記録を保存したら依頼する。
    let requiredSaveCount: Int

    init(requiredSaveCount: Int = 3) {
        self.requiredSaveCount = requiredSaveCount
    }

    func shouldRequest(saveCount: Int, hasRequested: Bool) -> Bool {
        guard !hasRequested else {
            return false
        }
        return saveCount >= requiredSaveCount
    }
}
