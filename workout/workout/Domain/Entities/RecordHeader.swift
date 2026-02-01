import Foundation
import SwiftData

@Model
final class RecordHeader {
    var id: UUID = UUID()
    var date: Date = Date()
    
    // ---- スナップショット（履歴を壊さないため） ----
    var exerciseIDSnapshot: UUID = UUID()
    var exerciseNameSnapshot: String = ""
    var bodyPartRawSnapshot: String = BodyPart.other.rawValue
    var defaultWeightUnitRawSnapshot: String = WeightUnit.kg.rawValue
    
    @Relationship(inverse: \Exercise.recordHeaders)
    var exercise: Exercise? = nil
    
    @Relationship(inverse: \RecordSet.header)
    var sets: [RecordSet]? = []
    
    init(
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
    
    var bodyPartSnapshot: BodyPart {
        BodyPart(rawValue: bodyPartRawSnapshot) ?? .other
    }
    
    var defaultWeightUnitSnapshot: WeightUnit {
        WeightUnit(rawValue: defaultWeightUnitRawSnapshot) ?? .kg
    }
}
