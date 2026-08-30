import Foundation
import SwiftData

/// 記録が1件でもある種目だけに絞る。グラフの一覧に使う。
enum RecordedExerciseFilter {
    static func exercisesWithRecords(exercises: [Exercise], records: [RecordHeader]) -> [Exercise] {
        let idsWithRecords = Set(
            records
                .filter { $0.hasRecordedSets }
                .map(\.exerciseIDSnapshot)
        )
        return exercises.filter { exercise in
            // ❗ ViewModelが持つ配列には、正規化で削除された種目が残っていることがある。
            // 全画面広告を閉じるとアプリがアクティブに戻り、その通知で正規化が走るため、
            // 広告を閉じた直後にこの状態になりやすい。
            // 削除済みのインスタンスはプロパティに触れた時点でSwiftDataが停止するので、
            // idを読む前に弾く。
            guard !exercise.isDeleted, exercise.modelContext != nil else {
                return false
            }
            return idsWithRecords.contains(exercise.id)
        }
    }
}
