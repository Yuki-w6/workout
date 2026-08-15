import Foundation
import SwiftData

@Model
public final class RecordHeader {
    public var id: UUID = UUID()
    public var date: Date = Date()

    // ---- スナップショット（履歴を壊さないため） ----
    public var exerciseIDSnapshot: UUID = UUID()
    public var exerciseNameSnapshot: String = ""
    public var bodyPartRawSnapshot: String = BodyPart.other.rawValue
    public var defaultWeightUnitRawSnapshot: String = WeightUnit.kg.rawValue

    @Relationship(inverse: \Exercise.recordHeaders)
    public var exercise: Exercise? = nil

    @Relationship(inverse: \RecordSet.header)
    public var sets: [RecordSet]? = []

    public init(
        id: UUID = UUID(),
        date: Date,
        exercise: Exercise
    ) {
        self.id = id
        self.date = date

        // 参照とスナップショットを同時に保存
        self.exercise = exercise
        self.exerciseIDSnapshot = exercise.id
        self.exerciseNameSnapshot = exercise.name
        self.bodyPartRawSnapshot = exercise.bodyPartRaw
        self.defaultWeightUnitRawSnapshot = exercise.defaultWeightUnitRaw
    }

    public var bodyPartSnapshot: BodyPart {
        BodyPart(rawValue: bodyPartRawSnapshot) ?? .other
    }

    public var defaultWeightUnitSnapshot: WeightUnit {
        WeightUnit(rawValue: defaultWeightUnitRawSnapshot) ?? .kg
    }
}
