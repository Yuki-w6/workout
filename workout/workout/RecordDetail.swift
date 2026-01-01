import Foundation
import SwiftData

enum WeightUnit: String, Codable, CaseIterable {
    case kilogram
    case pound
}

@Model
final class RecordDetail {
    @Attribute(.unique) var id: UUID
    var header: RecordHeader
    var setNumber: Int
    var weight: Double
    var weightUnit: WeightUnit
    var repetitions: Int
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
