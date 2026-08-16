import Foundation
import SwiftData

@Model
public final class ExerciseTemplateSet {
    public var id: UUID = UUID()
    public var order: Int = 0

    // テンプレは数値型に寄せると集計/UIが楽
    public var weight: Double?
    public var reps: Int?
    public var memo: String?

    // 親は non-optional 推奨（整合性を崩さない）
    @Relationship(inverse: \Exercise.templateSets)
    public var exercise: Exercise?

    public init(
        id: UUID = UUID(),
        order: Int,
        weight: Double? = nil,
        reps: Int? = nil,
        memo: String? = nil,
        exercise: Exercise
    ) {
        self.id = id
        self.order = order
        self.weight = weight
        self.reps = reps
        self.memo = memo
        self.exercise = exercise
    }
}
