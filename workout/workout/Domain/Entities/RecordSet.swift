import Foundation
import SwiftData

@Model
final class RecordSet {
    var id: UUID = UUID()
    var setNumber: Int = 0
    
    var weight: Double = 0
    var weightUnitRaw: String = WeightUnit.kg.rawValue
    var repetitions: Int = 0
    var memo: String?
    
    @Relationship
    var header: RecordHeader? = nil
    
    init(
        id: UUID = UUID(),
        setNumber: Int,
        weight: Double,
        weightUnit: WeightUnit,
        repetitions: Int,
        memo: String? = nil,
        header: RecordHeader
    ) {
        self.id = id
        self.setNumber = setNumber
        self.weight = weight
        self.weightUnitRaw = weightUnit.rawValue
        self.repetitions = repetitions
        self.memo = memo
        self.header = header
    }
    
    var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
        set { weightUnitRaw = newValue.rawValue }
    }
}
