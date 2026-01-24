import Foundation
import SwiftData

@Model
final class RecordDetail {
    var id: UUID = UUID()
    var header: RecordHeader?
    var setNumber: Int = 0
    var weight: Double = 0
    var weightUnit: WeightUnit = WeightUnit.kg
    var repetitions: Int = 0
    var memo: String?

    init(
        id: UUID = UUID(),
        header: RecordHeader,
        setNumber: Int,
        weight: Double,
        weightUnit: WeightUnit,
        repetitions: Int,
        memo: String? = nil
    ) {
        self.id = id
        self.header = header
        self.setNumber = setNumber
        self.weight = weight
        self.weightUnit = weightUnit
        self.repetitions = repetitions
        self.memo = memo
    }
}
