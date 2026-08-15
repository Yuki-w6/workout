import Foundation
import SwiftData

@Model
public final class RecordSet {
    public var id: UUID = UUID()
    public var setNumber: Int = 0

    public var weight: Double = 0
    public var weightUnitRaw: String = WeightUnit.kg.rawValue
    public var repetitions: Int = 0
    public var memo: String?

    @Relationship
    public var header: RecordHeader? = nil

    public init(
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

    public var weightUnit: WeightUnit {
        get { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
        set { weightUnitRaw = newValue.rawValue }
    }
}
