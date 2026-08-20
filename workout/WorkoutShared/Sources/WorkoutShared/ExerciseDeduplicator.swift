import Foundation

/// 同じ `id` を持つ `Exercise` を1件に畳む。
///
/// CloudKit(NSPersistentCloudKitContainer)は unique constraint をサポートしないため、
/// `Exercise.id` が同じレコードが複数同期されることがある。
/// 実体の掃除はiPhone側(`AppContainer`)が担当するが、掃除が走って同期が届くまでの間、
/// Watchでは同じ種目が重複して並んでしまう。表示側でも畳んでおく。
public enum ExerciseDeduplicator {
    public static func deduplicatedByID(_ exercises: [Exercise]) -> [Exercise] {
        var seen: Set<UUID> = []
        var result: [Exercise] = []
        result.reserveCapacity(exercises.count)
        for exercise in exercises where seen.insert(exercise.id).inserted {
            result.append(exercise)
        }
        return result
    }
}
